clc, clearvars, close all,

% load raw data
[file,location] = uigetfile('*.sigmf');
[~, name, ~] = fileparts(file);
if ~isfolder(name)
    untar([location file]);
end
[Y,XDelta] = f_read_sigmf(name);

% raw data pre-processing DDC
offset = 1e6;
fs = 1/XDelta;
timeVector = (0:numel(Y)-1).' / fs;
rx_signal_ddc = Y .* exp(-1j * 2 * pi * offset * timeVector);

figure,
subplot(211),plot(timeVector,real(rx_signal_ddc)),
grid minor, title('RX waveform (in-phase)'), xlabel('Time (sec.)'), ylabel('Amp.'),
subplot(212),plot(timeVector,imag(rx_signal_ddc)),
grid minor, title('RX waveform (in-phase)'), xlabel('Time (sec.)'), ylabel('Amp.'),

%% Parameters setting
% BLE adv. packet
adv_crc_init = '555555';
channel_idx = 37;
Rs = 1e6;
sps = fs/Rs;
preamble_bits = [0 1 0 1, 0 1 0 1];  % preamble, 1 bytes
adv_aa_bits = [0 1 1 0 1 0 1 1, 0 1 1 1 1 1 0 1, 1 0 0 1 0 0 0 1, 0 1 1 1 0 0 0 1]; % Adv. access address, 0x8E98BED6
Nbyte_pdu_header = 2;
Nbyte_pdu_crc = 3;

% LPF para
Fs = fs;          % Sampling frequency (Hz)
Fc = 1e6;           % Cutoff frequency (Hz)
N  = 50;            % Filter order (higher = sharper transition)

% Design FIR low-pass using Hamming window
b = fir1(N, Fc/(Fs/2), 'low', hamming(N+1));
a = 1;

freqVector = (-numel(rx_signal_ddc)/2:numel(rx_signal_ddc)/2-1) * fs / numel(rx_signal_ddc) / 1e6;
figure,
semilogy(freqVector, abs(fftshift(fft(rx_signal_ddc))), 'DisplayName','$r_{DDC}(t)$')
rx_signal = filter(b,1,rx_signal_ddc);
hold on,
semilogy(freqVector, abs(fftshift(fft(rx_signal))),'r', 'DisplayName','$y(t)$')
grid minor, title('RX waveform (in-phase)'), xlabel('Freq (MHz)'), ylabel('Amp.'),
legend('Interpreter', 'latex');

%% Receiver processing

% dsw
short_win_len = 128;
long_win_len = short_win_len;
[pkt_start,pkt_end] = dsw(rx_signal,short_win_len,long_win_len);
N_detected_pkt = length(pkt_start);
decode_info = cell(N_detected_pkt,4); % PDU type, payload length, CRC, Manu 

figure,
plot(timeVector,abs(rx_signal)),
xline(pkt_start*XDelta,'r')
xline(pkt_end*XDelta,'r')
grid minor, title('RX waveform'), xlabel('Time (sec.)'), ylabel('Mag'),

for i_pkt = 1:N_detected_pkt
    % demod
    %% phase diff.
    backoff = 10;
    rx_signal_bo = rx_signal(pkt_start(i_pkt)-backoff+1:pkt_end(i_pkt));
    demod_sig = angle(rx_signal_bo(2:end).*conj(rx_signal_bo(1:end-1)));
    figure,
    subplot(311),plot(real(rx_signal_bo))
    grid minor, title(['Detected Packet #' num2str(i_pkt) '(in-phase)']), xlabel('n'), ylabel('Amp.'),
    subplot(312),plot(demod_sig)
    grid minor, title('Phase Differentiation'), xlabel('n'), ylabel('Phase Diff.'),

    demod_sig2 = zeros(length(demod_sig),1);
    demod_sig2(abs(demod_sig)<0.3) = demod_sig(abs(demod_sig)<0.3);
    subplot(313),plot(demod_sig2)

    %% sync
    sync_word = [preamble_bits adv_aa_bits]; % 40 bits in total

    % matched filter template
    sync_template = repelem(sync_word * 2 - 1, sps);

    % correlation
    [corr_val, lags] = xcorr(demod_sig2, sync_template);
    [~, max_idx] = max(abs(corr_val));
    % figure,plot(abs(corr_val)),

    % PDU Payload sampling start point
    packet_start_idx = lags(max_idx) + length(sync_template) + 1;
    sync_point = max_idx-length(demod_sig2) + 1;

    if sync_point > 0
        disp('ADV. packet detected!');

        % Down sampling
        start_idx = sync_point+round(sps/2);
        end_idx = length(demod_sig);

        payload_samples = demod_sig(start_idx : sps : end_idx);
        subplot(313),
        hold on, plot(start_idx : sps : end_idx,payload_samples,'r*')
        grid minor, title('Sampling'), xlabel('n'), ylabel('Phase Diff.'),
        legend('Phase Differentiation','Sampled data'),

        % Demodulation
        demodulated_bits = payload_samples > 0;
        demod_pdu_bits = demodulated_bits(length(preamble_bits)+length(adv_aa_bits)+1:end);

        % De-whiten
        dewhiten_bits = ble_whitener(demod_pdu_bits,channel_idx);

        % 5. Decode PDU
        if length(dewhiten_bits) >= 16
            % PDU header
            fprintf('\nPDU header info:\n===============================================================\n');
            pdu_header_bits = dewhiten_bits(1:16)';
            pdu_header.pdu_type = pdu_header_bits(1:4); % bit 0-3
            pdu_header.RFU1 = pdu_header_bits(5);
            pdu_header.ChSel = pdu_header_bits(6);
            pdu_header.TxAdd = pdu_header_bits(7);
            pdu_header.RxAdd = pdu_header_bits(8);
            pdu_header.length_bits = pdu_header_bits(9:16); % bit 8-15

            % LSB First
            pdu_type_val = sum(2.^(0:3)*pdu_header.pdu_type);
            pdu_header.payload_length = sum(2.^(0:7)*pdu_header.length_bits);
            decode_info{i_pkt,2} = pdu_header.payload_length;

            % PDU type
            res = get_ble_pdu_info(pdu_type_val);
            for i = 1:height(res)
                pdu_header.pdu_type = res.PDU_Name{i};
                decode_info{i_pkt,1} = pdu_header.pdu_type;
                channel = res.Physical_Channel{i};
                fprintf('PDU type = %s, Channel = %s\n', pdu_header.pdu_type, channel);
            end

            fprintf('ChSel: %d \n', pdu_header.ChSel);
            fprintf('TxAdd: %d \n', pdu_header.TxAdd);
            fprintf('RxAdd: %d \n', pdu_header.RxAdd);
            fprintf('Payload length: %d bytes\n', pdu_header.payload_length);

            % CRC check
            crc_check = ble_crc_check(dewhiten_bits(1:(Nbyte_pdu_header+pdu_header.payload_length+Nbyte_pdu_crc)*8), adv_crc_init);
            if ~crc_check
                fprintf('CRC check valid!\n');
                decode_info{i_pkt,3} = 'CRC check valid!';
            else
                fprintf('CRC check failed!\n');
                decode_info{i_pkt,3} = 'CRC check failed!';
                return
            end

            % Extract payload
            fprintf('\nPDU payload info:\n===============================================================\n');
            pdu_payload_bits = dewhiten_bits(17 : 16 + pdu_header.payload_length*8);

            adv_pkt.manu_name = 'unknown';
            adv_pkt = ble_adv_pdu_payload_parser(pdu_header,pdu_payload_bits,adv_pkt);
            decode_info{i_pkt,4} = adv_pkt.manu_name;

            fprintf('\nEnd of ADV. packet decoding (%d/%d)......\n===============================================================\n\n\n\n\n',i_pkt,N_detected_pkt);

        end
    else
        disp('No ADV. packet detected......');
    end


end


%% Annotation in sigmf-meta

% file path
inFile  = '.\2026-10-07-17-57-16_recording\2026-10-07-17-57-16_recording.sigmf-meta';
outFile = '.\2026-10-07-17-57-16_recording\2026-10-07-17-57-16_recording.sigmf-meta';

% information
starts  = pkt_start; 
lengths = pkt_end-pkt_start; 
num_packets = size(decode_info, 1); 

% ==========================================
% 2. conversion
% ==========================================
infos = cell(num_packets, 1);

for i = 1:num_packets
    p_type = decode_info{i, 1};
    p_len  = decode_info{i, 2};
    p_crc  = decode_info{i, 3};
    p_comp = decode_info{i, 4};

    % info. combination：
    % "ADV_NONCONN_IND | Len: 23 | CRC check valid! | Apple, Inc."
    infos{i} = sprintf('%s | Len: %d | %s | %s', p_type, p_len, p_crc, p_comp);
end

% assume all packets are 2 MHz (2e6 Hz)
% automatically extract Fc 2401000000.0 in json to cal. upper and lower
% bond
bandwidths = 2e6; 

% add the annotation
write_sigmf_annotations(inFile, outFile, starts, lengths, infos, bandwidths, offset);

