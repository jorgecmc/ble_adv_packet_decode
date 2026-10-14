function adv_pkt = ble_adv_pdu_payload_parser(pdu_header,pdu_payload_bits,adv_pkt)
% Vol 3, Part C (Generic Access Profile), Section 11, PDU data format
payload_bits_rsp = reshape(pdu_payload_bits,8,[])';
payload_dec = payload_bits_rsp*(2.^(0:7)');
payload_byte = dec2hex(payload_dec);

switch pdu_header.pdu_type
    case {'ADV_IND', 'ADV_NONCONN_IND'}
        % AdvA
        if pdu_header.TxAdd
            fprintf('Random Device Address: %s-%s-%s-%s-%s-%s\n',...
                payload_byte(6,:),...
                payload_byte(5,:),...
                payload_byte(4,:),...
                payload_byte(3,:),...
                payload_byte(2,:),...
                payload_byte(1,:));
        else
            fprintf('Public Device Address: %s-%s-%s-%s-%s-%s\n',...
                payload_byte(6,:),...
                payload_byte(5,:),...
                payload_byte(4,:),...
                payload_byte(3,:),...
                payload_byte(2,:),...
                payload_byte(1,:));
        end
        mac_msb = dec2bin(hex2dec(payload_byte(6,:)),8);
        mac_msb_2 = mac_msb(1:2);
        fprintf('Random address type: ');
        switch mac_msb_2
            % Bluetooth Core Specification, Vol 6, Part B, Section 1.3
            case '11'
                fprintf('Static Random\n');
            case '01'
                fprintf('Resovable Private Address (RPA)\n');
            case '00'
                fprintf('Non-Resolvable Private Address\n');
            case '10'
                fprintf('Unused\n');
        end
        % LTV parser
        fprintf('PDU payload content (LTV parser):\n');
        existing_Nbytes = pdu_header.payload_length - 6;
        while existing_Nbytes > 0
            parser_idx = pdu_header.payload_length - existing_Nbytes + 1;
            pdu_l = hex2dec(payload_byte(parser_idx,:));
            parsed_payload = payload_byte(parser_idx+1:parser_idx+pdu_l,:);
            adv_pkt = ble_adv_pdu_payload_content(pdu_l,parsed_payload,adv_pkt);
            existing_Nbytes = existing_Nbytes - pdu_l - 1; % -1: L
        end
    otherwise
        fprintf('unrecognised/tbd PDU type: %s\n',pdu_header.pdu_type);
end

end
