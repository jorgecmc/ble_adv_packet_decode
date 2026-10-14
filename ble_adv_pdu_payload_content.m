

function adv_pkt = ble_adv_pdu_payload_content(pdu_l,parsed_payload,adv_pkt)
% Vol 6, Part B, Section 2.3, link layer payload content
% Part A (Data Types Specification)
type_hex = parsed_payload(1,:);
switch type_hex
    case '01'
        fprintf(' * Flags: %s\n',parsed_payload(2,:));
        mode_cap = dec2bin(hex2dec(parsed_payload(2:end,:)));
        fprintf('    Simultaneous LE and BR/EDR to Same Device Capable (Host): %s\n',mode_cap(5));
        fprintf('    Simultaneous LE and BR/EDR to Same Device Capable (Controller): %s\n',mode_cap(4));
        fprintf('    BR/EDR Supported: %s\n',mode_cap(3));
        fprintf('    LE General Discoverable Mode: %s\n',mode_cap(2));
        fprintf('    LE Limited Discoverable Mode: %s\n',mode_cap(1));
    case '02'
        fprintf(' * (tbd)Incomplete List of 16-bit Service Class UUIDs\n');
    case '03'
        fprintf(' * (tbd)Complete List of 16-bit Service Class UUIDs\n');
    case '06'
        fprintf(' * (tbd)128-bit Service Class UUIDs\n');
    case '07'
        fprintf(' * (tbd)128-bit Service Class UUIDs\n');
    case '08'
        fprintf(' * (tbd)Shortened Local Name\n');
    case '09'
        fprintf(' * (tbd)Complete Local Name\n');
    case '0A'
        TX_Power_lv = hex2dec(parsed_payload(2,:));
        fprintf(' * Tx Power Level:\n    %d dBm\n',TX_Power_lv);
    case '12'
        fprintf(' * (tbd)Slave Connection Interval Range\n');
    case '16'
        fprintf(' * (tbd)Service Data - 16-bit UUID\n');
    case 'FF'
        fprintf(' * Manufacturer Specific Data\n');
        manu = [parsed_payload(3,:) parsed_payload(2,:)];
        switch manu
            case '004C'
                manu_name = 'Apple, Inc.';
                adv_pkt.manu_name = manu_name;
                fprintf('    Manufacturer: %s\n',manu_name);
                resolved_type = apple_type(parsed_payload(4,:));
                fprintf('        Type: %s\n',resolved_type);
                L = hex2dec(parsed_payload(5,:));
                fprintf('        Length: %d\n',L);
                tmp_end_idx = 6 + L - 1;
                fprintf('        Value: %s\n',reshape(parsed_payload(6:tmp_end_idx,:)',1,[]));
                while tmp_end_idx < pdu_l
                    resolved_type = apple_type(parsed_payload(tmp_end_idx + 1,:));
                    fprintf('        Type: %s\n',resolved_type);
                    L = hex2dec(parsed_payload(tmp_end_idx + 2,:)) - 1;
                    fprintf('        Length: %d\n',L);
                    fprintf('        Value: %s\n',reshape(parsed_payload(tmp_end_idx+3:tmp_end_idx+3+L,:)',1,[]));
                    tmp_end_idx = tmp_end_idx + 3 + L;
                end
            case '0006'
                manu_name = 'Microsoft';
                adv_pkt.manu_name = manu_name;
                fprintf('    Manufacturer: %s\n',manu_name);
                fprintf('        (tbd) %s\n',reshape(parsed_payload(4:end,:)',1,[]));
            otherwise
                fprintf('unrecognised/tbd Manufacturer: %s\n',manu);
        end
    otherwise
        fprintf('unrecognised/tbd PDU content type: %s\n',type_hex);
end

end

