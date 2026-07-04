function gain_dB = get_beamforming_gain_vectorized(angle_matrix, antenna_types, azimuth_row, Config)
% GET_BEAMFORMING_GAIN_VECTORIZED 
% Optimized for Matrix Inputs (num_UEs x num_BS)

    gain_dB = zeros(size(angle_matrix));

    % Since antenna_types is a cell array (1 x num_BS), we check columns
    % We assume homogeneous types per layer for speed, but this supports mixed.
    
    % --- Conventional ---
    is_conv = strcmpi(antenna_types, 'Conventional');
    if any(is_conv)
        % Columns that are conventional
        az = azimuth_row(is_conv);
        theta_ue = angle_matrix(:, is_conv);
        
        % Delta calculation (Matrix - RowVector)
        delta = abs(theta_ue - az);
        delta = min(delta, 360 - delta);
        
        params = Config.Antenna.Conventional;
        pattern_drop = 12 * (delta / params.theta_3db).^2;
        gain_dB(:, is_conv) = params.max_gain_dBi - min(pattern_drop, params.front_to_back);
    end

    % --- Massive MIMO ---
    % Treat Smart Array (Small Cells) with beamsteering logic similar to MIMO
    is_mimo = strcmpi(antenna_types, 'MassiveMIMO') | strcmpi(antenna_types, 'Smart Array');
    if any(is_mimo)
        % For MIMO, we assume Beamsteering -> Peak Gain is always achieved
        % (Simulating that the beam tracks the user perfectly)
        params = Config.Antenna.MassiveMIMO;
        N = params.num_elements;
        max_gain = params.element_gain_dBi + 10*log10(N);
        
        % Assign peak gain to all users for these columns
        gain_dB(:, is_mimo) = max_gain;
    end
end