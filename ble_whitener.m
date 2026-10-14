function whiten_data = ble_whitener(data_in,channel_idx)


channel_idx_bin = dec2bin(channel_idx,6);
lfsr_whitener = zeros(1,7);
lfsr_whitener(1) = 1;
lfsr_whitener(2:end) = channel_idx_bin-'0';

l_data = length(data_in);
whiten_data = zeros(1,l_data);

for ii = 1:l_data
    % cal. data_out
    whiten_data(ii) = xor(data_in(ii),lfsr_whitener(end));

    % update lfsr status
    feedbackBit = lfsr_whitener(end);
    lfsr_whitener = [feedbackBit lfsr_whitener(1:end-1)];
    lfsr_whitener(5) = xor(feedbackBit,lfsr_whitener(5));
end