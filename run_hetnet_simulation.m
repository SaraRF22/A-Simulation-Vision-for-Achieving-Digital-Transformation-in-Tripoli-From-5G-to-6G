function Results = run_hetnet_simulation(Config, Network, UEs)
% RUN_HETNET_SIMULATION: Core Physics Engine
% UPDATED: Implements Frequency-Dependent Penetration Loss (3GPP TR 38.901)

    fprintf('--- Running Simulation: %s ---\n', Config.scenario_name);
    
    num_UEs = UEs.num_UEs;
    num_BS = Network.num_gNodeBs;
    sim_steps = Config.simulation_time_s;

    % --- 1. Pre-Extract Network Data ---
    BS_x = single(Network.gNodeBs.x_row);
    BS_y = single(Network.gNodeBs.y_row);
    BS_freq = single(Network.gNodeBs.freq_GHz_row); 
    BS_pow = single(Network.gNodeBs.tx_power_dBm_row);
    BS_az = single(Network.gNodeBs.azimuth_deg_row);
    
    if isfield(Network.gNodeBs, 'height_m_row')
        BS_height = single(Network.gNodeBs.height_m_row);
    else
        BS_height = single(repmat(25, 1, num_BS)); % Fallback to 25m
    end
    
    BS_layer = Network.gNodeBs.layer_id_row; 
    is_conv = strcmpi(Network.gNodeBs.antenna_type, 'Conventional');
    
    % --- NEW FIX: Define MIMO / Smart Array indices ---
    is_mimo = strcmpi(Network.gNodeBs.antenna_type, 'Massive MIMO') | ...
              strcmpi(Network.gNodeBs.antenna_type, 'MassiveMIMO') | ...
              strcmpi(Network.gNodeBs.antenna_type, 'Smart Array');
    
    % --- 2. Initialize User State ---
    UE_x = single(UEs.x_col); 
    UE_y = single(UEs.y_col);
    ue_sp = single(Config.max_ue_speed_ms * rand(num_UEs, 1));
    ue_dir = single(2 * pi * rand(num_UEs, 1));
    time_step = single(Config.time_step_s);
    ue_height = Config.ue_height_m; 
    
    Results = struct();
    Results.aggregate.avg_sinr_dB = zeros(sim_steps, 1);
    Results.aggregate.net_throughput_mbps = zeros(sim_steps, 1);
    
    ue_sinr_final = zeros(num_UEs, 1, 'single');
    served_id_final = zeros(num_UEs, 1);
    
    Noise_dBm = -174 + 10*log10(400e6) + Config.noise_figure_dB; 
    Noise_W = 10^((Noise_dBm - 30)/10); 
    
    Rej_Factor_Lin = 10^(Config.cso_sll_rejection_dB/10);
    
    tic;
    % --- 3. Time Loop ---
    for t = 1:sim_steps
        UE_x = UE_x + ue_sp .* cos(ue_dir) * time_step;
        UE_y = UE_y + ue_sp .* sin(ue_dir) * time_step;
        
        batch_size = 200;
        running_sinr_dB_sum = 0; 
        
        running_tput_sum = 0;
        
        for b = 1:batch_size:num_UEs
            idx = b:min(b+batch_size-1, num_UEs);
            N_batch = length(idx);
            
            % A. 3D Distance Calculation
            dx = UE_x(idx) - BS_x; 
            dy = UE_y(idx) - BS_y;
            d2_2D = dx.^2 + dy.^2;
            d_2D_m = max(sqrt(d2_2D), 1); 
            d_3D_m = sqrt(d_2D_m.^2 + (repmat(BS_height, N_batch, 1) - ue_height).^2);
            
            f_GHz = repmat(BS_freq, N_batch, 1);
            
            % B & C. DYNAMIC 3GPP UMa / UMi PATHLOSS
            P_LOS = zeros(N_batch, num_BS, 'single');
            PL_LOS = zeros(N_batch, num_BS, 'single');
            PL_NLOS = zeros(N_batch, num_BS, 'single');
            
            % LAYER 1: UMa
            idx_uma = (BS_layer == 1);
            if any(idx_uma)
                P_LOS(:, idx_uma) = min(18 ./ d_2D_m(:, idx_uma), 1) .* (1 - exp(-d_2D_m(:, idx_uma) / 63)) + exp(-d_2D_m(:, idx_uma) / 63);
                PL_LOS(:, idx_uma) = 28.0 + 22 * log10(d_3D_m(:, idx_uma)) + 20 * log10(f_GHz(:, idx_uma));
                PL_NLOS(:, idx_uma) = 13.5 + 39.08 * log10(d_3D_m(:, idx_uma)) + 20 * log10(f_GHz(:, idx_uma)) - 0.6 * (ue_height - 1.5);
            end
            
            % LAYER 2: UMi
            idx_umi = (BS_layer == 2);
            if any(idx_umi)
                P_LOS(:, idx_umi) = min(18 ./ d_2D_m(:, idx_umi), 1) .* (1 - exp(-d_2D_m(:, idx_umi) / 36)) + exp(-d_2D_m(:, idx_umi) / 36);
                PL_LOS(:, idx_umi) = 32.4 + 21 * log10(d_3D_m(:, idx_umi)) + 20 * log10(f_GHz(:, idx_umi));
                PL_NLOS(:, idx_umi) = 22.4 + 35.3 * log10(d_3D_m(:, idx_umi)) + 21.3 * log10(f_GHz(:, idx_umi));
            end
            
            is_LOS = rand(N_batch, num_BS) < P_LOS; 
            
            % --- DYNAMIC INDOOR PENETRATION FIX (Frequency Dependent) ---
            is_indoor = rand(N_batch, 1) < Config.indoor_user_percentage;
            is_LOS(is_indoor, :) = false; 
            
            PL = zeros(N_batch, num_BS, 'single');
            PL(is_LOS) = PL_LOS(is_LOS) + 4 * randn(sum(is_LOS(:)), 1, 'single');
            
            % NEW: 3GPP TR 38.901 Frequency-Dependent Penetration
            freq_penalty = zeros(1, num_BS, 'single');
            freq_penalty(BS_freq > 10) = 25; % Apply extreme penalty to mmWave
            
            total_pen_loss = Config.building_penetration_loss_dB + repmat(freq_penalty, N_batch, 1);
            
            % Apply the heavy, frequency-aware building penalty
            PL(~is_LOS) = PL_NLOS(~is_LOS) + total_pen_loss(~is_LOS) + 7.8 * randn(sum(~is_LOS(:)), 1, 'single');
             
           % D. Antenna Gain
            G = zeros(N_batch, num_BS, 'single');
            ang = atan2d(dy, dx); 
            
            % 1. Conventional Antennas (Baseline: Fixed 65-degree sectors)
            if any(is_conv)
                az_mat = repmat(BS_az, N_batch, 1);
                delta = min(abs(ang - az_mat), 360 - abs(ang - az_mat));
                G(:, is_conv) = 18 - min(12*(delta(:, is_conv)/65).^2, 25);
            end
            
            % 2. NEW FIX: Massive MIMO & Smart Arrays (Dynamic Beamsteering)
            if any(is_mimo)
                % Smart arrays dynamically steer the main lobe (28 dBi) at the user.
                % The CSO algorithm handles the 25dB Side Lobe (SLL) suppression 
                % of the interfering towers during the final SINR calculation.
                G(:, is_mimo) = 28; 
            end
            
            % E. Received Power & Cell Selection
            Rx_dBm = repmat(BS_pow, N_batch, 1) + G - PL;
            Bias = zeros(1, num_BS, 'single');
            Bias(BS_layer == 2) = Config.small_cell_offset_dB;
            
            [~, s_idx] = max(Rx_dBm + repmat(Bias, N_batch, 1), [], 2);
            if t == sim_steps
                served_id_final(idx) = s_idx;
            end
            
            % F. SINR Calculation (FIXED: Co-Channel Masking & dB Averaging)
            Rx_Lin = 10.^((Rx_dBm - 30)/10);
            
            f_served = BS_freq(s_idx); 
            f_served = f_served(:); 
            f_matrix = repmat(BS_freq, N_batch, 1);
            co_channel_mask = (f_matrix == repmat(f_served, 1, num_BS));
            
            Rx_Lin_CoChannel = Rx_Lin .* co_channel_mask;
            
            lin_idx = sub2ind(size(Rx_Lin), (1:N_batch)', s_idx);
            Sig_W = Rx_Lin(lin_idx);
            
            Total_W_CoChannel = sum(Rx_Lin_CoChannel, 2);
            Interf_Raw_W = Total_W_CoChannel - Sig_W;
            Interf_Final_W = Interf_Raw_W / Rej_Factor_Lin;
            
            SINR_Lin = Sig_W ./ (Interf_Final_W + Noise_W);
            SINR_dB = 10 * log10(max(SINR_Lin, 1e-10)); 
            
            if t == sim_steps
                ue_sinr_final(idx) = SINR_dB;
            end
            
            running_sinr_dB_sum = running_sinr_dB_sum + sum(SINR_dB);
        end
        
        Results.aggregate.avg_sinr_dB(t) = running_sinr_dB_sum / num_UEs;
    end
    toc;
    
    % --- 4. Final Real-World Resource Allocation ---
    Results.UE.x_col = double(UE_x);
    Results.UE.y_col = double(UE_y);
    Results.UE.sinr_dB = double(ue_sinr_final);
    Results.UE.served_cell_ids = served_id_final;
    
    Results.UE.spectral_efficiency = get_spectral_efficiency_from_sinr(Results.UE.sinr_dB);
    
    bs_loads = histcounts(served_id_final, 1:(num_BS+1)); 
    Results.UE.throughput_mbps = zeros(num_UEs, 1);
    total_network_tput = 0;
    
    for i = 1:num_UEs
        bs_id = served_id_final(i);
        if bs_id > 0
            users_on_this_bs = bs_loads(bs_id);
            
            % NEW FIX: Dynamically pull Bandwidth from the Config file!
            if Network.gNodeBs.layer_id_row(bs_id) == 1
                bw_MHz = Config.NetworkLayers{1}.bw_MHz; % Pulls 100 MHz
            else
                bw_MHz = Config.NetworkLayers{2}.bw_MHz; % Pulls 800 MHz
            end
            
            Results.UE.throughput_mbps(i) = (bw_MHz / users_on_this_bs) * Results.UE.spectral_efficiency(i);
            total_network_tput = total_network_tput + Results.UE.throughput_mbps(i);
        end
    end
    
    Results.aggregate.net_throughput_mbps(:) = total_network_tput;
    
    fprintf('--- Simulation Complete ---\n');
end