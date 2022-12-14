% ======================================================================
%> @file PABatchTool.cpp
%> @brief PABatchTool serves as Padaco's batch processing controller.
%> The class creates and controls the batch processing figure that is used
%> to process a collection of Actigraph GT3X+ data files.
% ======================================================================
classdef PABatchTool < PAFigureFcnController
   
    properties(Constant)
        % In minutes
        featureDurationStr = {
            '1 second'
            '15 seconds'
            '30 seconds'
            '1 minute'
            '5 minutes'
            '10 minutes'
            '15 minutes'
            '20 minutes'
            '30 minutes'
            '1 hour'};
        featureDurationVal = {
            1/60 % 0 is used to represent 1 sample frames.
            0.25
            0.5
            1
            5
            10
            15
            20
            30
            60};
        
        maxDaysAllowedStr = {
            '1 day'
            '7 days'
            'No Limit'
            };
        maxDaysVal = {
            1
            7
            Inf
            };
    end
    
    events
        BatchToolStarting;
        BatchToolRunning;
        BatchToolComplete;
        BatchToolClosing;
        SwitchToResults;
    end
    
    properties(Access=protected)
       figureFcn = @batchTool; 
    end
    
    properties(Access=private)
        %> Flag for determining if batch mode is running or not.  Can be
        %> changed to false by user cancelling.
        isRunning;
    end
    
    methods
        
        %> @brief Class constructor.
        %> @param batchSettings Struct containing settings to use for the batch process (optional).  if
        %> it is not inclded then the getDefaults() method will be called to obtain default
        %> values.
        %> @retval  PABatchTool Instance of PABatchTool.
        function this = PABatchTool(varargin)
            this@PAFigureFcnController(varargin{:});                        
            %             figureH = batchTool('visible','off','name','','sizechangedfcn',[]);
            %             if ~(this.setFigureHandle(figureH) && this.initFigure())
            %                 fprintf(2,'Failed to initialize PABatchTool!\n');
            %                 delete(figureH);
            %             end
        end
        
        function checkExportFeaturesCallback(this, varargin)
            this.refreshSettings();
        end
        
        function shouldExport = shouldExportAlignedFeatures(this)
            shouldExport = get(this.handles.check_run_aligned_feature_export,'value');            
        end
        
        function shouldExport = shouldExportUnalignedFeatures(this)
            shouldExport = get(this.handles.check_run_unaligned_feature_export,'value');            
        end
        
        function refreshSettings(this)
            if(ishandle(this.figureH))
                this.setSetting('featureLabel',getMenuString(this.handles.menu_featureFcn));            
                this.setSetting('frameDurationMinutes',getSelectedMenuUserData(this.handles.menu_frameDurationMinutes));
                this.setSetting('numDaysAllowed',getMenuUserData(this.handles.menu_maxDaysAllowed));
                if(this.shouldExportAlignedFeatures())
                    enableHandles(this.handles.panel_loadshape_settings);
                else
                    disableHandles(this.handles.panel_loadshape_settings);                    
                end
                if(~this.shouldExportAlignedFeatures() &&  ~this.shouldExportUnalignedFeatures())
                    set(this.handles.button_go,'enable','off');
                else
                    set(this.handles.button_go,'enable','on');
                end
            end            
        end
        
        function close(this, varargin)
            if(ishandle(this.figureH))
                this.refreshSettings();
                this.notify('BatchToolClosing',EventData_BatchTool(this.settings));
                delete(this.figureH);
            end
            delete(this);
        end
        
        % Callbacks
        % --------------------------------------------------------------------
        %> @brief Batch figure button callback for getting a directory of
        %> actigraph files to process.
        %> @param this Instance of PAController
        %> @param hObject    handle to buttont (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------        
        function getSourceDirectoryCallback(this,hObject,eventdata)
        % --------------------------------------------------------------------
            displayMessage = 'Select the directory containing .raw or count actigraphy files';
            initPath = get(this.handles.text_sourcePath,'string');
            tmpSrcDirectory = uigetfulldir(initPath,displayMessage);
            this.setSourcePath(tmpSrcDirectory);
        end        
 
        % --------------------------------------------------------------------
        %> @brief Batch figure button callback for getting a directory to
        %> save processed output files to.
        %> @param this Instance of PAController
        %> @param hObject    handle to buttont (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------
        function getOutputDirectoryCallback(this,hObject,eventdata)
            displayMessage = 'Select the output directory to place processed results.';
            initPath = get(this.handles.text_outputPath,'string');
            tmpOutputDirectory = uigetfulldir(initPath,displayMessage);
            this.setOutputPath(tmpOutputDirectory);
        end
        
        function didUpdate = toggleOutputToInputPathLinkageCallbackFcn(this, checkboxHandle, eventData)
            try
                this.setSetting('isOutputPathLinked',this.isOutputPathLinkedToInputPath());
                if(this.getSetting('isOutputPathLinked'))
                    this.setOutputPath(this.getSourcePath());
                    set(this.handles.button_getOutputPath,'enable','off');                    
                else
                    set(this.handles.button_getOutputPath,'enable','on');
                end
                didUpdate = true;
            catch me
                showME(me);
                didUpdate = false;
            end
        end
        
        function didSet = setSourcePath(this,tmpSrcPath)
            if(~isempty(tmpSrcPath) && isdir(tmpSrcPath))
                %assign the settings directory variable
                this.setSetting('sourceDirectory',tmpSrcPath);
                set(this.handles.text_sourcePath,'string',tmpSrcPath);
                this.calculateFilesFound();                
                if(this.isOutputPathLinkedToInputPath())
                    didSet = this.setOutputPath(tmpSrcPath);
                else
                    didSet = true;
                end
            else
                didSet = false;
            end            
        end
        
        function isLinked = isOutputPathLinkedToInputPath(this)
            isLinked = get(this.handles.check_linkInOutPaths,'value');
        end
        
        function didSet = setOutputPath(this,tmpOutputPath)
            if(~isempty(tmpOutputPath) && isdir(tmpOutputPath))
                %assign the settings directory variable
                this.setSetting('outputDirectory',tmpOutputPath);
                set(this.handles.text_outputPath,'string',tmpOutputPath);
                this.updateOutputLogs();
                didSet = true;
            else
                didSet = false;
            end            
        end

        function featurePathname = getFeaturePathname(this)
            featurePathname = fullfile(this.getOutputPath(),'features');
        end
        
        function exportPathname = getUnalignedFeaturePathname(this)
            exportPathname = fullfile(this.getOutputPath(),'unaligned_features');
        end
        
        function pathName = getOutputPath(this)
            pathName = this.getSetting('outputDirectory');
        end
        
        function pathName = getSourcePath(this)
            pathName = this.getSetting('sourceDirectory');
        end
                        
        % --------------------------------------------------------------------
        %> @brief Determines the number of actigraph files located in the
        %> specified source path and updates the GUI's count display.
        %> @param this Instance of PAController
        %> @param text_sourcePath_h Text graphic handle for placing the path
        %> selected on the GUI display
        %> @param text_filesFound_h Text graphic handle to place the number
        %> of actigraph files found in the source directory.        
        % --------------------------------------------------------------------        
        function calculateFilesFound(this,sourcePathname,text_filesFound_h)
        % --------------------------------------------------------------------
            
           %update the source path edit field with the source directory
           if(nargin<3)
               text_filesFound_h = this.handles.text_filesFound;
               if(nargin<2)
                   sourcePathname = this.getSourcePath();
               end
           end
           
           %get the file count and update the file count text field.
           %            rawFileCount = numel(getFilenamesi(sourcePathname,'.raw'));
           %            binFileCount = numel(getFilenamesi(sourcePathname,'.bin'));
           %            csvFileCount = numel(getFilenamesi(sourcePathname,'.csv'));

           % ignore "hidden" files which begin with a '.'
           rawFileCount = sum(cellfun(@(c)c(1)~='.',getFilenamesi(sourcePathname,'.raw')));
           binFileCount = sum(cellfun(@(c)c(1)~='.',getFilenamesi(sourcePathname,'.bin')));
           csvFileCount = sum(cellfun(@(c)c(1)~='.',getFilenamesi(sourcePathname,'.csv')));

           msg = '';
           if(rawFileCount==0 && csvFileCount==0 && binFileCount==0)
               msg = '0 files found.';
               set(this.handles.button_go,'enable','off','tooltipstring','No files found!');
           else
              if(rawFileCount>0)
                  msg = sprintf('%s%u .raw file(s) found.\n',msg,rawFileCount);
              end
              if(csvFileCount>0)
                  msg = sprintf('%s%u .csv file(s) found.',msg,csvFileCount);
              end
              if(binFileCount>0)
                  msg = sprintf('%s%u .bin file(s) found.',msg,binFileCount);
              end
              
              if(binFileCount+rawFileCount>0 && csvFileCount>0)
                 msg = sprintf('%s Only .csv file(s) will be processed; place .raw/.bin files in a separate directory for processing.',msg);
              end
              
              set(this.handles.button_go,'enable','on','tooltipstring','');
           end
           set(text_filesFound_h,'string',msg);
        end
        
               
        % --------------------------------------------------------------------
        %> @brief Determines the number of actigraph files located in the
        %> specified source path and updates the GUI's count display.
        %> @param this Instance of PAController
        %> @param outputPathname (optional) Pathname of output directory (string)
        %> @param text_outputLogs_h Text graphic handle to write results to.
        % --------------------------------------------------------------------        
        function updateOutputLogs(this,outputPathname,text_outputLogs_h)
        % --------------------------------------------------------------------
            
           %update the source path edit field with the source directory
           if(nargin<3)
               text_outputLogs_h = this.handles.text_outputLogs;
               if(nargin<2)
                   outputPathname = this.getOutputPath();
               end
           end
          
           set(text_outputLogs_h,'string','','hittest','off');

           %get the log files with most recent ones first on the list.
           sortNewestToOldest = true;
           [filenames, fullfilenames, filedates] = getFilenamesi(outputPathname,'.txt',sortNewestToOldest);
           
           newestIndex = find(strncmpi(filenames,'batchRun',numel('batchRun')),1);
           if(~isempty(newestIndex))
               logFilename = filenames{newestIndex};
               logFullFilename = fullfilenames{newestIndex};
               % logDate = filedates(newestIndex);
               logMsg = sprintf('Last log file: %s',logFilename);
               %tooltip = '<html><body><h4>Click to view last batch run log file</h4></body></html>';
               % tooltip = 'Click to view.';
               callbackFcn = {@viewTextFileCallback,logFullFilename};
               enableState = 'inactive';  % This prevents the tooltip from being seen :(, but allows the buttondownfcn to work :)
               
               fid = fopen(logFullFilename,'r');
               if(fid>0)
                   fopen(fid);
                   tooltip = fread(fid,'uint8=>char')';
                   fclose(fid);
                   enableState = 'on';
               
               else
                   tooltip = '';                   
               end
               
           else
               logMsg = '';
               tooltip = '';
               callbackFcn = [];
               enableState = 'on';
               
           end
           set(text_outputLogs_h,'string',logMsg,'tooltipstring',tooltip,'buttondownFcn',callbackFcn,'enable',enableState);
        end
        
        % --------------------------------------------------------------------        
        %> @brief Callback that starts a batch process based on batch gui
        %> paramters.
        %> @param this Instance of PAController
        %> @param hObject MATLAB graphic handle of the callback object
        %> @param eventdata reserved by MATLAB, not used.
        % --------------------------------------------------------------------        
        function startBatchProcessCallback(this,hObject,eventdata)                    
            
            this.disable();
            waitH = [];
            try
                dateMap.Sun = 0;
                dateMap.Mon = 1;
                dateMap.Tue = 2;
                dateMap.Wed = 3;
                dateMap.Thu = 4;
                dateMap.Fri = 5;
                dateMap.Sat = 6;
                
                % See also: weekday()-1
                
                
                % initialize batch processing file management
                [countFilenames, countFullFilenames] = getFilenamesi(this.getSourcePath(),'.csv');
                
                if(numel(countFilenames)>0)
                    accelType = 'count';
                    filenames = countFilenames;
                    fullFilenames = countFullFilenames;
                else
                    accelType = 'raw';
                    [rawFilenames, rawFullFilenames] = getFilenamesi(this.getSourcePath(),{'.bin','.raw'});
                    filenames = rawFilenames;
                    fullFilenames = rawFullFilenames;
                end
                
                % exclude "hidden" files which start with a '.'
                fullFilenames = fullFilenames(~startsWith(filenames,'.'));
                filenames = filenames(~startsWith(filenames,'.'));
                
                failedFiles = {};
                fileCount = numel(fullFilenames);
                fileCountStr = num2str(fileCount);
                
                % Get batch processing settings from the GUI
                
                this.notify('BatchToolStarting',EventData_BatchTool(this.settings));
                this.isRunning = true;
                
                
                % Establish waitbar - do this early, otherwise the program
                % appears to hang.
                
                %             waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','off');
                
                % Job security:
                %             waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','on','CreateCancelBtn',{@(hObject,eventData) feval(get(get(hObject,'parent'),'closerequestfcn'),get(hObject,'parent'),[])},'closerequestfcn',{@(varargin) delete(varargin{1})});
                
                % Program security:
                waitH = waitbar(0,{'','','Configuring rules and output file headers',''},'name','Batch processing','visible','off',...
                    'CreateCancelBtn',@this.waitbarCancelCallback,'closerequestfcn',@this.waitbarCloseRequestCallback,...
                    'resize','off','windowstyle','modal','color',[0.9 0.9 0.9]);
                
                % We have a cancel button and an axes handle on our waitbar
                % window; so look for the one that has the title on it.
                titleH = get(findobj(get(waitH,'children'),'flat','-property','title'),'title');
                buttonH = findobj(get(waitH,'children'),'flat','style','pushbutton');
                
                newFontSize = 12;
                oldFontSize = get(buttonH,'fontsize');
                changeRatio = newFontSize/oldFontSize;
                oldButtonPos = get(buttonH,'position');
                newW = oldButtonPos(3)*changeRatio;
                newH = oldButtonPos(4)*changeRatio;
                dW = newW-oldButtonPos(3);
                dH = newH-oldButtonPos(4);
                newButtonPos = [oldButtonPos(1)-dW/2, oldButtonPos(2)+dH/2, newW, newH];
                
                set(titleH,'interpreter','none','fontsize',newFontSize);  % avoid '_' being interpreted as subscript instruction
                set(buttonH,'fontsize',newFontSize,'position',newButtonPos);
                set(waitH,'visible','on');  %now show the results
                drawnow;
                
                
                % Get maximum days allowed for any one subject
                maximumDaysAllowed = getMenuUserData(this.handles.menu_maxDaysAllowed);
                this.setSetting('numDaysAllowed',maximumDaysAllowed);
                
                % get feature settings
                % determine which feature to process
                
                featureFcn = getMenuUserData(this.handles.menu_featureFcn);
                this.setSetting('featureLabel',getMenuString(this.handles.menu_featureFcn));
                
                % determine frame aggreation size - size to calculate each
                % feature from
                %             allFrameDurationMinutes = get(handles.menu_frameDurationMinutes,'userdata');
                %             frameDurationMinutes = allFrameDurationMinutes(get(handles.menu_frameDurationMinutes,'value'));
                frameDurationMinutes = getSelectedMenuUserData(this.handles.menu_frameDurationMinutes);
                this.setSetting('frameDurationMinutes',frameDurationMinutes);
                
                % features are grouped for all studies into one file per
                % signal, place groupings into feature function directories
                
                
                this.setSetting('alignment','elapsedStartHours',0); %when to start the first measurement
                this.setSetting('alignment','intervalLengthHours',24);  %duration of each interval (in hours) once started
                
                % setup developer friendly variable names
                elapsedStartHour  = this.getSetting('alignment','elapsedStartHours');
                intervalDurationHours = this.getSetting('alignment','intervalLengthHours');
                maxNumIntervals = 24/intervalDurationHours*maximumDaysAllowed;  %set maximum to a week
                %this.setSetting('alignment.singalName = 'X';
                
                signalNames = strcat('accel.',accelType,'.',{'x','y','z','vecMag'})';
                %signalNames = {strcat('accel.',this.accelObj.accelType,'.','x')};
                
                startDateVec = [0 0 0 elapsedStartHour 0 0];
                stopDateVec = startDateVec + [0 0 0 intervalDurationHours -frameDurationMinutes 0]; %-frameDurMin to prevent looping into the start of the next interval.
                frameInterval = [0 0 0 0 frameDurationMinutes 0];
                timeAxis = datenum(startDateVec):datenum(frameInterval):datenum(stopDateVec);
                timeAxisStr = datestr(timeAxis,'HH:MM:SS');
                
                [logFid, logFullFilename, summaryFid, summaryFullFilename] = this.prepLogAndSummaryFiles(this.settings);
                fprintf(logFid,'File count:\t%u',fileCount);
                
                %% Setup output folders
                
                % PASensorData separates the psd feature into bands in order to
                % create feature vectors.  Unfortunately, this does not give a
                % clean way to separate the groups into the expanded feature
                % vectors, hence the gobbly goop code here:
                if(strcmpi(featureFcn,'all'))
                    featureStructWithPSDBands= PASensorData.getFeatureDescriptionStructWithPSDBands();
                    outputFeatureFcns = fieldnames(featureStructWithPSDBands);
                    outputFeatureLabels = struct2cell(featureStructWithPSDBands);  % leave it here for the sake of other coders; yes, you can assign this using a second output argument from getFeatureDescriptionWithPSDBands
                elseif(strcmpi(featureFcn,'all_sans_psd'))
                    outputFeatureStruct = rmfield(PASensorData.getFeatureDescriptionStruct(),'psd');
                    outputFeatureFcns = fieldnames(outputFeatureStruct);
                    outputFeatureLabels = struct2cell(outputFeatureStruct);
                elseif(strcmpi(featureFcn,'all_sans_psd_usagestate')) % and sans usage state
                    outputFeatureStruct = rmfield(PASensorData.getFeatureDescriptionStruct(),{'psd','usagestate'});
                    outputFeatureFcns = fieldnames(outputFeatureStruct);
                    outputFeatureLabels = struct2cell(outputFeatureStruct);
                else
                    outputFeatureFcns = {featureFcn};
                    outputFeatureLabels = {this.getSetting('featureLabel')};
                end
                
                
                if(this.shouldExportUnalignedFeatures())
                    emptyUnalignedResults = mkstruct(outputFeatureFcns);
                    unalignedOutputPathname = this.getUnalignedFeaturePathname();
                    unalignedHeaderStr = cell2str(['# datenum';signalNames],', ');
                    unalignedRowStr = ['\n%s',repmat(', %f',1,numel(signalNames))];
                end
                
                if(this.shouldExportAlignedFeatures())
                    alignedFeatureOutputPathnames =   strcat(this.getFeaturePathname(),filesep,outputFeatureFcns);                    
                    for fn=1:numel(outputFeatureFcns)
                        
                        % Prep output alignment files.
                        outputFeatureFcn = outputFeatureFcns{fn};
                        features_pathname = alignedFeatureOutputPathnames{fn};
                        feature_description = outputFeatureLabels{fn};
                        
                        if(~isormkdir(features_pathname))
                            throw(MException('PA:BatchTool:Pathname','Unable create output path for storing batch process features'));
                        end
                        
                        for s=1:numel(signalNames)
                            signalName = signalNames{s};
                            
                            featureFilename = fullfile(features_pathname,strcat('features.',outputFeatureFcn,'.',signalName,'.txt'));
                            fid = fopen(featureFilename,'w');
                            fprintf(fid,'# Feature:\t%s\n',feature_description);
                            
                            fprintf(fid,'# Length:\t%u\n',size(timeAxisStr,1));
                            
                            fprintf(fid,'# Study_ID\tStart_Datenum\tStart_Day');
                            for t=1:size(timeAxisStr,1)
                                fprintf(fid,'\t%s',timeAxisStr(t,:));
                            end
                            fprintf(fid,'\n');
                            fclose(fid);
                        end
                    end
                end
                
                totalDayCount = 0;
                completeDayCount = 0;
                incompleteDayCount = 0;
                
                % setup timers
                pctDone = 0;
                pctDelta = (1/fileCount);
                
                waitbar(pctDone,waitH,filenames{1});
                
                startTime = now;
                startClock = clock;
                
                % batch process
                f = 0;
                
                
                while(f< fileCount && this.isRunning)
                    f = f+1;
                    ticStart = tic;                    
                    
                    [~,studyName] = fileparts(fullFilenames{f}); 
                    
                    
                    if(this.shouldExportUnalignedFeatures())
                        unalignedResults = emptyUnalignedResults;
                    end
                    
                    %for each featureFcnArray item as featureFcn
                    try
                        
                        fprintf('Processing %s\n',filenames{f});
                        curData = PASensorData(fullFilenames{f});%,this.SETTINGS.DATA
                        if(~curData.hasData())
                            errMsg = sprintf('No data loaded from file (%s)',filenames{f});
                            throw(MException('PA:BatchTool:FileLoad',errMsg));
                        end
                        curStudyID = curData.getStudyID('numeric');
                        if(isnan(curStudyID))
                            curStudyID = f;
                        end                        
                        setFrameDurMin = curData.setFrameDurationMinutes(frameDurationMinutes);
                        if(frameDurationMinutes~=setFrameDurMin)
                            fprintf('There was an error in setting the frame duration.\n');
                            throw(MException('PA:Batchtool','error in setting the frame duration'));
                        else                            
                            for s=1:numel(signalNames)
                                signalName = signalNames{s};
                                
                                % Calculate/extract the features for the
                                % current signal (e.g. x, y, z, or vecMag) and
                                % the given feature function (e.g.
                                % 'mode','psd','all')
                                curData.extractFeature(signalName,featureFcn);
                                
                                for fn=1:numel(outputFeatureFcns)
                                    outputFeatureFcn = outputFeatureFcns{fn};
                                    
                                    if(this.shouldExportAlignedFeatures())
                    
                                        features_pathname = alignedFeatureOutputPathnames{fn};
                                        
                                        featureFilename = fullfile(features_pathname,strcat('features.',outputFeatureFcn,'.',signalName,'.txt'));
                                        [alignedVec, alignedStartDateVecs] = curData.getAlignedFeatureVecs(outputFeatureFcn,signalName,elapsedStartHour, intervalDurationHours);
                                        
                                        numIntervals = size(alignedVec,1);
                                        if(numIntervals>maxNumIntervals)
                                            alignedVec = alignedVec(1:maxNumIntervals,:);
                                            alignedStartDateVecs = alignedStartDateVecs(1:maxNumIntervals, :);
                                            numIntervals = maxNumIntervals;
                                        end
                                    end
                                    
                                    if(this.shouldExportUnalignedFeatures())
                                        [unalignedVec, unalignedDatenums] = curData.getFeatureVecs(outputFeatureFcn,signalName);
                                    end
                                                                        
                                    % Currently, only x,y,z or vector magnitude
                                    % are considered for signal names.  And
                                    % they all have the same number of samples.
                                    % Thus, it is not necessary to perform the
                                    % following caluclations on the first
                                    % iteration through.
                                    if(s==1)
                                        % put date time stamp and first
                                        % signals vector followed by
                                        % empty/nan for remaining signals,
                                        % to be filled in 'else' (next)
                                        if(this.shouldExportUnalignedFeatures())
                                            unalignedResults.(outputFeatureFcn) = [unalignedDatenums(:),unalignedVec(:),nan(numel(unalignedVec),numel(signalNames)-1)];
                                        end
                                        
                                        if(this.shouldExportAlignedFeatures())
                                            
                                            % Need to apply datenum to get back to
                                            % proper time for datestr to work.
                                            startDatenums = datenum(alignedStartDateVecs);
                                            % There is a bug if you try to do this
                                            % datestr(alignedStartDateVecs,'ddd')
                                            % and the date vecs have a different
                                            % number of days due to extra or less
                                            % time in other columns (e.g. hours,
                                            % minutes).
                                            alignedStartDaysOfWeek = datestr(startDatenums,'ddd');
                                            alignedStartNumericDaysOfWeek = nan(numIntervals,1);
                                            for a=1:numIntervals
                                                alignedStartNumericDaysOfWeek(a)=dateMap.(alignedStartDaysOfWeek(a,:));
                                            end
                                            
                                            studyIDs = repmat(curStudyID,numIntervals,1);
                                            
                                            result = [studyIDs,startDatenums,alignedStartNumericDaysOfWeek,alignedVec];
                                        end
                                    else
                                        if(this.shouldExportAlignedFeatures())
                                            
                                            % Just fill in the new part, which is a
                                            % MxN array of features - taken for M
                                            % days at N time intervals.
                                            result =[result(:,1:3), alignedVec];
                                        end
                                        if(this.shouldExportUnalignedFeatures())
                                            unalignedResults.(outputFeatureFcn)(:,s+1) = unalignedVec(:); %first column holds datenum
                                        end
                                    end
                                    
                                    if(this.shouldExportAlignedFeatures())
                                        % Added this because of issues with raw
                                        % data loaded as a single.
                                        if(~isa(result,'double'))
                                            result = double(result);
                                        end
                                        save(featureFilename,'result','-ascii','-tabs','-append');
                                    end
                                end
                            end
                            
                            % Unaligned feature output
                            if(this.shouldExportUnalignedFeatures())
                                for fn=1:numel(outputFeatureFcns)
                                    outputFeatureFcn = outputFeatureFcns{fn};
                                    unalignedFeatureFilename = fullfile(unalignedOutputPathname,sprintf('%s.%s.csv',studyName,outputFeatureFcn));
                                    [fid, errMsg]  = fopen(unalignedFeatureFilename,'w+');
                                    if(fid>1)
                                        fprintf(fid,'%s',unalignedHeaderStr);
                                        result = unalignedResults.(outputFeatureFcn);
                                        dateStrs = datestr(result(:,1));
                                        result = result(:,2:end);
                                        for row=1:size(result,1)
                                            curRow = result(row,:);
                                            fprintf(fid,unalignedRowStr,dateStrs(row,:),curRow);
                                        end
                                        fclose(fid);
                                        
                                        %save(unalignedFeatureFilename,'result','-ascii','-append');
                                    else
                                        errMsg = sprintf('Unable to open unaligned feature output file for writing.  Error message: %s',errMsg');
                                        throw(MException('PA:Batch:File',errMsg));
                                    end
                                end
                            end                            
                            
                            [curCPM_x, curCPM_y, curCPM_z, curCPM_vm] = curData.getCountsPerMinute();
                            
                            [curCompleteDayCount, curIncompleteDayCount, curTotalDayCount] = curData.getDayCount(elapsedStartHour, intervalDurationHours);
                            totalDayCount = totalDayCount + curTotalDayCount;
                            completeDayCount = completeDayCount + curCompleteDayCount;
                            incompleteDayCount = incompleteDayCount + curIncompleteDayCount;
                            
                            fprintf(summaryFid,'%d, %s, %d, %d, %d, %d, %d, %d, %d\n',curStudyID, fullFilenames{f}, curTotalDayCount, curCompleteDayCount, curIncompleteDayCount, curCPM_x, curCPM_y, curCPM_z, curCPM_vm);                            
                        end
                    catch me
                        showME(me);
                        failedFiles{end+1} = filenames{f};
                        failMsg = sprintf('\t%s\tFAILED.\n',strrep(fullFilenames{f},'\','\\'));
                        fprintf(1,failMsg);
                        
                        % Log error
                        fprintf(logFid,'\n=======================================\n');
                        fprintf(logFid,failMsg);
                        showME(me,logFid);
                        
                    end
                    
                    num_files_completed = f;
                    pctDone = pctDone+pctDelta;
                    
                    elapsed_dur_sec = toc(ticStart);
                    fprintf('File %d of %d (%0.2f%%) Completed in %0.2f seconds\n',num_files_completed,fileCount,pctDone*100,elapsed_dur_sec);
                    elapsed_dur_total_sec = etime(clock,startClock);
                    avg_dur_sec = elapsed_dur_total_sec/num_files_completed;
                    
                    if(this.isRunning)
                        remaining_dur_sec = avg_dur_sec*(fileCount-num_files_completed);
                        est_str = sprintf('%01ihrs %01imin %01isec',floor(mod(remaining_dur_sec/3600,24)),floor(mod(remaining_dur_sec/60,60)),floor(mod(remaining_dur_sec,60)));
                        
                        msg = {['Processing ',filenames{f}, ' (file ',num2str(f) ,' of ',fileCountStr,')'],...
                            ['Elapsed Time: ',datestr(now-startTime,'HH:MM:SS')],...
                            ['Time Remaining: ',est_str]};
                        fprintf('%s\n',msg{2});
                        if(ishandle(waitH))
                            waitbar(pctDone,waitH,char(msg));
                        else
                            %                     waitHandle = findall(0,'tag','waitbarHTag');
                        end
                    end
                end
                elapsedTimeStr = datestr(now-startTime,'HH:MM:SS');
                
                % Let the user have a glimpse of the most recent update -
                % otherwise they have been waiting for this point long enough
                % already because they pressed the 'cancel' button
                if(this.isRunning)
                    pause(1);
                end
                
                waitbar(1,waitH,'Finished!');
                pause(1);  % Allow the finish message time to be seen.
                
                delete(waitH);  % we are done with this now.
                
                fileCount = numel(filenames);
                failCount = numel(failedFiles);
                
                skipCount = fileCount - f;  %f is number of files processed.
                successCount = f-failCount;
                
                if(~this.isRunning)
                    userCanceledMsg = sprintf('User canceled batch operation before completion.\n\n');
                else
                    userCanceledMsg = '';
                end
                
                batchResultStr = sprintf(['%sProcessed %u files in (hh:mm:ss)\t %s.\n',...
                    '\tSucceeded:\t%5u\n',...
                    '\tSkipped:\t%5u\n',...
                    '\tFailed:\t%5u\n\n'],userCanceledMsg,fileCount,elapsedTimeStr,successCount,skipCount,failCount);
                
                batchResultStr = sprintf(['%sTotal day count:\t%5u\n',...
                    'Complete day count:\t%5u\n',...
                    'Incomplete day count:\t%5u\n'],batchResultStr,totalDayCount, completeDayCount, incompleteDayCount);
                
                fprintf(logFid,'\n====================SUMMARY===============\n');
                fprintf(logFid,batchResultStr);
                fprintf(1,batchResultStr);
                if(failCount>0 || skipCount>0)
                    
                    promptStr = str2cell(sprintf('%s\nThe following files were not processed:',batchResultStr));
                    failMsg = sprintf('\n\n%u Files Failed:\n',numel(failedFiles));
                    fprintf(1,failMsg);
                    fprintf(logFid,failMsg);
                    for f=1:numel(failedFiles)
                        failMsg = sprintf('\t%s\tFAILED.\n',failedFiles{f});
                        fprintf(1,failMsg);
                        fprintf(logFid,failMsg);
                    end
                    
                    fclose(logFid);
                    fclose(summaryFid);
                    
                    % Only handle the case where non-skipped files fail here.
                    if(failCount>0)
                        skipped_filenames = failedFiles(:);
                        if(failCount<=10)
                            listSize = [180 150];  %[ width height]
                        elseif(failCount<=20)
                            listSize = [180 200];
                        else
                            listSize = [180 300];
                        end
                        
                        [selections,clicked_ok]= listdlg('PromptString',promptStr,'Name','Batch Completed',...
                            'OKString','Copy to Clipboard','CancelString','Close','ListString',skipped_filenames,...
                            'listSize',listSize);
                        
                        if(clicked_ok)
                            %char(10) is newline
                            skipped_files = [char(skipped_filenames(selections)),repmat(char(10),numel(selections),1)];
                            skipped_files = skipped_files'; %filename length X number of files
                            
                            clipboard('copy',skipped_files(:)'); %make it a column (1 row) vector
                            selectionMsg = [num2str(numel(selections)),' filenames copied to the clipboard.'];
                            disp(selectionMsg);
                            h = msgbox(selectionMsg);
                            pause(1);
                            if(ishandle(h))
                                delete(h);
                            end
                        end
                        
                        dlgName = 'Errors found';
                        showLogFileStr = 'Open log file';
                        showSummaryFileStr = 'Open summary file';
                        returnToBatchToolStr = 'Return to batch tool';
                        cancelStr = 'Cancel';
                        options.Default = showLogFileStr;
                        
                        options.Interpreter = 'none';
                        buttonName = questdlg(batchResultStr,dlgName,showLogFileStr,returnToBatchToolStr,cancelStr,options);
                        switch buttonName
                            case returnToBatchToolStr
                                % Bring the figure to the front/onscreen
                                figure(this.figureH);
                            case showLogFileStr
                                textFileViewer(logFullFilename);
                            case showSummaryFileStr
                                textFileViewer(summaryFullFilename);
                            otherwise
                                figure(this.figureH);
                        end
                        
                    end
                else
                    fclose(logFid);
                    fclose(summaryFid);
                    
                    dlgName = 'Batch complete';
                    showResultsStr = 'Switch to results';
                    showOutputFolderStr = 'Open output folder';
                    showLogFileStr = 'Open log file';
                    showSummaryFileStr = 'Open summary file';
                    returnToBatchToolStr = 'Return to batch tool';
                    
                    options.Default = showResultsStr;
                    options.Interpreter = 'none';
                    buttonName = questdlg(batchResultStr,dlgName,showResultsStr,showOutputFolderStr,returnToBatchToolStr,options);
                    switch buttonName
                        case returnToBatchToolStr
                            % Bring the figure to the front/onscreen
                            figure(this.figureH);
                        case showResultsStr
                            % Close the batch mode
                            
                            % Set the results path to be that of the normal
                            % settings path.
                            this.hide();
                            this.notify('SwitchToResults',EventData_SwitchToResults);
                            this.close();  % close this out, 'return',
                            return;       %  and go to the results view
                        case showOutputFolderStr
                            openDirectory(this.getOutputPath())
                        case showLogFileStr
                            textFileViewer(logFullFilename);
                        case showSummaryFileStr
                            textFileViewer(summaryFullFilename);
                        otherwise
                    end
                end
                
                this.updateOutputLogs();
                this.isRunning = false;
                this.enable();
            catch me
                if(ishandle(waitH))
                    delete(waitH);
                end
                showME(me);
                warndlg('An enexpected error occurred');
                this.enable();
            end
            
            %             this.resultsPathname = this.getOutputPath();
        end
        
        
        % Helper functions for close request and such
        function waitbarCloseRequestCallback(this,hWaitbar, ~)
            this.isRunning = false;
            waitbar(100,hWaitbar,'Cancelling .... please wait while current iteration finishes.');
            drawnow();
        end
        
        function waitbarCancelCallback(this,hCancelBtn, eventData) 
            this.waitbarCloseRequestCallback(get(hCancelBtn,'parent'),eventData);
        end
        
    end
    
    methods(Access=protected)
        
        function didInit = initFigure(this)
            didInit = false;
            if(ishandle(this.figureH))
                try
                    batchFig = this.figureH;
                    
                    contextmenu_directory = uicontextmenu('parent',batchFig);
                    if(ismac)
                        label = 'Show in Finder';
                    elseif(ispc)
                        label = 'Show in Explorer';
                    else
                        label = 'Show in browser';
                    end
                    
                    this.isRunning = false;
                    uimenu(contextmenu_directory,'Label',label,'callback',@showPathContextmenuCallback);
                    
                    set(this.handles.button_getSourcePath,'callback',@this.getSourceDirectoryCallback);
                    set(this.handles.button_getOutputPath,'callback',@this.getOutputDirectoryCallback);
                    
                    set(this.handles.text_outputPath,'string',this.getSetting('outputDirectory'),'uicontextmenu',contextmenu_directory);
                    set(this.handles.text_sourcePath,'string','','uicontextmenu',contextmenu_directory);
                    
                    set(this.handles.check_linkInOutPaths,'callback',@this.toggleOutputToInputPathLinkageCallbackFcn,'value',this.getSetting('isOutputPathLinked'));
                    
                    % Send a refresh to the widgets that may be effected by the
                    % current value of the linkage checkbox.
                    this.toggleOutputToInputPathLinkageCallbackFcn(this.handles.check_linkInOutPaths,[]);
                    %             set(this.handles.check_usageState,'value',this.getSetting('classifyUsageState);
                    
                    
                    set(this.handles.menu_frameDurationMinutes,'string',this.featureDurationStr,'userdata',this.featureDurationVal,'value',find(cellfun(@(x)(x==this.getSetting('frameDurationMinutes')),this.featureDurationVal)));
                    set(this.handles.menu_maxDaysAllowed,'string',this.maxDaysAllowedStr,'userdata',this.maxDaysVal,'value',find(cellfun(@(x)(x==this.getSetting('numDaysAllowed')),this.maxDaysVal)));
                    
                    set(this.handles.check_run_aligned_feature_export,'callback',@this.checkExportFeaturesCallback,'value',1);
                    set(this.handles.check_run_unaligned_feature_export,'callback',@this.checkExportFeaturesCallback,'value',0);
                    
                    set(this.handles.button_go,'callback',@this.startBatchProcessCallback);
                    
                    % try and set the source and output paths.  In the event that
                    % the path is not set, then revert to the empty ('') path.
                    if(~this.setSourcePath(this.getSetting('sourceDirectory')))
                        this.setSourcePath('');
                    end
                    if(~this.setOutputPath(this.getSetting('outputDirectory')))
                        this.setOutputPath('');
                    end
                    
                    %             imgFmt = this.getSetting('images.format;
                    %             imageFormats = {'JPEG','PNG'};
                    %             imgSelection = find(strcmpi(imageFormats,imgFmt));
                    %             if(isempty(imgSelection))
                    %                 imgSelection = 1;
                    %             end
                    %             set(this.handles.menu_imageFormat,'string',imageFormats,'value',imgSelection);
                    %
                    featureFcns = fieldnames(PASensorData.getFeatureDescriptionStruct()); %spits field-value pairs of feature names and feature description strings
                    featureDesc = PASensorData.getExtractorDescriptions();  %spits out the string values
                    
                    featureFcns = [featureFcns; 'all_sans_psd';'all_sans_psd_usagestate';'all'];
                    featureLabels = [featureDesc;'All (sans PSD)';'All (sans PSD and activity categories)'; 'All'];
                    
                    
                    featureLabel = this.getSetting('featureLabel');
                    featureSelection = find(strcmpi(featureLabels,featureLabel));
                    
                    if(isempty(featureSelection))
                        featureSelection =1;
                    end
                    set(this.handles.menu_featureFcn,'string',featureLabels,'value',featureSelection,'userdata',featureFcns);
                    
                    % Make visible
                    this.figureH = batchFig;
                    set(this.figureH,'visible','on','closerequestFcn',@this.close);
                    didInit = true;
                catch me
                    showME(me);
                end
            end
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Prepares the current run's log and summary files.
        %> @param this Instance of PABatchTool
        %> @param settings
        %> @retval logFID The <i>open</i> file identifier of the created
        %> log file.
        % --------------------------------------------------------------------        
        function [logFID, logFullFilename, summaryFID, summaryFullFilename] = prepLogAndSummaryFiles(this,settings)
        % --------------------------------------------------------------------
            
            featurePathname = this.getFeaturePathname();
        
            unalignedFeaturePathname = this.getUnalignedFeaturePathname();
            
            startDateTime = datestr(now,'ddmmmyyyy_HHMM');
            
            summaryFilename = settings.summaryFilename.value(); %convert from a PAStringParam
            summaryFilename = strrep(summaryFilename,'@TIMESTAMP',startDateTime);
            
            isormkdir(featurePathname);
            isormkdir(unalignedFeaturePathname);
            
            summaryFullFilename = fullfile(featurePathname,summaryFilename); 
            summaryFID = fopen(summaryFullFilename,'w');
            
            if(summaryFID<0)
                fprintf(1,'Cannot open or create summary file: %s\nSending summary output to the console.\n',summaryFullFilename);
                summaryFID = 1;
            end
            fprintf(summaryFID,'studyID, study_filename, total day count, complete day count, incomplete day count, counts per minute (x), counts per minute (y), counts per minute (z), counts per minute (vec magnitude)\n');
            
            logFilename = settings.logFilename.value();
            logFilename = strrep(logFilename,'@TIMESTAMP',startDateTime);
            logFullFilename = fullfile(settings.outputDirectory.value(),logFilename);
            
            logFID = fopen(logFullFilename,'w');
            if(logFID<0)
                fprintf(1,'Cannot open or create the log file: %s\nSending log output to the console.\n',logFullFilename);
                logFID = 1;
            end
            versionStr = PAAppController.getVersionInfo('num');
            fprintf(logFID,'Padaco batch processing log\nStart time:\t%s\n',startDateTime);
            fprintf(logFID,'Padaco version %s\n',versionStr);
            fprintf(logFID,'Source directory:\t%s\n',settings.sourceDirectory.value());
            fprintf(logFID,'Output directory:\t%s\n',settings.outputDirectory.value());
            fprintf(logFID,'Aligned features (for clustering):\t%s\n',featurePathname);
            fprintf(logFID,'Original features (for clustering):\t%s\n',unalignedFeaturePathname);
            
            fprintf(logFID,'Features:\t%s\n',settings.featureLabel);
            fprintf(logFID,'Frame duration (minutes):\t%0.2f\n',settings.frameDurationMinutes.value());
            
            fprintf(logFID,'Alignment settings:\n');
            fprintf(logFID,'\tElapsed start (hours):\t%u\n',settings.alignment.elapsedStartHours.value());
            fprintf(logFID,'\tInterval length (hours):\t%u\n',settings.alignment.intervalLengthHours.value());
            fprintf(logFID,'Summary file:\t%s\n',summaryFullFilename);
        end 
        
    end
    
    methods(Static)
        % ======================================================================
        %> @brief Returns a structure of PABatchTool default, saveable parameters as a struct.
        %> @retval pStruct A structure of parameters which include the following
        %> fields
        %> - @c sourceDirectory
        %> - @c outputDirectory
        %> - @c alignment.elapsedStartHours when to start the first measurement
        %> - @c alignment.intervalLengthHours  duration of each interval (in hours) once started
        %> - @c frameDurationMinutes
        %> - @c featureLabel;
        %> - @c logFilename
        %> - @c isOutputPathLinked
        %> - @c signalTagLine
        % ======================================================================
        function pStruct = getDefaults()
            try
                docPath = findpath('docs');
            catch
                docPath = fileparts(mfilename('fullpath'));
            end
            
            %             pStruct.sourceDirectory = docPath;
            %             pStruct.outputDirectory = docPath;
            %
            %
            %             pStruct.alignment.elapsedStartHours = 0; %when to start the first measurement
            %             pStruct.alignment.intervalLengthHours = 24;  %duration of each interval (in hours) once started
            %             pStruct.frameDurationMinutes = 15;
            %
            %
            %             pStruct.numDaysAllowed = 7;
            %             pStruct.featureLabel = 'All';
            %             pStruct.logFilename = 'batchRun_@TIMESTAMP.txt';
            %             pStruct.summaryFilename = 'batchSummary_@TIMESTAMP.txt';
            %             pStruct.isOutputPathLinked = false;
            
            pStruct.sourceDirectory = PAPathParam('default',docPath,'description','Source Directory');
            pStruct.outputDirectory = PAPathParam('default',docPath,'description','Output Directory');
            
            pStruct.alignment.elapsedStartHours = PANumericParam('default',0,'Description','Hour of the day to start first measurement','min',0,'max',23.99);
            pStruct.alignment.intervalLengthHours = PANumericParam('default',24,'Description','%Duration of each interval (in hours) once started','min',0,'max',24); 
            pStruct.frameDurationMinutes = PANumericParam('default',15,'Description','Duration of frame in minutes','min',0,'max',24*60);
            
            pStruct.numDaysAllowed = PANumericParam('default',7,'Description','Maximum number of days allowed/used','min',0);

            pStruct.featureLabel = PAStringParam('default','All','description','Feature selection');
            
            pStruct.logFilename = PAStringParam('default','batchRun_@TIMESTAMP.txt','description','Log filename convention');
            pStruct.summaryFilename = PAStringParam('default','batchRun_@TIMESTAMP.txt','description','Summary filename convention');
             
            pStruct.isOutputPathLinked = PABoolParam('default',false,'description','Store output results within same folder as input files');
            

        end            
                
        
    end
end
