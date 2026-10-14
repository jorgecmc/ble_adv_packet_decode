function [ps,pe] = dsw(rx_signal,short_win_len,long_win_len)

%% Double Sliding Window (STA/LTA) 
% cal. signal energy
energy = abs(rx_signal).^2;

% cal. Short-Term Average (STA)
% using filter for Moving Average
h_sta = ones(short_win_len, 1) / short_win_len;
sta = filter(h_sta, 1, energy);

% cal. Long-Term Average (LTA)
delayed_energy = [zeros(short_win_len, 1); energy(1:end-short_win_len)];
h_lta = ones(long_win_len, 1) / long_win_len;
lta = filter(h_lta, 1, delayed_energy);

% cal. Metric (STA / LTA Ratio)
epsilon = 1e-10; % avoid dividing zero
metric = sta ./ (lta + epsilon);
metric2 = lta ./ (sta + epsilon);

% (4) find trigger point which is above Threshold 
% trigger_idx = find(metric(short_win_len+long_win_len+1:end) > threshold, 1, 'first');
[~,trigger_idx] = max(metric(short_win_len+long_win_len+1:end));
pkt_start = trigger_idx + short_win_len + long_win_len - short_win_len;
[~,trigger_idx2] = max(metric2(short_win_len+long_win_len+1:end));
pkt_end = trigger_idx2 + short_win_len + long_win_len - short_win_len;

threshold = 500;
sps = 8;
max_payload_length = 500*sps;
ps = [];
pe = [];

pkt_end_t = 0;
while ~isempty(find(metric(short_win_len+long_win_len+pkt_end_t+1:end) > threshold, 1, 'first'))
    trigger_idx_t = find(metric(short_win_len+long_win_len+pkt_end_t+1:end) > threshold, 1, 'first');
    [~,trigger_idx_tmp] = max(metric(short_win_len+long_win_len+pkt_end_t+1:trigger_idx_t+pkt_end_t+max_payload_length));
    pkt_start_t = trigger_idx_tmp + pkt_end_t + short_win_len + long_win_len - short_win_len;
    [~,trigger_idx2_t] = max(metric2(short_win_len+long_win_len+pkt_end_t+1:trigger_idx_t+pkt_end_t+max_payload_length));
    pkt_end_t = trigger_idx2_t + pkt_end_t + short_win_len + long_win_len - short_win_len;

    ps = [ps pkt_start_t];
    pe = [pe pkt_end_t];
end
