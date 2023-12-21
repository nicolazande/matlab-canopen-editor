function CoGuiDevice(tab, fig, functions)
%
% Show general device and info regarding the selected CANopen Node.
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
    getOdInfo = functions{2};
    % ============================================================== %

    % create object dictionary tab entry
    info_tab = uitab(tab, 'Title', 'General Info');
   
    % device panel
    device_info.labels = {'Vendor Name', 'Vendor Number', 'Product Name', 'Product Number'};
    device_info.keys = {'VendorName', 'VendorNumber', 'ProductName', 'ProductNumber'};
    device_info.slots = cell(4, 2);
    device_panel = uipanel(info_tab);
    device_panel.Title = 'Vendor and Device';
    device_panel.TitlePosition = 'centertop';
    device_panel.FontSize = 14;
    device_panel.FontWeight = 'bold';
    device_panel.Units = 'normalized';
    device_panel.Position = [0.05, 0.65, 0.425, 0.3];
    device_grid = uigridlayout(device_panel); 
    device_grid.RowHeight = {'1x', '1x', '1x', '1x'};
    device_grid.ColumnWidth = {'1x', '1x'};
    for i = 1 : numel(device_info.keys)
        device_info.slots{i, 1} = uilabel(device_grid);
        device_info.slots{i, 1}.Text = device_info.labels{i};
        device_info.slots{i, 1}.FontSize = 12;
        device_info.slots{i, 1}.FontWeight = 'bold';
        device_info.slots{i, 1}.Layout.Row = i;
        device_info.slots{i, 1}.Layout.Column = 1;
        device_info.slots{i, 1}.HorizontalAlignment = 'left';
        device_info.slots{i, 2} = uieditfield(device_grid);
        % get value from EDS
        tmp = getOdInfo(handles.lines, device_info.keys{i});
        % set value to editfield
        set(device_info.slots{i, 2}, 'Value', tmp);
        device_info.slots{i, 2}.Editable = 'on';
        device_info.slots{i, 2}.Layout.Row = i;
        device_info.slots{i, 2}.Layout.Column = 2;
        device_info.slots{i, 2}.HorizontalAlignment = 'left';
        % add value change callback
        device_info.slots{i, 2}.ValueChangedFcn = ...
            @(src, ~)update_device_callback(src, device_info.keys{i});
        % save value in handles
        handles.device_info.(device_info.keys{i}) = tmp;
    end

    % file panel
    file_info.labels = {'File Name', 'Description', 'File Version', 'Modification Date'};
    file_info.keys = {'FileName', 'Description', 'FileVersion', 'ModificationDate'};
    file_info.slots = cell(4, 2);
    file_panel = uipanel(info_tab);
    file_panel.Title = 'File';
    file_panel.TitlePosition = 'centertop';
    file_panel.FontSize = 14;
    file_panel.FontWeight = 'bold';
    file_panel.Units = 'normalized';
    file_panel.Position = [0.525, 0.65, 0.425, 0.3];
    file_grid = uigridlayout(file_panel); 
    file_grid.RowHeight = {'1x', '1x', '1x', '1x'};
    file_grid.ColumnWidth = {'1x', '1x'};
    for i = 1 : numel(file_info.keys)
        file_info.slots{i, 1} = uilabel(file_grid);
        file_info.slots{i, 1}.Text = file_info.labels{i};
        file_info.slots{i, 1}.FontSize = 12;
        file_info.slots{i, 1}.FontWeight = 'bold';
        file_info.slots{i, 1}.Layout.Row = i;
        file_info.slots{i, 1}.Layout.Column = 1;
        file_info.slots{i, 1}.HorizontalAlignment = 'left';
        file_info.slots{i, 2} = uieditfield(file_grid);
        % get value from EDS
        tmp = getOdInfo(handles.lines, file_info.keys{i});
        % set value to editfield
        set(file_info.slots{i, 2}, 'Value', tmp);
        file_info.slots{i, 2}.Editable = 'on';
        file_info.slots{i, 2}.Layout.Row = i;
        file_info.slots{i, 2}.Layout.Column = 2;
        file_info.slots{i, 2}.HorizontalAlignment = 'left';
        % add value change callback
        file_info.slots{i, 2}.ValueChangedFcn = ...
            @(src, ~)update_file_callback(src, file_info.keys{i});
        % save value in handles
        handles.file_info.(file_info.keys{i}) = tmp;
    end

    % PDO - SRDO panel
    device_info.labels = {'RPDO count', 'TPDO count', 'RX-SRDO count', 'TX-SRDO count'};
    % get number of active RPDO
    try
        n_rpdo =  num2str(nnz(arrayfun(@(x) ...
            (stoi(handles.objects{x}.index) >= 0x1600) && ...
            (stoi(handles.objects{x}.index) < 0x1800) && ...
            (stoi(handles.objects{x}.subindex) == 1), ...
            1:numel(handles.objects))));
    catch
        n_rpdo = '0';
    end
    % get number of active TPDO
    try
        n_tpdo =  num2str(nnz(arrayfun(@(x) ...
            (stoi(handles.objects{x}.index) >= 0x1800) && ...
            (stoi(handles.objects{x}.index) < 0x1A00) && ...
            (stoi(handles.objects{x}.subindex) == 1), ...
            1:numel(handles.objects))));
    catch
        n_tpdo = '0';
    end
    % get number of active RX-SRDO
    try
        n_rsrdo =  num2str(nnz(arrayfun(@(x) ...
            (stoi(handles.objects{x}.index) > 0x1300) && ...
            (stoi(handles.objects{x}.index) < 0x1380) && ...
            (stoi(handles.objects{x}.subindex) == 1) && ...
            (stoi(handles.objects{x}.value) == 2), ...
            1:numel(handles.objects))));
    catch
        n_rsrdo = '0';
    end
    % get number of active TX-SRDO
    try
        n_tsrdo =  num2str(nnz(arrayfun(@(x) ...
            (stoi(handles.objects{x}.index) > 0x1300) && ...
            (stoi(handles.objects{x}.index) < 0x1380) && ...
            (stoi(handles.objects{x}.subindex) == 1) && ...
            (stoi(handles.objects{x}.value) == 1), ...
            1:numel(handles.objects))));
    catch
        n_tsrdo = '0';
    end
    % set values retrieved from EDS
    device_info.values = {n_rpdo, n_tpdo, n_rsrdo, n_tsrdo};
    device_info.slots = cell(2, 4);
    device_panel = uipanel(info_tab);
    device_panel.Units = 'normalized';
    device_panel.Position = [0.05, 0.45, 0.9, 0.15];
    device_grid = uigridlayout(device_panel); 
    device_grid.RowHeight = {'1x', '1x'};
    device_grid.ColumnWidth = {'1x', '1x', '1x', '1x'};
    for i = 1 : numel(device_info.values)
        device_info.slots{1, i} = uilabel(device_grid);
        device_info.slots{1, i}.Text = device_info.labels{i};
        device_info.slots{1, i}.FontSize = 12;
        device_info.slots{1, i}.FontWeight = 'bold';
        device_info.slots{1, i}.Layout.Row = 1;
        device_info.slots{1, i}.Layout.Column = i;
        device_info.slots{1, i}.HorizontalAlignment = 'center';
        device_info.slots{2, i} = uieditfield(device_grid);
        set(device_info.slots{2, i}, 'Value', device_info.values{i});
        device_info.slots{2, i}.Editable = 'off';
        device_info.slots{2, i}.Layout.Row = 2;
        device_info.slots{2, i}.Layout.Column = i;
        device_info.slots{2, i}.HorizontalAlignment = 'center';
    end

    % save updated handles
    guidata(fig, handles);

    function update_device_callback(src, slot)
    %
    % Update device inforamtion in global structure.
    %
    % param [in] src   Source edit field.
    % param [in] slot  Struct specific edit field.
    %
        if isfield(handles.device_info, slot)
            handles = guidata(fig);
            handles.device_info.(slot) = src.Value;
            guidata(fig, handles);
        end
    end

    function update_file_callback(src, slot)
    %
    % Update file inforamtion in global structure.
    %
    % param [in] src   Source edit field.
    % param [in] slot  Struct specific edit field.
    %
        if isfield(handles.file_info, slot)
            handles = guidata(fig);
            handles.file_info.(slot) = src.Value;
            guidata(fig, handles);
        end
    end

end



