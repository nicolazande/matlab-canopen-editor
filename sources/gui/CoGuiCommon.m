function CoGuiCommon(fig, functions)
%
% Common section for CANopen gui.
%
% param [in] fig         Parent figure object storing shared data.
% param [in] functions   Arry of needed common function pointers.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %
        
    % -------- external functions passed as function pointers ------ %
    stoi = functions{1};
    CoGetDataCode = functions{2};
    CoGetOdPropriety = functions{3}; %#ok<NASGU> 
    % ============================================================== %

    % create button panel
    common_panel = uipanel(fig);
    common_panel.Units = 'normalized';
    common_panel.Position = [0.40, 0.025, 0.2, 0.075];
    common_grid = uigridlayout(common_panel); 
    common_grid.ColumnWidth = {'1x'}; 
    common_grid.RowHeight = {'1x'};

    % print button
    button_object = uibutton(common_grid);
    button_object.Text = 'Export EDS';
    button_object.FontSize = 12;
    button_object.FontWeight = 'bold';
    button_object.ButtonPushedFcn = @(src, event)export(fig);
    button_object.Layout.Row = 1;
    button_object.Layout.Column = 1;

    function export(fig)
    %
    % Export EDS file.
    %
    % param [in] fig    Common parent figure with shared data.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %

        % ------------------ mask/utils parameters --------------------- %
        ttParamEntry = {'[', ']'};
        ttParamSubEntry = 'sub';
        ttParamName = 'ParameterName=';
        ttParamObjectType = 'ObjectType=';
        ttParamDataType = 'DataType=';
        ttParamAccessType = 'AccessType=';
        ttParamValue = 'DefaultValue=';
        ttParamPdoMapping = 'PDOMapping=';
        % ------------------- gui shared data handles ------------------ %
        handles = guidata(fig);
        % ============================================================== %

        % open a save file dialog
        [name, path, ~] = uiputfile('*.eds', 'Save As', 'od.eds');
        file = fullfile(path, name);
        if ~isempty(file) && ischar(file) && ischar(path) && isfolder(path)
            % open file
            fid = fopen(file,'w');
            try
                % print device info
                print_base_info();
                % print objects
                for o = 1 : numel(handles.objects)
                    print_object(handles.objects{o});
                end
            catch
                fclose(fid);
                error('Error in writing EDS file!');
            end
            % close file
            fclose(fid);
        end

        function print_object(obj)
        %
        % Print object to file.
        %
        % param [in] obj    Object to be printed.
        %
            % check if index is valid
            if ~isnan(stoi(obj.index))
                % get index and subindex
                index = dec2hex(stoi(obj.index)); subindex = '';
                if isfield(obj, 'subindex') && ~isnan(stoi(obj.subindex))
                    subindex = [ttParamSubEntry, dec2hex(stoi(obj.subindex))];
                end
                % print entry index and subindex
                fprintf(fid, [ttParamEntry{1}, index, subindex, ttParamEntry{2}]);
                fprintf(fid, newline);
                % entry name
                if isfield(obj, 'name') && ~isempty(obj.name)
                    fprintf(fid, [ttParamName, obj.name]);
                    fprintf(fid, newline);
                end
                % print entry objecttype
                if isfield(obj, 'objecttype') && ~isempty(obj.objecttype)
                    fprintf(fid, [ttParamObjectType, obj.objecttype]);
                    fprintf(fid, newline);
                end
                % print entry datatype
                if isfield(obj, 'datatype') && ~isempty(obj.datatype)
                    fprintf(fid, [ttParamDataType, CoGetDataCode(obj.datatype)]);
                    fprintf(fid, newline);
                end
                % entry accesstype
                if isfield(obj, 'accesstype') && ~isempty(obj.accesstype)
                    fprintf(fid, [ttParamAccessType, obj.accesstype]);
                    fprintf(fid, newline);
                end
                % print entry value
                if isfield(obj, 'value') && ~isempty(obj.value)
                    fprintf(fid, [ttParamValue, obj.value]);
                    fprintf(fid, newline);
                end
                % print entry pdomapping
                if isfield(obj, 'pdomapping') && ~isempty(obj.pdomapping)
                    fprintf(fid, [ttParamPdoMapping, obj.pdomapping]);
                    fprintf(fid, newline);
                end
                fprintf(fid, newline);
            end
        end

        function print_base_info()
        %
        % Print basic information to file.
        %
            % ============= CONFIG SECTION ================================= %
            %   If some names in the block mask change modify here as well   %
        
            % ------------------ mask/utils parameters --------------------- %
            ttParamEdsVersion = '4.2';
            ttParamDeviceInfo = {'VendorName', 'VendorNumber', 'ProductName', 'ProductNumber'};
            ttParamFileInfo = {'FileName', 'Description', 'FileVersion', 'ModificationDate'};
            % ============================================================== %

            % get number of rpdo
            n_rpdo = get_pdo_number(0x1600, 0x1800);
            % get number of tpdo
            n_tpdo = get_pdo_number(0x1800, 0x1A00);
            % get number of srdo
            n_srdo = get_pdo_number(0x1301, 0x1380);

            % file info
            fprintf(fid, '[FileInfo]'); fprintf(fid, newline);
            for i = 1 : numel(ttParamFileInfo)
                fprintf(fid, [ttParamFileInfo{i}, '=', handles.file_info.(ttParamFileInfo{i})]);
                fprintf(fid, newline);
            end
            fprintf(fid, 'CreatedBy=TTC CANopen Designer'); fprintf(fid, newline);
            fprintf(fid, ['EDSVersion=', ttParamEdsVersion]); fprintf(fid, newline);
            fprintf(fid, newline);

            % device info
            fprintf(fid, '[DeviceInfo]'); fprintf(fid, newline);
            for i = 1 : numel(ttParamDeviceInfo)
                fprintf(fid, [ttParamDeviceInfo{i}, '=', handles.device_info.(ttParamDeviceInfo{i})]);
                fprintf(fid, newline);
            end
            fprintf(fid, ['NrOfRXPDO=', n_rpdo]); fprintf(fid, newline);
            fprintf(fid, ['NrOfTXPDO=', n_tpdo]); fprintf(fid, newline);
            fprintf(fid, ['NrOfSRDO=', n_srdo]); fprintf(fid, newline);
            fprintf(fid, newline);

            function ret = get_pdo_number(comm_index, map_index)
            %
            % Get number of pdo from global data in a specific index range.
            %
            % param [in] comm_index   Index of first communication record.
            % param [in] map_index    Index of first mapping record.
            %
            % return     ret    Number of pdo found.
            %
                ret = num2str(nnz(arrayfun(@(x) ...
                    all(isfield(handles.objects{x}, {'index', 'subindex'})) && ...
                    (stoi(handles.objects{x}.index) >= comm_index) && ...
                    (stoi(handles.objects{x}.index) < map_index) && ...
                    (stoi(handles.objects{x}.subindex) == 1), ...
                    1:numel(handles.objects))));
            end
        end

    end

end




