% ======================================================================
%> @file PADataLineSettings.cpp
%> @brief Class for updating display properties of data found in a PAData
%> object.
% ======================================================================
%> @brief The PADataLineSettings class handles the interface between the
%> line handles connected with PAData signals.
% ======================================================================
classdef PADataLineSettings < handle
    properties(Constant)
        figureFcn = @singleStudyDisplaySettings;
    end
    properties(SetAccess=protected)
        figureH;
        viewSelection;
    end
    properties(Access=protected)
        dataObj;
        labels;
        handles;
    end
    methods
        function this = PADataLineSettings(dataObjIn, viewSelection, lineHandles)
            this.figureH = this.figureFcn('visible','off');
            set(this.figureH,'visible','on');
            this.handles = guidata(this.figureH);
            if(nargin<2 || ~isa(dataObjIn,'PAData') || ~any(strcmpi(viewSelection,fieldnames(dataObjIn.label))))
                
            else
                viewSelections = fieldnames(dataObjIn.label); % have to watch out for cases where view selection comes in as 'timeseries' and field name is actually 'timeSeries'
                this.viewSelection = viewSelections{strcmpi(viewSelections,viewSelection)};
                this.dataObj = dataObjIn;
                this.buildRows(lineHandles);
            end
            this.initCallbacks();
            set(this.figureH,'visible','on');
        end 
        
        function numLines = getNumLines(this, structIn)
            if(nargin<2)
                numLines = this.getNumLines(this.dataObj.label.(this.viewSelection));
            else
                if(isstruct(structIn))
                    numLines = 0;
                    fNames = fieldnames(structIn);
                    for f=1:numel(fNames)
                        numLines = numLines + this.getNumLines(structIn.(fNames{f}));
                    end                    
                else                    
                    numLines = 1;
                end
            end
        end
        
        function showAll(this)
            set(this.getCheckboxHandles(),'value',1);
        end
        
        function hideAll(this)
            set(this.getCheckboxHandles(),'value',0);
        end
        
        function h= getCheckboxHandles(this)
            h = findobj(this.figureH,'style','checkbox');
        end
    end
    methods(Access=protected)
        function initCallbacks(this)
            set(this.handles.push_showAll,'callback',@this.showAllCallback);
            set(this.handles.push_showAll,'callback',@this.hideAllCallback);
            set(this.handles.push_cancel,'callback',@this.cancelCallback);
            set(this.handles.push_confirm,'callback',@this.confirmCallback);
        end
        
        % GUI Callbacks
        function showAllCallback(this, hObject, evtData)
            this.showAll();
        end
        function hideAllCallback(this, hObject, evtData)
            this.hideAll();
        end
        function cancelCallback(this, hObject, evtData)
            this.cancel();
        end
        function confirmCallback(this, hObject, evtData)
            this.confirm();
        end
    end
    
    methods(Access=private)
        function buildRows(this, lineHandles)
            % Delta referes to yDelta
            numLines = numel(lineHandles);

            row_label_h = [this.handles.text_visible, this.handles.text_name, this.handles.text_color,...
                this.handles.text_scale, this.handles.text_offset];
            
            row_template_tags = {'check_show_%d','push_color_%d','edit_scale_%d','edit_offset_%d'};
            row_1_tags = {'check_show_1','push_color_1','edit_scale_1','edit_offset_1'};
            
            row_1_h = cellfun(@(x)(this.handles.(x)),row_1_tags,'uniformoutput',false);
            
            linePanelPos = get(this.handles.panel_lineProperties,'position');
            
            % buttonPanelPos = get(this.handles.panel_buttons,'position');
            % The button panel doesn't need to adjustment b/c they it's the
            % bottomest row and moves with the figure's resizing.  
            
            figurePos = get(this.figureH,'position');
            labelPos = get(this.handles.text_visible,'position');
            % labelRow_marginTop = linePanelPos(4) - labelPos(2);
            row1Pos = get(this.handles.check_show_1,'position');
            rowYDelta = labelPos(2) - row1Pos(2);
            panelDelta = (numLines-1)*rowYDelta;            
            
            figurePos(2) = figurePos(2)-panelDelta;  % shift down
            figurePos(4) = figurePos(4)+panelDelta;  % then grow up
%             buttonPanelPos(2) = buttonPanelPos(2) - panelDelta; % shift down - is this necessary?
            linePanelPos(4) = linePanelPos(4) + panelDelta;
            set(this.figureH,'position',figurePos);
%             set(this.handles.panel_buttons,'position',buttonPanelPos);
            set(this.handles.panel_lineProperties,'position',linePanelPos);
            
            %labelPos(2) = labelPos(2)+panelDelta;
            %row1Pos(2) = row1Pos(2)+panelDelta;
            
            for col=1:numel(row_label_h)
                h = row_label_h(col);
                pos = get(h,'position');
                pos(2) = pos(2)+panelDelta;
                set(h,'position',pos);
            end
            
            for col=1:numel(row_1_h)
                h = row_1_h{col};
                pos = get(h,'position');
                pos(2) = pos(2)+panelDelta;
                set(h,'position',pos);
            end
            
            for row = 2:numLines
                for col=1:numel(row_template_tags)
                    curRowTag = sprintf(row_template_tags{col},row);
                    prevRowTag = sprintf(row_template_tags{col},row-1);
                    prevH = get(this.handles.(prevRowTag));
                    prevH.tag = curRowTag;
                    prevH.Position(2) = prevH.Position(2)-rowYDelta;
                    prevH = rmfield(prevH,{'Extent','BeingDeleted','Type'});
                    this.handles.(curRowTag) = uicontrol(prevH); 
                    set(this.handles.(curRowTag),'position',prevH.Position);
                end                
            end
            
            %set(this.handles.text_visible,'position',labelPos);
            %set(this.handles.check_show_1,'position',row1Pos);
            
        end
    end
end