function [Y,XDelta] = f_read_sigmf(name)

cd(name);

% 1. read file and resolve as struct
rawText = fileread([name '.sigmf-meta']);
data = jsondecode(rawText);

% 2. get specific column（convert ':' to '_'）
freq = data.captures(1).core_frequency;      % 2442000000
dt   = data.captures(1).core_datetime;       % '2026-10-04T10:19:52.131Z'
fs   = data.global.core_sample_rate;         % 61439999
fmt  = data.global.core_datatype;            % 'ci16_le'

fs = round(fs/10)*10;
XDelta = 1/fs;

fprintf('Sample Rate: %.1f Hz\n', fs);
fprintf('Center Frequency: %.1f Hz\n', freq);


% 3. regex parsing
% pattern = '^(?<is_complex>[cr])(?<type>[iuf])(?<bits>8|16|32|64)_?(?<endian>le|be)?$';
% parsed = regexp(fmt, pattern, 'names');


% 4. file open
fo = fopen([name '.sigmf-data'],"r");

% 5. read file
switch fmt(1:4)
    case 'ci16'
        bytes = fread(fo,'int16');
        sig = bytes./2^15;
        Lend = mod(length(sig),2);
        sig = sig(1:end-Lend);
        Y = complex(sig(1:2:end),sig(2:2:end));
    otherwise
        error('tbd data converter for this file format');
end

% file close
fclose(fo);

% % save as mat
% save ble_adv_1 Y fs

cd ..
