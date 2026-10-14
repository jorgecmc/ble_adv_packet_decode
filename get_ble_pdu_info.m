function resultTable = get_ble_pdu_info(pduInput)
% GET_BLE_PDU_INFO Query the corresponding meaning of Bluetooth LE PDU Type.
% 
% Syntax:
%   resultTable = get_ble_pdu_info(pduInput)
%
% Inputs:
%   pduInput - Can be a decimal number (0-15) or a string 
%              (e.g., '0b0111', '7', or '0x07').
%
% Examples:
%   result = get_ble_pdu_info('0b0111');
%   result = get_ble_pdu_info(3);

% 1. Process input format and convert it to a decimal value
if nargin < 1
    error('Please input a PDU Type to query (e.g., 3 or ''0b0011'').');
end

if ischar(pduInput) || isstring(pduInput)
    s = char(pduInput);
    if startsWith(s, '0b', 'IgnoreCase', true)
        pduVal = bin2dec(s(3:end));
    elseif startsWith(s, '0x', 'IgnoreCase', true)
        pduVal = hex2dec(s(3:end));
    else
        pduVal = str2double(s);
    end
else
    pduVal = pduInput;
end

% 2. Build the complete PDU mapping database
% Columns: [PduValue, PduName, PhysicalChannel]
masterData = {
    0,  'ADV_IND',              'Primary Advertising';
    1,  'ADV_DIRECT_IND',       'Primary Advertising';
    2,  'ADV_NONCONN_IND',      'Primary Advertising';
    3,  'SCAN_REQ',             'Primary Advertising';
    3,  'AUX_SCAN_REQ',         'Secondary Advertising';
    4,  'SCAN_RSP',             'Primary Advertising';
    5,  'CONNECT_IND',          'Primary Advertising';
    5,  'AUX_CONNECT_REQ',      'Secondary Advertising';
    6,  'ADV_SCAN_IND',         'Primary Advertising';
    7,  'ADV_EXT_IND',          'Primary Advertising';
    7,  'AUX_ADV_IND',          'Secondary Advertising';
    7,  'AUX_SCAN_RSP',         'Secondary Advertising';
    7,  'AUX_SYNC_IND',         'Periodic';
    7,  'AUX_CHAIN_IND',        'Secondary Advertising and Periodic';
    7,  'AUX_SYNC_SUBEVENT_IND','Periodic';
    7,  'AUX_SYNC_SUBEVENT_RSP','Periodic';
    8,  'AUX_CONNECT_RSP',      'Secondary Advertising';
    9,  'ADV_DECISION_IND',     'Primary Advertising';
    };

% Convert to a MATLAB Table for filtering and display
fullTable = cell2table(masterData, ...
    'VariableNames', {'PDU_Type_Val', 'PDU_Name', 'Physical_Channel'});

% 3. Filter based on the input value
if pduVal >= 0 && pduVal <= 9
    idx = (fullTable.PDU_Type_Val == pduVal);
    resultTable = fullTable(idx, :);
elseif pduVal >= 10 && pduVal <= 15
    % Reserved values
    reservedTable = table(pduVal, {'Reserved for future use'}, {'-'}, ...
        'VariableNames', {'PDU_Type_Val', 'PDU_Name', 'Physical_Channel'});
    resultTable = reservedTable;
else
    error('Invalid PDU Type value. Please input a value between 0 and 15.');
end

end