function write_sigmf_annotations(input_filename, output_filename, packet_starts, packet_lengths, packet_infos, packet_bandwidths, offset)
    % WRITE_SIGMF_ANNOTATIONS Reads a SigMF-meta file, adds packet annotations 
    % including frequency bandwidth information, and saves it to a new file.
    % Ensures JSON arrays (like captures) remain properly formatted.

    % ==========================================
    % 1. Read and parse the existing sigmf-meta file
    % ==========================================
    raw_json = fileread(input_filename);
    
    % Replace "core:" with "core_" to avoid invalid MATLAB struct field names
    safe_json = strrep(raw_json, '"core:', '"core_');
    meta_data = jsondecode(safe_json);
    
    % ==========================================
    % 2. Extract Center Frequency & Fix Captures Array
    % ==========================================
    try
        if iscell(meta_data.captures)
            center_freq = meta_data.captures{1}.core_frequency;
        else
            center_freq = meta_data.captures(1).core_frequency;
            
            % [Key Fix]: If MATLAB jsondecode converted a single-element JSON array 
            % into a normal struct, we must wrap it back into a cell array 
            % using num2cell. This ensures jsonencode outputs it as an array [...].
            meta_data.captures = num2cell(meta_data.captures);
        end
    catch
        warning('Could not find core:frequency in captures. Using 0 Hz as default.');
        center_freq = 0;
    end
    
    % ==========================================
    % 3. Create and append Annotations
    % ==========================================
    num_packets = length(packet_starts);
    
    % Using a cell array ensures jsonencode outputs a JSON array [...]
    new_annotations = cell(num_packets, 1); 
    
    is_scalar_bw = isscalar(packet_bandwidths);
    
    for i = 1:num_packets
        anno = struct();
        
        % Convert MATLAB's 1-indexed positions to SigMF's 0-indexed format
        anno.core_sample_start = packet_starts(i) - 1; 
        anno.core_sample_count = packet_lengths(i);
        anno.core_description  = packet_infos{i};
        
        % --- Bandwidth Edge Calculations ---
        if is_scalar_bw
            bw = packet_bandwidths;
        else
            bw = packet_bandwidths(i);
        end
        
        anno.core_freq_lower_edge = center_freq - (bw / 2) + offset;
        anno.core_freq_upper_edge = center_freq + (bw / 2) + offset;
        
        new_annotations{i} = anno;
    end
    
    meta_data.annotations = new_annotations;
    
    % ==========================================
    % 4. Convert struct back to JSON and save
    % ==========================================
    out_json = jsonencode(meta_data, 'PrettyPrint', true);
    
    % Replace "core_" back to the standard "core:"
    out_json = strrep(out_json, '"core_', '"core:');
    
    % Write to the new .sigmf-meta file
    fid = fopen(output_filename, 'w');
    if fid == -1
        error('Cannot create or write to file: %s', output_filename);
    end
    
    fprintf(fid, '%s', out_json);
    fclose(fid);
    
    fprintf('Successfully added %d annotations with bandwidth info and saved to %s\n', num_packets, output_filename);
end