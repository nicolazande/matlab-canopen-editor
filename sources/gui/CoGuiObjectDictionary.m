function CoGuiObjectDictionary(tab, fig, functions)
%
% Show all valid object dictionary entries and give the user the
% possibility to search among them, delete and add new ones.
%
% param [in] tab         GUI dedicated tab to populate.
% param [in] fig         Parent figure object storing shared data.
% param [in] functions   Arry of needed common function pointers.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %
    handles = guidata(fig);

    % -------- external functions passed as function pointers ------ %
    stoi = functions{1};
    preProcessTableData = functions{2};
    % ============================================================== %

    % create filter to extract meaningful object dictionary entries
    info = struct('name', '', ...
                  'index', '', ...
                  'subindex', '', ...
                  'datatype', '', ...
                  'value', '');

    % create object dictionary tab entry
    object_dictionary_tab = uitab(tab, 'Title', 'Object Dictionary');

    % create table panel
    table_panel = uipanel(object_dictionary_tab);
    table_panel.Units = 'normalized';
    table_panel.Position = [0.05, 0.05, 0.9, 0.65];
    e_table = uitable(table_panel);
    e_table.Data = struct2table(cell2mat(handles.objects));
    e_table.Units = 'normalized';
    e_table.Position = [0, 0, 1, 1];
    e_table.RowName = 'numbered';
    e_table.ColumnName = {'Name', 'Index', 'SubIndex', 'Data Type', ...
                          'Default Value', 'Object Type', 'Access Type', 'Pdo Mapping'};
    e_table.KeyReleaseFcn = @(src, event)delete_object(src, event, fig);

    % create search panel
    search_panel = uipanel(object_dictionary_tab);
    search_panel.Title = 'Filter';
    search_panel.TitlePosition = 'centertop';
    search_panel.FontSize = 14;
    search_panel.FontWeight = 'bold';
    search_panel.Units = 'normalized';
    search_panel.Position = [0.05, 0.75, 0.9, 0.2];
    search_grid = uigridlayout(search_panel); 
    search_grid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'}; 
    search_grid.RowHeight = {'1x', '1x'};

    % Name related proprieties
    l_name = uilabel(search_grid);
    l_name.Text = 'Name';
    l_name.FontSize = 12;
    l_name.FontWeight = 'bold';
    l_name.Layout.Row = 1;
    l_name.Layout.Column = 1;
    l_name.HorizontalAlignment = 'center';
    e_name = uieditfield(search_grid);
    e_name.ValueChangedFcn = @(x, y) filter_changed_callback(e_name, 'name');
    e_name.Layout.Row = 2;
    e_name.Layout.Column = 1;
    e_name.HorizontalAlignment = 'center';

    % Index related proprieties
    l_index = uilabel(search_grid);
    l_index.Text = 'Index';
    l_index.FontSize = 12;
    l_index.FontWeight = 'bold';
    l_index.Layout.Row = 1;
    l_index.Layout.Column = 2;
    l_index.HorizontalAlignment = 'center';
    e_index = uieditfield(search_grid);
    e_index.ValueChangedFcn = @(x, y)filter_changed_callback(e_index, 'index');
    e_index.Layout.Row = 2;
    e_index.Layout.Column = 2;
    e_index.HorizontalAlignment = 'center';

    % Subindex related proprieties
    l_subindex = uilabel(search_grid);
    l_subindex.Text = 'SubIndex';
    l_subindex.FontSize = 12;
    l_subindex.FontWeight = 'bold';
    l_subindex.Layout.Row = 1;
    l_subindex.Layout.Column = 3;
    l_subindex.HorizontalAlignment = 'center';
    e_subindex = uieditfield(search_grid);
    e_subindex.ValueChangedFcn = @(x, y)filter_changed_callback(e_subindex, 'subindex');
    e_subindex.Layout.Row = 2;
    e_subindex.Layout.Column = 3;
    e_subindex.HorizontalAlignment = 'center';

    % Data Type related proprieties
    l_datatype = uilabel(search_grid);
    l_datatype.Text = 'Data Type';
    l_datatype.FontSize = 12;
    l_datatype.FontWeight = 'bold';
    l_datatype.Layout.Row = 1;
    l_datatype.Layout.Column = 4;
    l_datatype.HorizontalAlignment = 'center';
    e_datatype = uidropdown(search_grid);
    e_datatype.Items = {'', 'SS_BOOLEAN', ...
                        'SS_UINT8','SS_INT8', ...
                        'SS_UINT16', 'SS_INT16', ...
                        'SS_UINT32', 'SS_INT32', ...
                        'SS_UINT64', 'SS_INT64', ...
                        'SS_SINGLE', 'SS_DOUBLE'};
    e_datatype.Value = '';
    e_datatype.ValueChangedFcn = @(x, y)filter_changed_callback(e_datatype, 'datatype');
    e_datatype.Layout.Row = 2;
    e_datatype.Layout.Column = 4;

    % Value related proprieties
    l_value = uilabel(search_grid);
    l_value.Text = 'Value';
    l_value.FontSize = 12;
    l_value.FontWeight = 'bold';
    l_value.Layout.Row = 1;
    l_value.Layout.Column = 5;
    l_value.HorizontalAlignment = 'center';
    e_value = uieditfield(search_grid);
    e_value.ValueChangedFcn = @(x, y)filter_changed_callback(e_value, 'value');
    e_value.Layout.Row = 2;
    e_value.Layout.Column = 5;
    e_value.HorizontalAlignment = 'center';

    % Search push button
    search_button_object = uibutton(search_grid);
    search_button_object.Text = 'Search';
    search_button_object.FontSize = 12;
    search_button_object.FontWeight = 'bold';
    search_button_object.ButtonPushedFcn = @(x, y)button_pushed_callback();
    search_button_object.Layout.Row = 2;
    search_button_object.Layout.Column = 6;

    % New push button
    new_button_object = uibutton(search_grid);
    new_button_object.Text = 'New';
    new_button_object.FontSize = 12;
    new_button_object.FontWeight = 'bold';
    new_button_object.ButtonPushedFcn = @(x, y)add_object();
    new_button_object.Layout.Row = 1;
    new_button_object.Layout.Column = 6;

    %% private functions dedicated section
    function filter_changed_callback(src, dest)
    %
    % Edit fields and drop down common callback: update the global
    % filter with the condition specified in the selected uicontrol.
    %
    % param [in] src         Source edit field.
    % param [in] dest        Destination filter.
    %
        info.(dest) = src.Value;
    end

    function button_pushed_callback()
    %
    % Search button pushed callback: get filtered data from overall table
    % and redraw it. Keep original data alive.
    %
        % get subset of interesting entries according to filter
        match = filter_entries(handles.objects, ...
                               info.name, ...
                               info.index, ...
                               info.subindex, ...
                               info.datatype);
        match = preProcessTableData(match);
        e_table.Data = match;
    end

    function [items, idx] = filter_entries(objects, name, index, subindex, datatype)
    %
    % Filter elements found in EDS file according specified proprieties.
    %
    % param [in] name         Target object name.
    % param [in] index        Target object index.
    % param [in] subindex     Target object subindex.
    % param [in] datatype     Target object data type.
    %
        idx =  ...
            arrayfun(@(x) ...
                all(isfield(objects{x}, {'name', 'index', 'subindex', 'datatype'})) && ...
                contains(objects{x}.name, name, 'IgnoreCase',true) && ...
                contains(objects{x}.index, index, 'IgnoreCase',true) && ...
                contains(objects{x}.subindex, subindex, 'IgnoreCase',true) && ...
                contains(objects{x}.datatype, datatype, 'IgnoreCase',true), ...
            1:numel(objects));
        % return only filtered elements
        items = objects(idx);
    end

    function add_object()
    %
    % Add object dictionary entry.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %
        ttParamDefaultRecordType = '0x9'; %#ok<NASGU> 
        ttParamDefaultObjectType = '0x7';
        ttParamDefaultAccessType = 'rw';
        ttParamDefaultPdoMapping = '0x1';
        % ============================================================== %
        % get handles
        handles = guidata(fig);
        % get numeric index
        nindex = stoi(info.index); found = 0;
        if ~isnan(nindex)
            if nindex < stoi(handles.objects{1}.index)
                % insert in first place
                pos = 1; found = 1;
            elseif nindex > stoi(handles.objects{end}.index)
                % insert in last place
                pos = numel(handles.objects) + 1; found = 1;
            else
                % get insertion position
                pos = numel(handles.objects) + 1;
                for i = 2 : numel(handles.objects)
                    % current and previous items in object dictionary
                    prev_idx = stoi(handles.objects{i-1}.index);
                    curr_idx = stoi(handles.objects{i}.index);
                    % move until next index
                    if ~isnan(prev_idx) && ~isnan(curr_idx) && curr_idx > nindex
                        % check previous index
                        if prev_idx ~= nindex
                            pos = i; found = 1;
                        else
                            error(['An object with index: ', ...
                                   handles.objects{i-1}.index, ...
                                   32, 'already exists!']);
                        end
                        break;
                    end
                end
            end
            % check if insertion place found
            if ~found
                error('No insertion place found!');
            end
            % add object to object dictionary
            handles.objects = { ...
                handles.objects{1:pos-1}, ...
                struct('name', info.name, ...
                'index', info.index, ...
                'subindex', '', ... %TODO: keep always empty
                'datatype', info.datatype, ...
                'value', info.value, ...
                'objecttype', ttParamDefaultObjectType, ...
                'accesstype', ttParamDefaultAccessType, ...
                'pdomapping', ttParamDefaultPdoMapping), ...
                handles.objects{pos:end}};
            % update view
            e_table.Data = struct2table(cell2mat(handles.objects));
            % store modified data in figure (always)
            guidata(fig, handles);
        end
    end

    function delete_object(src, event, fig)
    %
    % Delete object dictionary entry.
    %
    % param [in] src         Current source figure object.
    % param [in] event       Last user event.
    % param [in] fig         Common parent figure with shared data.
    %
        % gui shared data handles
        handles = guidata(fig);
        % get user selected row and column
        r = event.Source.Selection(1);
        c = event.Source.Selection(2); %#ok<NASGU> 
        % get table row (object)
        obj = src.Data(r, :);

        % process event
        switch event.Key
    
            % delete object
            case {'backspace', 'delete'}
        
                % search item in object dictionary
                pos = NaN;
                for i = 1 : numel(handles.objects)
                    if strcmp(obj.index, handles.objects{i}.index) && ...
                       strcmp(obj.subindex, handles.objects{i}.subindex) && ...
                       strcmp(obj.datatype, handles.objects{i}.datatype)
                        % save position
                        pos = i;
                        break;
                    end
                end
                % check if entry found
                if ~isnan(pos)
                    % remove object from object dictionary
                    handles.objects = {handles.objects{1:pos-1}, handles.objects{pos+1:end}};
                    % clear view
                    src.Data(r, :) = [];
                    % store modified data in figure (always)
                    guidata(fig, handles);
                end
        end
    end

end