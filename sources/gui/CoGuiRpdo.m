function CoGuiRpdo(tab, fig, functions)
%
% Get RPDO information and show tham in correspondent gui tab.
%
% param [in] tab         GUI dedicated tab to populate.
% param [in] fig         Parent figure object storing shared data.
% param [in] functions   Arry of needed common function pointers.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %
        
    % -------- external functions passed as function pointers ------ %
    stoi = functions{1};
    getPDO = functions{2};
    preProcessTableData = functions{3};
    CoGuiPdoMappingCallback = functions{4};
    CoGuiPdoCommunicationCallback = functions{5};
    % ============================================================== %

    % create object dictionary tab entry
    rpdo_info_tab = uitab(tab, 'Title', 'RPDO');

    % get table values for all RPDO
    [comm_table_values, map_table_values] = getPDO(fig, 0x1400, 0x1600);

    % create communication table
    communication_panel = uipanel(rpdo_info_tab);
    communication_panel.Title = 'Communication Section';
    communication_panel.TitlePosition = 'centertop';
    communication_panel.FontSize = 14;
    communication_panel.FontWeight = 'bold';
    communication_panel.Units = 'normalized';
    communication_panel.Position = [0.05, 0.45, 0.9, 0.35];
    communication_table = uitable(communication_panel);
    communication_table.ColumnEditable = true;
    communication_table.Data = preProcessTableData(comm_table_values);
    communication_table.Units = 'normalized';
    communication_table.Position = [0, 0, 1, 1];
    communication_table.RowName = 'numbered';
    communication_table.ColumnName = {'Index', 'COB-ID', 'Channel', 'Transmission Type', 'Inhibit Time', 'Event Timer'};
    communication_table.KeyReleaseFcn = @(src, event)CoGuiPdoCommunicationCallback(src, event, communication_table, fig);
    communication_table.CellEditCallback = @(src, event)comm_value_changed_wrapper(src, event, fig);
    set(communication_table, 'ColumnEditable', true(1, width(communication_table)));

    % create mapping table
    mapping_panel = uipanel(rpdo_info_tab);
    mapping_panel.Title = 'Mapping Section';
    mapping_panel.TitlePosition = 'centertop';
    mapping_panel.FontSize = 14;
    mapping_panel.FontWeight = 'bold';
    mapping_panel.Units = 'normalized';
    mapping_panel.Position = [0.05, 0.05, 0.9, 0.35];
    mapping_table = uitable(mapping_panel);
    mapping_table.Data = preProcessTableData(map_table_values);
    mapping_table.Units = 'normalized';
    mapping_table.Position = [0, 0, 1, 1];
    mapping_table.RowName = 'numbered';
    mapping_table.ColumnName = {'Index', 'COB-ID', 'Data[0]', 'Data[1]', 'Data[2]', 'Data[3]', 'Data[4]', 'Data[5]', 'Data[6]', 'Data[7]' };
    mapping_table.KeyReleaseFcn = @(src, event)CoGuiPdoMappingCallback(src, event, mapping_table, fig);

    % create button panel
    button_panel = uipanel(rpdo_info_tab);
    button_panel.Units = 'normalized';
    button_panel.Position = [0.05, 0.85, 0.9, 0.1];
    button_grid = uigridlayout(button_panel); 
    button_grid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x', '1x'}; 
    button_grid.RowHeight = {'1x'};

    % index label and edit
    index_label = uilabel(button_grid);
    index_label.Text = 'Index';
    index_label.FontSize = 12;
    index_label.FontWeight = 'bold';
    index_label.Layout.Row = 1;
    index_label.Layout.Column = 1;
    index_label.HorizontalAlignment = 'right';
    index_edit = uieditfield(button_grid);
    index_edit.Layout.Row = 1;
    index_edit.Layout.Column = 2;
    index_edit.HorizontalAlignment = 'center';

    % cob-id label and edit
    cob_id_label = uilabel(button_grid);
    cob_id_label.Text = 'COD-ID';
    cob_id_label.FontSize = 12;
    cob_id_label.FontWeight = 'bold';
    cob_id_label.Layout.Row = 1;
    cob_id_label.Layout.Column = 3;
    cob_id_label.HorizontalAlignment = 'right';
    cob_id_edit = uieditfield(button_grid);
    cob_id_edit.Layout.Row = 1;
    cob_id_edit.Layout.Column = 4;
    cob_id_edit.HorizontalAlignment = 'center';

    % new pdo button
    button_object = uibutton(button_grid);
    button_object.Text = 'new rpdo';
    button_object.FontSize = 12;
    button_object.FontWeight = 'bold';
    button_object.ButtonPushedFcn = @(src, event)add_pdo(index_edit, cob_id_edit, communication_table, mapping_table, fig);
    button_object.Layout.Row = 1;
    button_object.Layout.Column = 6;

    function add_pdo(index_edit, cob_id_edit, comm_table, map_table, fig)
    %
    % Create new RPDO.
    %
    % param [in] index_edit   Edit field used to retrieve the user defined index.
    % param [in] cob_id_edit  Edit field used to retrieve the user defined cob-id.
    % param [in] comm_table   Communication table.
    % param [in] map_table    Mapping table.
    % param [in] fig         Common parent figure with shared data.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
     
        % ------------------ mask/utils parameters --------------------- %  
        ttParamMapOffset = 512;
            
        % ============================================================== %

        % check user inputs
        if ~isnan(stoi(index_edit.Value)) && ~isnan(stoi(cob_id_edit.Value))
            % user inputs
            comm_index = ['0x', dec2hex((stoi(index_edit.Value)))];
            map_index = ['0x', dec2hex((stoi(comm_index)+ttParamMapOffset))];
            cob_id = ['0x', dec2hex(stoi(cob_id_edit.Value))];
            % create communication record
            add_comm_record(comm_index, cob_id, comm_table, fig);
            % create mapping record
            add_map_record(map_index, map_table, fig);
        end
    end

    function add_comm_record(sindex, scob, table, fig)
    %
    % Create new mapping record for RPDO.
    %
    % param [in] sindex      User defined index (string).
    % param [in] scob        User defined cob-id (string).
    % param [in] table       Communication table.
    % param [in] fig         Common parent figure with shared data.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %  
        ttParamLowIndex = 0x1400;
        ttParamHighIndex = 0x1600;
        ttParamVarNames = {'index', 'cobid', 'channel', 'type', 'inhibit', 'eventtimer'};
        ttParamDefaultRecordType = '0x9';
        ttParamDefaultObjectType = '0x7';
        ttParamDefaultAccessType = 'rw';
        ttParamDefaultPdoMapping = '0x0';   
        % ------------------- gui shared data handles ------------------ %
        handles = guidata(fig);
        % ============================================================== %
        
        % get numeric index
        index = stoi(sindex);
        cob = stoi(scob);
        % check index validity
        if ~isnan(index) && ~isnan(cob) && (isempty(table.Data) || ~any(stoi(table.Data.index) == index))
            % create new pdo map record
            pdo = cell2table(repmat({''}, size(ttParamVarNames)), 'VariableNames', ttParamVarNames);
            % check if index is in range
            if index >= ttParamLowIndex && index < ttParamHighIndex
                % update view
                pdo.index{1, 1} = sindex;
                pdo.cobid{1, 1} = scob;
                warning('off', 'all');
                table.Data = [table.Data; pdo];
                warning('on', 'all');
                % find right place in object dictionary
                pos = numel(handles.objects) + 1;
                for i = 1 : numel(handles.objects)
                    tmp_idx = stoi(handles.objects{i}.index);
                    if ~isnan(tmp_idx) && tmp_idx > index
                        pos = i;
                        break;
                    end
                end
                % add record and all sub-entries in object dictionary
                record = struct('name', ['RPDO', num2str(height(table)), 'Communication Parameter'], ...
                                'index', sindex, ...
                                'subindex', '', ...
                                'datatype', '', ...
                                'value', '', ...
                                'objecttype', ttParamDefaultRecordType, ...
                                'accesstype', '', ...
                                'pdomapping', '');
                n_entries = struct('name', 'Highest Sub-Index Supported', ...
                                   'index', sindex, ...
                                   'subindex', '0x0', ...
                                   'datatype', 'SS_UINT8', ...
                                   'value', '0x5', ...
                                   'objecttype', ttParamDefaultObjectType, ...
                                   'accesstype', 'ro', ...
                                   'pdomapping', ttParamDefaultPdoMapping);
                cob_id = struct('name', 'COB-ID Used By RPDO', ...
                                'index', sindex, ...
                                'subindex', '0x1', ...
                                'datatype', 'SS_UINT32', ...
                                'value', scob, ...
                                'objecttype', ttParamDefaultObjectType, ...
                                'accesstype', ttParamDefaultAccessType, ...
                                'pdomapping', ttParamDefaultPdoMapping);
                trans_type = struct('name', 'Transmission Type', ...
                                    'index', sindex, ...
                                    'subindex', '0x2', ...
                                    'datatype', 'SS_UINT8', ...
                                    'value', '255', ...
                                    'objecttype', ttParamDefaultObjectType, ...
                                    'accesstype', ttParamDefaultAccessType, ...
                                    'pdomapping', ttParamDefaultPdoMapping);
                event_timer = struct('name', 'Event Timer', ...
                                    'index', sindex, ...
                                    'subindex', '0x5', ...
                                    'datatype', 'SS_UINT16', ...
                                    'value', '0', ...
                                    'objecttype', ttParamDefaultObjectType, ...
                                    'accesstype', ttParamDefaultAccessType, ...
                                    'pdomapping', ttParamDefaultPdoMapping);
                % update object dictionary with mandatory entries
                handles.objects = {handles.objects{1:pos-1}, ...
                                   record, ...
                                   n_entries, ...
                                   cob_id, ...
                                   trans_type, ...
                                   event_timer, ...
                                   handles.objects{pos:end}};
                % update figure handles
                guidata(fig, handles);
            end
        end
    end
    
    function add_map_record(sindex, table, fig)
    %
    % Create new mapping record for RPDO.
    %
    % param [in] sindex      User defined index (string).
    % param [in] table       Mapping table.
    % param [in] fig         Common parent figure with shared data.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %  
        ttParamLowIndex = 0x1600;
        ttParamHighIndex = 0x1800;
        ttParamCobIdSubindex = 1;
        ttParamVarNames = {'index', 'cobid', 'byte0', 'byte1', 'byte2', ...
                           'byte3', 'byte4', 'byte5', 'byte6', 'byte7'};
        ttParamDefaultRecordType = '0x9';
        ttParamDefaultObjectType = '0x7';
        ttParamDefaultAccessType = 'rw'; %#ok<NASGU> 
        ttParamDefaultPdoMapping = '0x0';   
        % ------------------- gui shared data handles ------------------ %
        handles = guidata(fig);
        % ============================================================== %
   
        % get numeric index
        index = stoi(sindex);
        % check index validity
        if ~isnan(index) && (isempty(table.Data) || ~any(strcmp(table.Data.index, sindex)))
            % create new pdo map record
            pdo = cell2table(repmat({''}, size(ttParamVarNames)), 'VariableNames', ttParamVarNames);
            % check if index is in range
            if index >= ttParamLowIndex && index < ttParamHighIndex
                % find respective communication record (cob_id parameter)
                cob_id = handles.objects(arrayfun(@(x) ...
                    stoi(handles.objects{x}.index) == index - (ttParamHighIndex-ttParamLowIndex) && ...
                    stoi(handles.objects{x}.subindex) == ttParamCobIdSubindex, ...
                    1:numel(handles.objects)));
                % proceed only with correnct communication record
                if ~isempty(cob_id)
                    % update view
                    pdo.index{1, 1} = sindex;
                    pdo.cobid{1, 1} = cob_id{1, 1}.value;
                    warning('off', 'all');
                    table.Data = [table.Data; pdo];
                    warning('on', 'all');
                    % new map data
                    map_data = struct( ...
                        'index', sindex, ...
                        'cobid', '', ...
                        'nmo', 0, ...
                        'byte0', struct('name', ['RPDO_', num2str(height(table))], 'index', index, 'subindex', 0, 'length', 1), ...
                        'byte1', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
                        'byte2', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
                        'byte3', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
                        'byte4', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
                        'byte5', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
                        'byte6', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
                        'byte7', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0));
                    % update overall rpdo map data
                    handles.rpdo_map_data = {handles.rpdo_map_data{1:end}, map_data};
                    % find right place in object dictionary
                    pos = numel(handles.objects) + 1;
                    for i = 1 : numel(handles.objects)
                        tmp_idx = stoi(handles.objects{i}.index);
                        if ~isnan(tmp_idx) && tmp_idx > index
                            pos = i;
                            break;
                        end
                    end
                    % add record and entry zero objects in object dictionary
                    record = struct('name', ['RPDO', num2str(height(table)), 'Mapping Parameter'], ...
                                    'index', sindex, ...
                                    'subindex', '', ...
                                    'datatype', '', ...
                                    'value', '', ...
                                    'objecttype', ttParamDefaultRecordType, ...
                                    'accesstype', '', ...
                                    'pdomapping', '');
                    n_entries = struct('name', 'Highest Sub-Index Supported', ...
                                       'index', sindex, ...
                                       'subindex', '0x0', ...
                                       'datatype', 'SS_UINT8', ...
                                       'value', '0', ...
                                       'objecttype', ttParamDefaultObjectType, ...
                                       'accesstype', 'ro', ...
                                       'pdomapping', ttParamDefaultPdoMapping);
                    % update object dictionary with mandatory entries
                    handles.objects = {handles.objects{1:pos-1}, record, n_entries, handles.objects{pos:end}};
                    % update figure handles
                    guidata(fig, handles);
                end
            end
        end
    end

    function comm_value_changed_wrapper(src, event, fig)
    %
    % Communication table value changed function wrapper.
    %
    % param [in] src    Communication table.
    % param [in] event  Current event.
    % param [in] fig    Common parent figure with shared data.
    %
        % get user selected row and column
        r = event.Indices(1); c = event.Indices(2);
        % pass r and c to new evend (get modified cell, not new one selected)
        event.Source.Selection(1) = r; event.Source.Selection(2) = c;
        % get propriety
        p = src.Data.Properties.VariableNames{c};
        % modify source
        src.Data.(p){r} = event.EditData;
        % call communication callback with modified data
        CoGuiPdoCommunicationCallback(src, event, src, fig);
    end

end



