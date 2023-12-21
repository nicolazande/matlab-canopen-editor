function CoGui(eds_path)
%
% Main function for the Matlab EDS viewer\editor.
%
% param [in] eds_path     EDS file path.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %
        
    % ------------------ mask/utils parameters --------------------- %
    ttParamFigureHeight = 625; ttParamFigureWidth = 900;
    % ============================================================== %

    % open and read EDS file
    if ~isfile(eds_path)
        error('Invilid EDS path specified');
    end
    try  
        fid = fopen(eds_path, 'r'); 
    catch
        error ('Invalid EDS path specified!');
    end
    data = textscan(fid, '%s','delimiter', '\t');
    fclose(fid);
    
    % process raw data and get meaningfull information
    [lines, objects] = CoPostProcessData(data);

    % get screen size
    ssz = get(0, 'ScreenSize'); sw = mean(ssz([1, 3])); sh = mean(ssz([2, 4]));
    
    % create overall figure
    fig = uifigure('Position', [sw - ttParamFigureWidth/2, ...
                                sh - ttParamFigureHeight/2, ...
                                ttParamFigureWidth, ...
                                ttParamFigureHeight], ...
                   'Name', 'Simulink CANopen Explorer');

    % set figure handle with shared data
    handles.objects  = objects;
    handles.rpdo_map_data = {};
    handles.tpdo_map_data = {};
    handles.srdo_map_data = {};
    handles.lines = lines;
    handles.file_info = struct('FileName', '', ...
                               'Description', '', ...
                               'FileVersion', '', ...
                               'ModificationDate', '');
    handles.device_info = struct('VendorName', '', ...
                                 'VendorNumber', '', ...
                                 'ProductName', '', ...
                                 'ProductNumber', '');

    % save updated handles
    guidata(fig, handles);

    % create main window
    tab = uitabgroup(fig);
    tab.Units = 'normalized';
    tab.Position = [0.0, 0.125, 1, 0.875];

    % setup common section 
    CoGuiCommon(fig, {@stoi, ...
                      @CoGetDataCode, ...
                      @CoGetOdPropriety});

    % setup general info tab
    CoGuiDevice(tab, fig, {@stoi, ...
                           @CoGetOdPropriety});

    % setup object dictionary tab
    CoGuiObjectDictionary(tab, fig, {@stoi, ...
                                     @CoPreProcessTableData});

    % setup rpdo tab
    CoGuiRpdo(tab, fig, {@stoi, ...
                         @CoSetupPDO, ...
                         @CoPreProcessTableData, ...
                         @CoGuiPdoMappingCallback, ...
                         @CoGuiPdoCommunicationCallback});

    % setup tpdo tab
    CoGuiTpdo(tab, fig, {@stoi, ...
                         @CoSetupPDO, ...
                         @CoPreProcessTableData, ...
                         @CoGuiPdoMappingCallback, ...
                         @CoGuiPdoCommunicationCallback});

    % setup srdo tab
    CoGuiSrdo(tab, fig, {@stoi, ...
                         @CoSetupSRDO, ...
                         @CoPreProcessTableData, ...
                         @CoGuiPdoMappingCallback, ...
                         @CoGuiSrdoCommunicationCallback});

end


%% public helper functions dedicated section
function num = stoi(str)
%
% Get numeric value from string considering also hex numbers.
%
% param [in] str   String (or char array) representing the number.
%
% return     num   Correspondent numerical value.
%
    if any(contains(str, {'0x', 'A', 'B', 'C', 'D', 'E', 'F'}))
        % hex number
        try num = hex2dec(str); catch; num = NaN; end
    else
        % decimal number (returns NaN on error)
        num = str2double(str);
    end
end

function ret = CoGetDataType(code)
%
% Get Simulink data type from CANopenNode data type code.
%
% param [in] code   CANopenNode data type code.
%
% return     ret    Simulink data type.
%
    try
        switch (code)
            case 1
                ret = 'SS_BOOLEAN';
            case 2
                ret = 'SS_INT8';
            case 3
                ret = 'SS_INT16';
            case 4
                ret = 'SS_INT32';
            case 5
                ret = 'SS_UINT8';
            case 6
                ret = 'SS_UINT16';
            case 7
                ret = 'SS_UINT32';
            case 8
                ret = 'SS_SINGLE';
            case {9, 10, 11}
                ret = 'SS_STRING';
            case 17
                ret = 'SS_DOUBLE';
            case 21
                ret = 'SS_INT64';
            case 27
                ret = 'SS_UINT64';
            otherwise
                ret = '';
        end
    catch
        ret = '';
    end
end

function ret = CoGetDataCode(type)
%
% Get CANopenNode data type code from Simulink data type.
%
% param [in] type   Simulink data type.
%
% return     ret    CANopenNode data type code.
%
    try
        switch (type)
            case 'SS_BOOLEAN'
                ret = '0x1';
            case 'SS_INT8'
                ret = '0x2';
            case 'SS_INT16'
                ret = '0x3';
            case 'SS_INT32'
                ret = '0x4';
            case 'SS_UINT8'
                ret = '0x5';
            case 'SS_UINT16'
                ret = '0x6';
            case 'SS_UINT32'
                ret = '0x7';
            case 'SS_SINGLE'
                ret = '0x8';
            case 'SS_STRING'
                ret = '0x9';
            case 'SS_DOUBLE'
                ret = '0x11';
            case 'SS_INT64'
                ret = '0x15';
            case 'SS_UINT64'
                ret = '0x1B';
            otherwise
                ret = '';
        end
    catch
        ret = '';
    end
end

function ret = CoGetDataSize(code)
%
% Get data size in bytes from Simulink data type code.
%
% param [in] code   Simulink data type code.
%
% return     ret    Size in bytes of the data type.
%
    try
        switch (code)
            case {'SS_BOOLEAN', 'SS_UINT8', 'SS_INT8'}
                ret = 1;
            case {'SS_UINT16', 'SS_INT16'}
                ret = 2;
            case {'SS_SINGLE', 'SS_UINT32', 'SS_INT32'}
                ret = 4;
            case {'SS_DOUBLE', 'SS_UINT64', 'SS_INT64'}
                ret = 8;
            otherwise
                ret = 0;
        end
    catch
        ret = 0;
    end
end

function code = CoObjectCodeMapping(obj)
%
% Encode map value given object and size.
%
% param [in] obj   CANopen object.
%
% return     code  Encoded object information.
%
    nbytes = CoGetDataSize(obj.datatype{1, 1});
    code = uint32(bitsll(uint32(stoi(obj.index)), 16));
    code = uint32(bitor(code, bitsll(uint32(stoi(obj.subindex)), 8)));
    code = uint32(bitor(code, uint32(nbytes) * 8));
end

function [index, subindex, length] = CoObjectDecodeMapping(code)
%
% Decode map value and return index, subindex and length (in bytes).
%
% param [in] code   Encoded (index, subindex, length) information.
%
% return     index   Object index.
%            index   Object subindex.
%            length  Object length in bytes.
%
    index = bitsra(uint32(stoi(code)), 16);
    subindex = bitsra(bitand(uint32(stoi(code)), uint32(0xFF00)), 8);
    length = bitand(uint32(stoi(code)), uint32(0xFF)) / 8;
end

function [val, idx] = CoFindOdRecord(objects, index)
%
% Helper function to search a record in the object dictionary.
%
% param [in] objects     List of objects to search in.
% param [in] index       Index to search for.
% param [in] subindex    SubIndex to search for.
%
% return val             Flag signaling if object found.
%        idx             Position of object in objects.
%
    [val, idx] = max(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex'})) && ...
        stoi(objects{x}.index) == index && ...
        isnan(stoi(objects{x}.subindex)) && ...
        isempty(CoFilterValidDataType(objects(x))), ...
        1:numel(objects)));
end

function [val, idx] = CoFindOdVar(objects, index, subindex)
%
% Helper function to search a variable in the object dictionary. There
% is distinction between empty and zero subindex, this is important
% in order t get the number of entries in a record.
%
% param [in] objects     List of objects to search in.
% param [in] index       Index to search for.
% param [in] subindex    SubIndex to search for.
%
% return val             Flag signaling if object found.
%        idx             Position of object in objects.
%
    [val, idx] = max(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex'})) && ...
        stoi(objects{x}.index) == index && ...
        stoi(objects{x}.subindex) == subindex, ...
        1:numel(objects)));
end

function [val, idx] = CoFindOdItem(objects, index, subindex)
%
% Helper function to search an item in the object dictionary. It can
% search for both record and standalone objects, since an empty subindex
% is considered zero.
%
% param [in] objects     List of objects to search in.
% param [in] index       Index to search for.
% param [in] subindex    SubIndex to search for.
%
% return val             Flag signaling if object found.
%        idx             Position of object in objects.
%
    [val, idx] = max(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex'})) && ...
        uint32(stoi(objects{x}.index)) == index && ...
        uint8(stoi(objects{x}.subindex)) == subindex, ...
        1:numel(objects)));
end

function valid = CoFilterValidDataType(objects)
%
% Helper function to filter only selectable objects in object dictionary
% according to datata type.
%
% param [in] objects     List of objects to search in.
%
% return valid           List of valid (selectable) objects.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %
    ttParamValidDataTypes = {'SS_BOOLEAN', ...
                             'SS_UINT8', 'SS_INT8', ...
                             'SS_UINT16', 'SS_INT16', ...
                             'SS_UINT32', 'SS_INT32', ...
                             'SS_UINT64', 'SS_INT64', ...
                             'SS_SINGLE', 'SS_UINT64'};
    % ============================================================== %
    valid = objects(arrayfun(@(x) ...
        any(strcmp(ttParamValidDataTypes, objects{x}.datatype)), ...
        1:numel(objects)));
end

function valid = CoExcludeRange(objects, lb, up)
%
% Helper function to filter only selectable objects in object dictionary
% according to index.
%
% param [in] objects     List of objects to search in.
% param [in] lb          Lower bound of non acceptable objects range.
% param [in] ub          Upper bound of non acceptable objects range.
%
% return valid           List of valid (selectable) objects.
%
    valid = objects(arrayfun(@(x) ...
        isfield(objects{x}, 'index') && ...
        stoi(objects{x}.index) < lb || ...
        stoi(objects{x}.index) > up, ...
        1:numel(objects)));
end

function data = CoPreProcessTableData(data)
%
% Prepare data for a Matlab GUI table.
%
% param [in] data   Encoded (index, subindex, length) information.
%
    nItems = numel(data);
    if nItems == 0
        data = table.empty;
    elseif nItems == 1
        data = struct2table(data{1}, 'AsArray', true);
    else
        data = struct2table(cell2mat(data));
    end
end

function val = CoGetOdPropriety(od, propriety)
%
% Extract propriety value from EDS file in form of cell array of
% charachter vectors (lines) and return it as character vector if
% found or nothing if not.
%
% param [in] od          Object dictionary (cell array).
% param [in] propriety   Specific device info propriety to search for.
%
    % value of propriety to search
    val = '';
    % search in all lines
    nLines = numel(od);
    for l = 1 : nLines
        % look for first matching line
        if contains(od(l), propriety)
            try
                % get raw value (unknown data type a priori)
                tmp = extractAfter(od(l), [propriety, '=']);
                if iscell(tmp)
                    val = tmp{1};
                elseif isstring(tmp)
                    val = tmp(1);
                elseif ischar(tmp)
                    val = tmp;
                end
            catch
                val = '';
            end
            % early stop
            break;
        end
    end
end

function [lines, objects] = CoPostProcessData(data)
%
% Postprocess data collected from EDS file.
%
% param [in] data     Raw input data.
%
% return lines        Char array of raw lines.
%        objects      Char array of struct representing objects.
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
    % ============================================================== %

    % prepare data
    lines = data{:};
    nFileLines = numel(lines);
    objects = cell(1, nFileLines);
    j = 1;
    % loop over all EDS file lines
    for i = 1 : nFileLines
        % get entry
        if contains(lines{i}, ttParamEntry)
            % number of proprieties for the current entry/subentry
            nProprieties = 1;
            while (i + nProprieties < nFileLines) && (~contains(lines{i+nProprieties}, ttParamEntry))
                nProprieties = nProprieties + 1;
            end
            % get entry name
            name = get_propriety(ttParamName);
            % check if name is valid
            if ~isempty(name)
                % get index from current line (possibly mixed with subindex)
                index = ['0x', char(extractBetween(lines{i}, ttParamEntry{1}, ttParamEntry{2}))];
                % check if object is subentry
                subindex = '';
                if contains(index, ttParamSubEntry)
                    % extract subindex
                    subindex = ['0x', char(extractAfter(index, ttParamSubEntry))];
                    % extract index
                    index = char(extractBefore(index, ttParamSubEntry));
                end
                % get objet proprieties
                value = get_propriety(ttParamValue);
                datatype = CoGetDataType(stoi(get_propriety(ttParamDataType)));
                objecttype = get_propriety(ttParamObjectType);
                accesstype = get_propriety(ttParamAccessType);
                pdomapping = get_propriety(ttParamPdoMapping);
                % invalid index (go on and skip it)
                if isnan(stoi(index))
                    continue;
                end
                % add new object to list
                objects{j} = struct('name', name, ...
                                    'index', index, ...
                                    'subindex', subindex, ...
                                    'datatype', datatype, ...
                                    'value', value, ...
                                    'objecttype', objecttype, ...
                                    'accesstype', accesstype, ...
                                    'pdomapping', pdomapping);
                % increment object index
                j = j + 1; 
            end
        end
    end
    % remove unused entries in cell array
    objects(j:end) = [];

    function value = get_propriety(p)
    %
    % Get object propriety.
    %
    % param [in] p       Name of propriety to search for.
    %
    % return     vaule   Value of propriety searched.
    %
        value = '';
        for l = 1 : nProprieties
            if (contains(lines{i+l}, p))
                value = extractAfter(lines{i+l}, p);
                break;
            end
        end
    end

end


%% gui callback functions dedicated section
function [comm_array, map_array] = CoSetupPDO(fig, comm_index, map_index)
%
% Get PDO (RPDO and TPDO) mapping and communication records as cell
% arrays of structs containing all meaningful information needed for
% the visualization on the gui.
%
% param [in] fig         Common figure where data is stored.
% param [in] comm_index  Communication record first index.
% param [in] map_index   Mapping record first index.
%
% return comm_array      Updated communication array.
%        map_array       Updated mapping array.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %  
    ttParamMaxMappedBytes = 8;

    % ------------------- gui shared data handles ------------------ %
    handles = guidata(fig);
    objects = handles.objects;
    % ============================================================== %

    % filter communication objects only
    comm_objects = objects(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex', 'value'})) && ...
        (stoi(objects{x}.index) >= comm_index) && ...
        (stoi(objects{x}.index) < map_index), ...
        1:numel(objects)));
    % filter mapping objects only
    map_objects = objects(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex', 'value'})) && ...
        (stoi(objects{x}.index) >= map_index) && ...
        (stoi(objects{x}.index) < map_index + (map_index - comm_index)), ...
        1:numel(objects)));

    % get number of max items according to communication objects
    nItems = nnz(arrayfun(@(x) (stoi(comm_objects{x}.subindex) == 0), 1:numel(comm_objects)));
    comm_array = cell(1, nItems);
    map_array = cell(1, nItems);
    map_data_array = cell(1, nItems);

    % comm and map counters
    comm_entries = 0; map_entries = 0; lex = max(cellfun(@(x) stoi(x.index), comm_objects));
    if isempty(lex) || isnan(lex)
        lex = 0;
    else
        lex = lex - comm_index;
    end

    % process all items (accept also unordered items)
    for j = 0 : lex

        % communication record
        comm = struct('index', '', 'cobid', '', 'channel', '', ...
                      'type', '', 'inhibit', '', 'eventtimer', '');
        % mapping record
        map = struct('index', '', 'cobid', '', ...
                     'byte0', '', 'byte1', '', 'byte2', '', 'byte3', '', ...
                     'byte4', '', 'byte5', '', 'byte6', '', 'byte7', '');
        % map data used for reverse mapping in write phase
        map_data = struct(  ...
            'index', '', ...
            'cobid', '', ...
            'nmo', 0, ...
            'byte0', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte1', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte2', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte3', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte4', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte5', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte6', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte7', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0));

        %% communication
        % get interesting subindeces (discard subindex zero)
        subindeces = comm_objects(arrayfun(@(x) ...
            (stoi(comm_objects{x}.index) == comm_index + j) && ...
            (stoi(comm_objects{x}.subindex) > 0), ...
            1:numel(comm_objects)));
        % fill record
        nSubindeces = numel(subindeces);
        if nSubindeces > 0
            % set index
            comm.index = subindeces{1}.index;
            % loop over possible subindeces
            for s = 1 : nSubindeces
                % get subindex
                osubindex = subindeces{s};
                % fill record
                switch uint8(stoi(osubindex.subindex))
                    case 1
                        %cobid
                        comm.cobid = osubindex.value;
                    case 2
                        %transmissio type
                        comm.type = osubindex.value;
                    case 3
                        %inhibit time
                        comm.inhibit = osubindex.value;
                    case 4
                        %channel
                        comm.channel = osubindex.value;
                    case 5
                        %event timer
                        comm.eventtimer = osubindex.value;
                end
            end
            % populate communication array
            comm_array{comm_entries+1} = comm;
            % increment number of valid entries
            comm_entries = comm_entries + 1;
        end
        
        %% mapping
        % get interesting subindeces (discard subindex zero)
        subindeces = map_objects(arrayfun(@(x) ...
            (stoi(map_objects{x}.index) == map_index + j) && ...
            (stoi(map_objects{x}.subindex) > 0), ...
            1:numel(map_objects)));
        % fill record
        nSubindeces = numel(subindeces);
        if nSubindeces > 0
            % set index
            map.index = subindeces{1}.index;
            map_data.index = map.index;
            % comm and map need to have the same cobid
            map.cobid = comm.cobid;
            map_data.cobid = map.cobid;
            map_data.nmo = 0;
            % mapped object size (in bytes)
            mapped_bytes = 0;
            % loop over possible subindeces
            for s = 1 : nSubindeces
                % get target object info (index, subindex, length (in bytes))
                [oindex, osubindex, olength] = CoObjectDecodeMapping(subindeces{s}.value);
                % try to get mapped object if exists
                if olength > 0 && oindex > 0
                    for o = 1 : numel(objects)
                        % check if index and subindex match with no empty-zero subIndex distinction (faster than array function)
                        if uint32(stoi(objects{o}.index)) == oindex && uint32(stoi(objects{o}.subindex)) == osubindex
                            % check if datatype matches (stupid users put it wrong)
                            if olength == CoGetDataSize(objects{o}.datatype)
                                % try to add to mapped objects list
                                for k = mapped_bytes : mapped_bytes+olength-1
                                    if k < ttParamMaxMappedBytes
                                        % update view
                                        map.(['byte', num2str(k)]) = objects{o}.name;
                                        % update map data
                                        map_data.(['byte', num2str(k)]).name = objects{o}.name;
                                        map_data.(['byte', num2str(k)]).index = map_index + j;
                                        map_data.(['byte', num2str(k)]).subindex = stoi(subindeces{s}.subindex);
                                        map_data.(['byte', num2str(k)]).length = olength;
                                    end
                                end
                                % increase object counter
                                map_data.nmo = map_data.nmo + 1;
                                % increase mapped object size
                                mapped_bytes = mapped_bytes + olength;
                            end
                            % stop object found
                            break;
                        end
                    end
                end
            end
            % populate mapping array
            map_array{map_entries+1} = map;
            map_data_array{map_entries+1} = map_data;
            % increment number of valid entries
            map_entries = map_entries + 1;
        end
    end
    % remove empty cells (present due to wrong EDS config)
    map_array = map_array(~cellfun('isempty', map_array));
    comm_array = comm_array(~cellfun('isempty', comm_array));
    % update handles with proper map
    handles = set_map_type(handles, comm_index, map_index, map_data_array);
    % store modified data in figure
    guidata(fig, handles);

    function handles = set_map_type(handles, comm_index, map_index, map_data_array)
    %
    % Set proper map field to figure handles.
    %
    % param [in] handles         Figure handles.
    % param [in] comm_index      Communication record first index.
    % param [in] map_index       Mapping record first index.
    % param [in] map_data_array  Map used to update handles.
    %
    % return     handles   Updated figure handles.
    %  
        if comm_index == 0x1400 && map_index == 0x1600
            handles.rpdo_map_data = map_data_array(~cellfun('isempty', map_data_array));
        elseif comm_index == 0x1800 && map_index == 0x1A00
            handles.tpdo_map_data = map_data_array(~cellfun('isempty', map_data_array));
        end
    end

end

function [comm_array, map_array] = CoSetupSRDO(fig, comm_index, map_index)
%
% Get SRDO (TX and RX) mapping and communication recors as cell arrays
% of structs containing all meaningful information needed for the
% visualization on the gui.
%
% param [in] fig         Common figure where data is stored.
% param [in] comm_index  Communication record first index.
% param [in] map_index   Mapping record first index.
%
% return comm_array      Updated communication array.
%        map_array       Updated mapping array.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %  
    ttParamMaxMappedBytes = 16;
    ttParamReservedIdx = 3;

    % ------------------- gui shared data handles ------------------ %
    handles = guidata(fig);
    objects = handles.objects;
    % ============================================================== %

    % filter communication objects only
    comm_objects = objects(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex', 'value'})) && ...
        (stoi(objects{x}.index) >= comm_index) && ...
        (stoi(objects{x}.index) < map_index), ...
        1:numel(objects)));
    % filter mapping objects only
    map_objects = objects(arrayfun(@(x) ...
        all(isfield(objects{x}, {'index', 'subindex', 'value'})) && ...
        (stoi(objects{x}.index) >= map_index) && ...
        (stoi(objects{x}.index) < map_index + (map_index - comm_index)), ...
        1:numel(objects)));

    % get number of max items according to communication objects
    nItems = nnz(arrayfun(@(x) (stoi(comm_objects{x}.subindex) == 0), 1:numel(comm_objects)));
    comm_array = cell(1, nItems);
    map_array = cell(1, nItems);
    map_data_array = cell(1, nItems);

    % comm and map counters
    comm_entries = 0; map_entries = 0; lex = max(cellfun(@(x) stoi(x.index), comm_objects));
    if isempty(lex) || isnan(lex)
        lex = 0;
    else
        lex = lex - comm_index - ttParamReservedIdx;
    end

    % process all items (accept also unordered items)
    for j = 0 : lex

        % communication record
        comm = struct('index', '', 'cobid_normal', '', 'cobid_inverted', '', ...
                      'direction', '', 'channel', '', 'refresh_time', '', ...
                      'srvt', '', 'transmissiontype', '');
        % mapping record
        map = struct('index', '', 'cobid', '', ...
                     'byte0', '', 'byte1', '', 'byte2', '', 'byte3', '', ...
                     'byte4', '', 'byte5', '', 'byte6', '', 'byte7', '', ...
                     'byte8', '', 'byte9', '', 'byte10', '', 'byte11', '', ...
                     'byte12', '', 'byte13', '', 'byte14', '', 'byte15', '');
        % map data used for reverse mapping in write phase
        map_data = struct(  ...
            'index', '', ...
            'cobid', '', ...
            'nmo', 0, ...
            'byte0',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte1',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte2',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte3',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte4',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte5',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte6',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte7',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte8',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte9',  struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte10', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte11', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte12', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte13', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte14', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0), ...
            'byte15', struct('name', '', 'index', 0, 'subindex', 0, 'length', 0));

        %% communication
        % get interesting subindeces (discard subindex zero)
        subindeces = comm_objects(arrayfun(@(x) ...
            (stoi(comm_objects{x}.index) == comm_index + j) && ...
            (stoi(comm_objects{x}.subindex) > 0), ...
            1:numel(comm_objects)));
        % fill record
        nSubindeces = numel(subindeces);
        if nSubindeces > 0
            % set index
            comm.index = subindeces{1}.index;
            % loop over possible subindeces (subindex zero not meaningful)
            for s = 1 : nSubindeces
                % get subindex
                n_subindex = subindeces{s};
                % fill record
                switch uint8(stoi(n_subindex.subindex))
                    case 1
                        %direction
                        comm.direction = n_subindex.value;
                    case 2
                        %refresh time
                        comm.refresh_time = n_subindex.value;
                    case 3
                        %srvt
                        comm.srvt = n_subindex.value;
                    case 4
                        %transmission type
                        comm.transmissiontype = n_subindex.value;
                    case 5
                        %cobid normal
                        comm.cobid_normal = n_subindex.value;
                    case 6
                        %cobid inverted
                        comm.cobid_inverted = n_subindex.value;
                    case 7
                        %channel
                        comm.channel = n_subindex.value;
                end
            end
            % populate communication array
            comm_array{comm_entries+1} = comm;
            % increment number of valid entries
            comm_entries = comm_entries + 1;
        end
        
         %% mapping
        % get interesting subindeces (discard subindex zero)
        subindeces = map_objects(arrayfun(@(x) ...
            (stoi(map_objects{x}.index) == map_index + j) && ...
            (stoi(map_objects{x}.subindex) > 0), ...
            1:numel(map_objects)));
        % fill record
        nSubindeces = numel(subindeces);
        if nSubindeces > 0
            % set index
            map.index = subindeces{1}.index;
            map_data.index = map.index;
            % comm and map need to have the same cobid
            map.cobid = comm.cobid_normal;
            map_data.cobid = map.cobid;
            map_data.nmo = 0;
            % mapped object size (in bytes)
            mapped_bytes = 0;
            % loop over possible subindeces
            for s = 1 : nSubindeces
                % get target object info (index, subindex, length (in bytes))
                [oindex, osubindex, olength] = CoObjectDecodeMapping(subindeces{s}.value);
                % try to get mapped object if exists
                if olength > 0 && oindex > 0
                    for o = 1 : numel(objects)
                        % check if index and subindex match with no empty-zero subIndex distinction (faster than array function)
                        if uint32(stoi(objects{o}.index)) == oindex && uint32(stoi(objects{o}.subindex)) == osubindex
                            % check if datatype matches (stupid users put it wrong)
                            if olength == CoGetDataSize(objects{o}.datatype)
                                % try to add to mapped objects list
                                for k = mapped_bytes : mapped_bytes+olength-1
                                    if k < ttParamMaxMappedBytes
                                        % update view
                                        map.(['byte', num2str(k)]) = objects{o}.name;
                                        % update map data
                                        map_data.(['byte', num2str(k)]).name = objects{o}.name;
                                        map_data.(['byte', num2str(k)]).index = map_index + j;
                                        map_data.(['byte', num2str(k)]).subindex = stoi(subindeces{s}.subindex);
                                        map_data.(['byte', num2str(k)]).length = olength;
                                    end
                                end
                                % increase object counter
                                map_data.nmo = map_data.nmo + 1;
                                % increase mapped object size
                                mapped_bytes = mapped_bytes + olength;
                            end
                            % stop object found
                            break;
                        end
                    end
                end
            end
            % populate mapping array
            map_array{map_entries+1} = map;
            map_data_array{map_entries+1} = map_data;
            % increment number of valid entries
            map_entries = map_entries + 1;
        end
    end
    % remove empty cells (present due to wrong EDS config)
    map_array = map_array(~cellfun('isempty', map_array));
    comm_array = comm_array(~cellfun('isempty', comm_array));
    % update common data
    handles.srdo_map_data = map_data_array(~cellfun('isempty', map_data_array));
    % store modified data in figure
    guidata(fig, handles);
end

function CoGuiPdoMappingCallback(src, event, table, fig)
%
% Entry point for the PDO and SRDO Gui mapping section callbacks.
%
% param [in] src         Current source figure object.
% param [in] event       Last user event.
% param [in] table       Private table to be updated (for sisualization).
% param [in] fig         Common parent figure with shared data.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %  
    ttParamDataIndex = 3;
        
    % ------------------- gui shared data handles ------------------ %
    handles = guidata(fig);
    % ============================================================== %

    % check if cell valid
    if ~isempty(event.Source.Selection)
        % disable warning for empty table
        warning('off', 'all');
        % get user selected row and column
        r = event.Source.Selection(1); c = event.Source.Selection(2);
        % get row (PDO mapping record)
        pdo = src.Data(r, :);
        % get proper map (keep RPDO and TPDO maps separated DIOBRASCA)
        map_data = get_map_type(handles, pdo);
    
        % process event
        switch event.Key
    
            % delete object
            case {'backspace', 'delete'}
                % delete single pdo map
                if c >= ttParamDataIndex
                    delete_slot_callback(c);
                %delete whole pdo releted data
                else
                    delete_pdo_callback();
                end
                 
            % add new entry
            case {'return', 'space'}
                % allow input only for empty cells
                if c >= ttParamDataIndex
                    enter_callback(c);
                end
        end
        % reenable warning for empty table
        warning('on', 'all');
    end

    function delete_pdo_callback()
    %
    % First level callback used to delete a whole pdo.
    %
    % param [in] c   User selected column index.
    %
        % get all object matching pdo index
        idx = arrayfun(@(x) ...
            strcmp(handles.objects{x}.index, pdo.index), ...
            1:numel(handles.objects));
        % remove objects from object dictionary
        handles.objects = handles.objects(~idx);
        % delete pdo specific map data
        map_data(r) = [];
        % refresh view
        src.Data(r, :) = [];
        % update handles anf figure
        handles = set_map_type(handles, pdo, map_data);
        guidata(fig, handles);
    end

    function delete_slot_callback(c)
    %
    % First level callback used to delete a single pdo map.
    %
    % param [in] c   User selected column index.
    %
        % get original size (fixed)
        tsz = size(src.Data.Properties.VariableNames);
        % empty buffer used to shit and  store final data
        buffer = repmat({''}, tsz);
        % get user selected column name
        p = src.Data.Properties.VariableNames{c};
        % get user selected map
        selected_map = map_data{r}.(p);
        % remove subEntry from object dictionary
        [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), selected_map.subindex);
        if sum(val, 'all') > 0
            handles.objects = {handles.objects{1:pos-1}, handles.objects{pos+1:end}};
        end
        % loop over byte columns
        for i = ttParamDataIndex : tsz(2)
            % get i-th column propriety name
            p = src.Data.Properties.VariableNames{i};
            % if subindex and name match remove it (it's same object)
            if isempty(pdo.(p){1, 1}) || ...
                (map_data{r}.(p).subindex == selected_map.subindex && ...
                 strcmp(map_data{r}.(p).name, selected_map.name))
                pdo = removevars(pdo, p);
            end
        end
        % update buffer size with removed variables
        bsz = size(pdo);
        % shift everything left
        buffer(1:bsz(1), 1:bsz(2)) = table2array(pdo);
        % tmp map data that can be processed safely
        tmp_map_data = map_data{r};
        % local indeces and map keys
        k = 1; b = 1; r_ctv = ''; r_ntv = ''; %#ok<NASGU>
        % fix map_data for future use when single byte remaining (important)
        if bsz(2) == ttParamDataIndex
            % get new table variable name (read mode from modified pdo)
            r_ntv = pdo.Properties.VariableNames{bsz(2)};
            % get standard table variable name (write mode to table)
            w_ntv = src.Data.Properties.VariableNames{bsz(2)};
            % get next map variables from map
            nmv = map_data{r}.(r_ntv);
            % update current map
            tmp_map_data.(w_ntv).name = nmv.name;
            tmp_map_data.(w_ntv).length = nmv.length;
            tmp_map_data.(w_ntv).subindex = k;
        end
        % fix map_data for future use
        for i = ttParamDataIndex : bsz(2)-1
            % get new table variable names (read mode from modified pdo)
            r_ctv = pdo.Properties.VariableNames{i};
            r_ntv = pdo.Properties.VariableNames{i+1};
            % get standard table variable names (write mode to table)
            w_ctv = src.Data.Properties.VariableNames{i};
            w_ntv = src.Data.Properties.VariableNames{i+1};
            % get current and next map variables from map
            cmv = map_data{r}.(r_ctv);
            nmv = map_data{r}.(r_ntv);
            % update current map
            tmp_map_data.(w_ctv).name = cmv.name;
            tmp_map_data.(w_ctv).length = cmv.length;
            tmp_map_data.(w_ctv).subindex = k;
            % different variable (name + size check)
            if ~strcmp(cmv.name, nmv.name) || b >= cmv.length
                % shift object dictionary map subindexes
                [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), cmv.subindex);
                if sum(val, 'all') > 0
                    handles.objects{pos}.subindex = ['0x', num2str(dec2hex(k))];
                end
                % increase subindex count and reset variable length
                k = k + 1; b = 1;
            else
                % increase variable length
                b = b + 1;
            end
            % update next map
            tmp_map_data.(w_ntv).name = nmv.name;
            tmp_map_data.(w_ntv).length = nmv.length;
            tmp_map_data.(w_ntv).subindex = k;
        end
        % shift last object dictionary map subindex independently
        if ~isempty(r_ntv)
            [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), map_data{r}.(r_ntv).subindex);
            if sum(val, 'all') > 0
                handles.objects{pos}.subindex = ['0x', num2str(dec2hex(k))];
            end
        end
        % erase last unused columns
        for i = bsz(2)+1 : tsz(2)
            p = src.Data.Properties.VariableNames{i};
            tmp_map_data.(p) = struct('name', '', 'index', 0, 'subindex', 0, 'length', 0);
        end
        % update global map
        map_data{r} = tmp_map_data;
        % decrease object counter and assign to subindex zero
        map_data{r}.nmo = map_data{r}.nmo - 1;
        [val, idx] = CoFindOdVar(handles.objects, stoi(pdo.index), 0);
        if sum(val, 'all') > 0
            handles.objects{idx}.value = ['0x', num2str(dec2hex(map_data{r}.nmo))];
        end
        % update table
        table.Data(r, :) = buffer;
        % update proper map
        handles = set_map_type(handles, pdo, map_data);
        % store modified data in figure (always)
        guidata(fig, handles);
    end

    function enter_callback(c)
    %
    % First level callback used to enter a single new pdo map.
    %
    % param [in] c   User selected column index.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %  
        ttParamColumNames = {'Name', 'Index', 'SubIndex', ...
                             'Data Type', 'Default Value', 'Object Type', ...
                             'Access Type', 'Pdo Mapping'};
        ttParamFigureHeight = 625;
        ttParamFigureWidth = 900;
        % ============================================================== %
        % get screen size
        ssz = get(0, 'ScreenSize'); sw = mean(ssz([1, 3])); sh = mean(ssz([2, 4]));
        % crate new figure for object selection
        ifig = uifigure('Name','PDO mapped object', ...
                        'NumberTitle','off', ...
                        'Position', [sw - ttParamFigureWidth/2, ...
                                     sh - ttParamFigureHeight/2, ...
                                     ttParamFigureWidth, ...
                                     ttParamFigureHeight]);
        itable = uitable(ifig);
        itable.Units = 'normalized';
        itable.Position = [0, 0, 1, 1];
        % add new variable (read/write mode)
        if isempty(src.Data{r, c}{1, 1})
            itable.Data = CoPreProcessTableData(CoExcludeRange(CoFilterValidDataType(handles.objects), 0x1300, 0x1C00));
            itable.KeyPressFcn = @(src, event)add_entry(src, event, fig);
        % show current variable (read only mode)
        else
            % get selected column index name
            p = src.Data.Properties.VariableNames{c};
            % get user selected map
            selected_map = map_data{r}.(p);
            % search map object dictionary
            [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), selected_map.subindex);
            if sum(val, 'all') > 0
                map = handles.objects{pos};
                if (~isnan(stoi(map.value)))
                    % decode map value
                    [index, subindex, ~] = CoObjectDecodeMapping(map.value);
                    % get pointed object from object dictionary
                    [val, pos] = CoFindOdItem(handles.objects, index, subindex);
                    if sum(val, 'all') > 0
                        itable.Data = CoPreProcessTableData(handles.objects(pos));
                        itable.ColumnName = ttParamColumNames;
                    end
                end
            end
        end

        function add_entry(src, event, fig)
        %
        % Second level callback for adding new PDO entry in mapping table.
        %
        %
        % param [in] src         Current source figure object.
        % param [in] event       Last user event.
        % param [in] fig         Common parent figure with shared data.
        %
            % ============= CONFIG SECTION ================================= %
            %   If some names in the block mask change modify here as well   %
        
            % ------------------ mask/utils parameters --------------------- %  
            ttParamDataIndex = 3;
            ttParamDefaultRecordType = '0x9';
            ttParamDefaultObjectType = '0x7';
            ttParamDefaultAccessType = 'rw'; %#ok<NASGU> 
            ttParamDefaultPdoMapping = '0x1'; %#ok<NASGU> 
            
            % ------------------- gui shared data handles ------------------ %
            handles = guidata(fig);
            % ============================================================== %
    
            % get selected row and column (object dictionary entry)
            ir = event.Source.Selection(1);
            ic = event.Source.Selection(2); %#ok<NASGU> 
            
            % get object and pdo data
            iobj = src.Data(ir, :);
            nbytes = CoGetDataSize(iobj.datatype{1, 1});
            itsz = size(pdo);
            ipos = ttParamDataIndex;
    
            % process event
            switch event.Key
    
                % object selected
                case {'return', 'space'}
                    % get first empty slot
                    for i = ttParamDataIndex : itsz(2) 
                        % update table position (can moved in if statement)
                        ipos = i;
                        % early stop
                        if isempty(pdo{1, i}{1, 1})
                            break;
                        end
                    end
                    % check if there is place in pdo for new object
                    if (ipos + nbytes - 1 > itsz(2))
                        error('No space in pdo for the selected object!');
                    end
                    % increase object counter
                    map_data{r}.nmo = map_data{r}.nmo + 1;
                    % get index of pdo last valid subindex in objects
                    pos = numel(handles.objects); isub = 1;
                    % try to get subentry zero (number of mapped objects)
                    [val, idx] = CoFindOdVar(handles.objects, uint32(stoi(pdo.index)), 0);
                    if sum(val, 'all') == 0
                        % look for record
                        [val, idx] = CoFindOdRecord(handles.objects, stoi(pdo.index));
                        if sum(val, 'all') == 0
                            % if no record, create it in last position
                            handles.objects = {handles.objects{1:pos}, ...
                               struct('name', [pdo.name, ' Record'], ...
                                      'index', pdo.index, ...
                                      'subindex', '', ...
                                      'datatype', '', ...
                                      'value', '', ...
                                      'objecttype', ttParamDefaultRecordType, ...
                                      'accesstype', '', ...
                                      'pdomapping', '')};
                            pos = pos + 1;
                        else
                            pos = idx;
                        end
                        % create new subentry zero after record
                        handles.objects = {handles.objects{1:pos}, ...
                               struct('name', 'Number of entries', ...
                                      'index', pdo.index, ...
                                      'subindex', '0x0', ...
                                      'datatype', 'SS_UINT8', ...
                                      'value', '', ...
                                      'objecttype', ttParamDefaultObjectType, ...
                                      'accesstype', 'ro', ...
                                      'pdomapping', '0x0'), ...
                               handles.objects{pos:end}};
                        % update new entry position
                        pos = pos + 1;
                    else
                        % if subentry zero found, save index for update
                        pos = idx;
                    end
                    %update subindex zero index
                    n_entries_idx = pos;
                    % fill eventual map holes (more efficent on target)
                    while 1
                        % look for map in objects
                        [val, idx] = CoFindOdVar(handles.objects, uint32(stoi(pdo.index)), isub);
                        if sum(val, 'all') == 0
                            % empty map spot, add here
                            break;
                        else
                            % reset found flag
                            val = 0;
                            % get index and subindex of pointed object
                            [oi, os, ol] = CoObjectDecodeMapping(handles.objects{idx}.value);
                            % check for index and size validity
                            if oi > 0 && ol > 0
                                % look for pointed object
                                [val, ~] = CoFindOdItem(handles.objects, oi, os);
                            end
                            % if no object pointed delete dummy map
                            if sum(val, 'all') == 0
                                handles.objects = {handles.objects{1:idx-1}, handles.objects{idx+1:end}};
                                break;
                            end
                            % update position and go on searching
                            pos = idx;
                        end
                        % nex subindex
                        isub = isub + 1;
                    end
                    % increase mapped object counter
                    handles.objects{n_entries_idx}.value = ['0x', num2str(dec2hex(map_data{r}.nmo))];
                    % add new pdo map in proper position
                    handles.objects = {handles.objects{1:pos}, ...
                                       struct('name', ['mapped object.', num2str(isub)], ...
                                              'index', pdo.index, ...
                                              'subindex', ['0x', num2str(dec2hex(isub))], ...
                                              'datatype', 'SS_UINT32', ...
                                              'value', '', ...
                                              'objecttype', ttParamDefaultObjectType, ...
                                              'accesstype', 'const', ...
                                              'pdomapping', '0x0'), ...
                                       handles.objects{pos+1:end}};
                    % object map encoding
                    code = CoObjectCodeMapping(iobj);
                    handles.objects{pos+1}.value = ['0x', num2str(dec2hex(code))];
                    % update pdo and reverse map_data
                    for i = 0 : nbytes-1
                        % get byte position in table
                        ictv = pdo.Properties.VariableNames{ipos+i};
                        % update map_data
                        map_data{r}.(ictv) = struct( ...
                            'name', iobj.name, ...
                            'index', pdo.index, ...
                            'subindex', isub, ...
                            'length', nbytes);
                        % update graphic
                        pdo.(ictv) = iobj.name;
                    end
                    % update table and hide figure (don't close it)
                    table.Data(r, :) = pdo;
                    ifig.Visible = 'off';
                    % update common data
                    handles = set_map_type(handles, pdo, map_data);
                    % store modified data in figure
                    guidata(fig, handles);
            end
        end
    end

    function map = get_map_type(handles, pdo)
    %
    % Get proper map field from figure handles.
    %
    % param [in] handles  Figure handles.
    % param [in] pdo      Current pdo.
    %
    % return     map     Specific map_data field.
    %        
        if stoi(pdo.index) >= 0x1600 && stoi(pdo.index) < 0x1800
            map = handles.rpdo_map_data;
        elseif stoi(pdo.index) >= 0x1A00 && stoi(pdo.index) < 0x1C00
            map = handles.tpdo_map_data;
        elseif stoi(pdo.index) >= 0x1381 && stoi(pdo.index) < 0x1400
            map = handles.srdo_map_data;
        else
            map = {};
        end
    end

    function handles = set_map_type(handles, pdo, map_data)
    %
    % Set proper map field to figure handles.
    %
    % param [in] handles   Figure handles.
    % param [in] pdo       Current pdo.
    % param [in] map_data  Map used to update handles.
    %
    % return     handles   Updated figure handles.
    %  
        if stoi(pdo.index) >= 0x1600 && stoi(pdo.index) < 0x1800
            handles.rpdo_map_data = map_data;
        elseif stoi(pdo.index) >= 0x1A00 && stoi(pdo.index) < 0x1C00
            handles.tpdo_map_data = map_data;
        elseif stoi(pdo.index) >= 0x1381 && stoi(pdo.index) < 0x1400
            handles.srdo_map_data = map_data;
        end
    end

end

function CoGuiPdoCommunicationCallback(src, event, table, fig)
%
% Entry point for the PDO Gui communication section callbacks.
%
% param [in] src         Current source figure object.
% param [in] event       Last user event.
% param [in] table       Private table to be updated (for sisualization).
% param [in] fig         Common parent figure with shared data.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %  
    ttParamDataIndex = 3;
    ttParamPressEventName = 'KeyRelease';
    ttParamValueChangedEventName = 'CellEdit';
        
    % ------------------- gui shared data handles ------------------ %
    handles = guidata(fig);
    % ============================================================== %

    % check if cell valid
    if ~isempty(event.Source.Selection)
        % disable warning for empty table
        warning('off', 'all');
        % get user selected row and column
        r = event.Source.Selection(1); c = event.Source.Selection(2);
        % get row (PDO mapping record)
        pdo = src.Data(r, :);
        % get command from event
        cmd = 'brascamenta';
        switch event.EventName
            case ttParamPressEventName
                % key pressed
                cmd = event.Key;
            case ttParamValueChangedEventName
                % value changed (update always)
                cmd = 'return';
        end
        % process command
        switch cmd
            case {'backspace', 'delete'}
                % delete single pdo map
                if c >= ttParamDataIndex
                    delete_slot_callback(c);
                %delete whole pdo releted data
                else
                    delete_pdo_callback();
                end   
            case {'return', 'space'}
                % add new entry only for empty cells
                if c >= ttParamDataIndex
                    enter_callback(c);
                end
        end
        % reenable warning for empty table
        warning('on', 'all');
    end

    function delete_pdo_callback()
    %
    % First level callback used to delete a whole pdo.
    %
        % get all object matching pdo index
        idx = arrayfun(@(x) ...
            strcmp(handles.objects{x}.index, pdo.index), ...
            1:numel(handles.objects));
        % remove objects from object dictionary
        handles.objects = handles.objects(~idx);
        % refresh view
        src.Data(r, :) = [];
        guidata(fig, handles);
    end

    function delete_slot_callback(c)
    %
    % First level callback used to delete a single pdo comm entry.
    %
    % param [in] c   User selected column index.
    %
        % get propriety from column
        p = src.Data.Properties.VariableNames{c};
        % reset sub entry value in object dictionary
        [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), get_comm_subindex(p));
        if sum(val, 'all') > 0
            handles.objects{pos}.value = '';
        end
        % update table
        table.Data.(p){r} = '';
        % store modified data in figure (always)
        guidata(fig, handles);
    end

    function enter_callback(c)
    %
    % First level callback used to enter a single new pdo entry.
    %
    % param [in] c   User selected column index.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %
        ttParamPdoCommSubindeces = struct('entries', @entries_callback, ...
                                          'cobid', @cobid_callback, ...
                                          'type', @transmission_type_callback, ...
                                          'inhibit', @inhibit_time_callback, ...
                                          'channel', @channel_callback, ...
                                          'eventtimer', @event_timer_callback);
        % ============================================================== %

        % get propriety from column and subindex
        p = src.Data.Properties.VariableNames{c};
        subindex = get_comm_subindex(p);

        % update flag
        update = false;
        
        % get value of user selected cell
        svalue = pdo.(p){1, 1};

        % check if value exists
        if ~isempty(svalue)
            % get respective numeric value
            nvalue = stoi(svalue);
            % get object from object dictionary (needs to be already there)
            [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), subindex);
            if sum(val, 'all') > 0
                % execute specific validity check callback
                if isfield(ttParamPdoCommSubindeces, p)
                    ttParamPdoCommSubindeces.(p)();
                end
                if update
                    % update object dictionary entry
                    handles.objects{pos}.value = svalue;
                    % update table
                    table.Data.(p){r} = svalue;
                    % store modified data in figure
                    guidata(fig, handles);
                else
                    % reset old value
                    table.Data.(p){r} = handles.objects{pos}.value;
                end
            else
                % empty table slot (not found in object dictionary)
                table.Data.(p){r} = '';
            end
        end

        function entries_callback()
        %
        % Number of entries verification callback.
        %
            if ~isnan(nvalue) && nvalue > 0 && nvalue <= 5
                update = true;
            end
        end

        function cobid_callback()
        %
        % COB-ID verification callback.
        %
            if ~isnan(nvalue) && nvalue > 0
                update = true;
            end
        end

        function transmission_type_callback()
        %
        % Transmission type verification callback.
        %
            if ~isnan(nvalue) && (nvalue <= 240 || nvalue == 254 || nvalue == 255)
                update = true;
            end
        end

        function inhibit_time_callback()
        %
        % Inhibit callback verification callback.
        %
            if ~isnan(nvalue)
                update = true;
            end
        end

        function channel_callback()
        %
        % Channel verification callback.
        %
            if ~isnan(nvalue) && nvalue >= 0 && nvalue < 4
                update = true;
            end
        end

        function event_timer_callback()
        %
        % Event timer verification callback.
        %
            if ~isnan(nvalue)
                update = true;
            end
        end
        
    end

    function val = get_comm_subindex(p)
    %
    % Get pdo communication parameter subindex from name.
    %
    % param [in] p  Name of the propriety to search.
    %
    % return val    Subindex of the propriety searched.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %
        ttParamPdoCommSubindeces = struct('entries', 0, ...
                                          'cobid', 1, ...
                                          'type', 2, ...
                                          'inhibit', 3, ...
                                          'channel', 4, ...
                                          'eventtimer', 5);
        % ============================================================== %
        val = NaN;
        if isfield(ttParamPdoCommSubindeces, p)
            val = ttParamPdoCommSubindeces.(p);
        end
    end

end

function CoGuiSrdoCommunicationCallback(src, event, table, fig)
%
% Entry point for the SRDO Gui communication section callbacks.
%
% param [in] src         Current source figure object.
% param [in] event       Last user event.
% param [in] table       Private table to be updated (for sisualization).
% param [in] fig         Common parent figure with shared data.
%
    % ============= CONFIG SECTION ================================= %
    %   If some names in the block mask change modify here as well   %

    % ------------------ mask/utils parameters --------------------- %  
    ttParamDataIndex = 3;
    ttParamPressEventName = 'KeyRelease';
    ttParamValueChangedEventName = 'CellEdit';
        
    % ------------------- gui shared data handles ------------------ %
    handles = guidata(fig);
    % ============================================================== %

    % check if cell valid
    if ~isempty(event.Source.Selection)
        % disable warning for empty table
        warning('off', 'all');
        % get user selected row and column
        r = event.Source.Selection(1); c = event.Source.Selection(2);
        % get row (PDO mapping record)
        pdo = src.Data(r, :);
        % get command from event
        cmd = 'brascamenta';
        switch event.EventName
            case ttParamPressEventName
                % key pressed
                cmd = event.Key;
            case ttParamValueChangedEventName
                % value changed (update always)
                cmd = 'return';
        end
        % process command
        switch cmd
            % delete object
            case {'backspace', 'delete'}
                % delete single pdo map
                if c >= ttParamDataIndex
                    delete_slot_callback(c);
                %delete whole pdo releted data
                else
                    delete_pdo_callback();
                end
            % add new entry
            case {'return', 'space'}
                % allow input only for empty cells
                if c >= ttParamDataIndex
                    enter_callback(c);
                end
        end
        % reenable warning for empty table
        warning('on', 'all');
    end

    function delete_pdo_callback()
    %
    % First level callback used to delete a whole pdo.
    %
        % get all object matching pdo index
        idx = arrayfun(@(x) ...
            strcmp(handles.objects{x}.index, pdo.index), ...
            1:numel(handles.objects));
        % remove objects from object dictionary
        handles.objects = handles.objects(~idx);
        % refresh view
        src.Data(r, :) = [];
        guidata(fig, handles);
    end

    function delete_slot_callback(c)
    %
    % First level callback used to delete a single pdo comm entry.
    %
    % param [in] c   User selected column index.
    %
        % get propriety from column
        p = src.Data.Properties.VariableNames{c};
        % reset sub entry value in object dictionary
        [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), get_comm_subindex(p));
        if sum(val, 'all') > 0
            handles.objects{pos}.value = '';
        end
        % update table
        table.Data.(p){r} = '';
        % store modified data in figure (always)
        guidata(fig, handles);
    end

    function enter_callback(c)
    %
    % First level callback used to enter a single new pdo entry.
    %
    % param [in] c   User selected column index.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %
        ttParamPdoCommSubindeces = struct( ...
            'entries', @entries_callback, ...
            'direction', @direction_callback, ...
            'refresh_time', @refresh_time_callback, ...
            'srvt', @srvt_callback, ...
            'transmissiontype', @transmission_type_callback, ...
            'cobid_normal', @cobid_normal_callback, ...
            'cobid_inverted', @cobid_inverted_callback, ...
            'channel', @channel_callback);
        % ============================================================== %

        % get propriety from column and subindex
        p = src.Data.Properties.VariableNames{c};
        subindex = get_comm_subindex(p);

        % update flag
        update = false;
        
        % get value of user selected cell
        svalue = pdo.(p){1, 1};

        % check if value exists
        if ~isempty(svalue)
            % get respective numeric value
            nvalue = stoi(svalue);
            % get object from object dictionary (needs to be already there)
            [val, pos] = CoFindOdItem(handles.objects, uint32(stoi(pdo.index)), subindex);
            if sum(val, 'all') > 0
                % execute specific validity check callback
                if isfield(ttParamPdoCommSubindeces, p)
                    ttParamPdoCommSubindeces.(p)();
                end
                if update
                    % update object dictionary entry
                    handles.objects{pos}.value = svalue;
                    % update table
                    table.Data.(p){r} = svalue;
                    % store modified data in figure
                    guidata(fig, handles);
                else
                    % reset old value
                    table.Data.(p){r} = handles.objects{pos}.value;
                end
            else
                % empty table slot (not found in object dictionary)
                table.Data.(p){r} = '';
            end
        end

        function entries_callback()
        %
        % Number of entries verification callback.
        %
            if ~isnan(nvalue) && nvalue > 0 && nvalue <= 7
                update = true;
            end
        end

        function direction_callback()
        %
        % Direction verification callback.
        %
            if ~isnan(nvalue) && nvalue < 3
                update = true;
            end
        end

        function refresh_time_callback()
        %
        % Refresh time verification callback.
        %
            if ~isnan(nvalue)
                update = true;
            end
        end

        function srvt_callback()
        %
        % Srvt verification callback.
        %
            if ~isnan(nvalue)
                update = true;
            end
        end

        function transmission_type_callback()
        %
        % Transmission type verification callback.
        %
            if ~isnan(nvalue) && (nvalue <= 240 || nvalue == 254 || nvalue == 255)
                update = true;
            end
        end

        function cobid_normal_callback()
        %
        % COB-ID normal verification callback.
        %
            if ~isnan(nvalue) && (bitand(nvalue, 1) == 0)
                update = true;
                tmp = stoi(pdo.cobid_inverted{1, 1});
                if isnan(tmp) || (tmp ~= nvalue + 1)
                    delete_slot_callback(c+1);
                end
            end
        end

        function cobid_inverted_callback()
        %
        % COB-ID inverted verification callback.
        %
            if ~isnan(nvalue) && (bitand(nvalue, 1) == 1)
                update = true;
                tmp = stoi(pdo.cobid_normal{1, 1});
                if isnan(tmp) || (tmp ~= nvalue - 1)
                    delete_slot_callback(c-1);
                end
            end
        end

        function channel_callback()
        %
        % Channel verification callback.
        %
            if ~isnan(nvalue) && nvalue >= 0 && nvalue < 4
                update = true;
            end
        end

    end

    function val = get_comm_subindex(p)
    %
    % Get pdo communication parameter subindex from name.
    %
    % param [in] p  Name of the propriety to search.
    %
    % return val    Subindex of the propriety searched.
    %
        % ============= CONFIG SECTION ================================= %
        %   If some names in the block mask change modify here as well   %
    
        % ------------------ mask/utils parameters --------------------- %
        ttParamPdoCommSubindeces = struct('entries', 0, ...
                                          'direction', 1, ...
                                          'refresh_time', 2, ...
                                          'srvt', 3, ...
                                          'transmissiontype', 4, ...
                                          'cobid_normal', 5, ...
                                          'cobid_inverted', 6, ...
                                          'channel', 7);

        % ============================================================== %
        val = NaN;
        if isfield(ttParamPdoCommSubindeces, p)
            val = ttParamPdoCommSubindeces.(p);
        end
    end

end