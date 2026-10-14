function [crc_check] = ble_crc_check(rx_adv_pdu,adv_crc_init)


% adv_crc_init = '555555'; % for adv.

% LFSR
crcValue = uint32(hex2dec(adv_crc_init));
lfsrState = de2bi(crcValue, 24, 'right-msb');

for ii = 1:length(rx_adv_pdu)
    % inputBit = advertisingPDU_r(end-ii+1);
    inputBit = rx_adv_pdu(ii);

    feedbackBit = xor(lfsrState(end), inputBit);
    nextState = [feedbackBit lfsrState(1:end-1)];
    % lfsr state
    nextState(11) = xor(feedbackBit,nextState(11));
    nextState(10) = xor(feedbackBit,nextState(10));
    nextState(7) = xor(feedbackBit,nextState(7));
    nextState(5) = xor(feedbackBit,nextState(5));
    nextState(4) = xor(feedbackBit,nextState(4));
    nextState(2) = xor(feedbackBit,nextState(2));

    lfsrState = nextState;
end

crc_gen = flip(lfsrState);
crc_check = sum(crc_gen);