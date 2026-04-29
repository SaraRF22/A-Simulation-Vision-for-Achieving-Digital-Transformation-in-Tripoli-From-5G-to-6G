% =========================================================================
% SIMULATE_RIS_6G_TRANSITION_GLOBECOM_FINAL (Advanced 6G Version)
% Thesis Module: Dense 6G Hybrid Connectivity (5G mmWave + 60GHz RIS)
% Features: 
%   1. GLOBECOM PHY Constraints (Rigorous Hardware Losses)
%   2. ADVANCED LOGIC: Proportional Fair (PF) Resource Allocation
%   3. Solves the spatial fairness collapse of the Greedy algorithm
% =========================================================================
clc; close all;
fprintf('--- Starting 6G Hybrid RIS Simulation (Advanced PF Build) ---\n');
rng(97); % Set random seed for absolute academic reproducibility

% --- 1. Load Enhanced 5G Data ---
if ~exist('Results_Enhanced.mat', 'file')
    error('Results_Enhanced.mat missing. Run main_enhanced_mmwave_simulation.m first.');
end
Data = load('Results_Enhanced.mat');
Config = Data.Config;
Network = Data.Network;
Results_5G = Data.Results;
num_users = length(Results_5G.UE.x_col);

% --- 2. 6G / RIS Parameters (With Strict Physical Constraints) ---
Freq_6G = 60;             
BW_6G = 1200e6;           
RIS_Count = 400;          
Num_RIS_Elements = 10000; 
RIS_Array_Gain_dB = 10 * log10(Num_RIS_Elements^2); 
Tx_Antenna_Gain = 25; 
Rx_Antenna_Gain = 10; 
Active_Amp_Gain = 15; 
Phase_Quant_Loss_dB = 3.0; 
Beam_Isolation_dB = 20.0;  
Rx_Noise_Figure = 10;      
RIS_Insertion_Loss_dB = 4.0;   
Max_CSI_Error_dB = 5.0;        

Total_System_Gain_Ideal = RIS_Array_Gain_dB + Tx_Antenna_Gain + Rx_Antenna_Gain + Active_Amp_Gain - Phase_Quant_Loss_dB - RIS_Insertion_Loss_dB;
Isolation_Linear = 10^(-Beam_Isolation_dB / 10);

% --- 3. Intelligent RIS Deployment (K-Means) ---
fprintf('Deploying %d Active RIS Panels...\n', RIS_Count);
ue_coords = double([Results_5G.UE.x_col(:), Results_5G.UE.y_col(:)]);
[~, C_ris] = kmeans(ue_coords, RIS_Count, 'MaxIter', 1000, 'Replicates', 3);
ris_x = zeros(RIS_Count, 1); ris_y = zeros(RIS_Count, 1);
for r = 1:RIS_Count
    dist_sq = (ue_coords(:,1) - C_ris(r,1)).^2 + (ue_coords(:,2) - C_ris(r,2)).^2;
    [~, min_idx] = min(dist_sq);
    ris_x(r) = ue_coords(min_idx, 1); ris_y(r) = ue_coords(min_idx, 2);
end
ris_coords = unique([ris_x, ris_y], 'rows');
ris_x = ris_coords(:,1); ris_y = ris_coords(:,2);
Actual_RIS_Count = length(ris_x);

% --- 4. Unified Physics Engine ---
BS_X = Network.gNodeBs.x_row; BS_Y = Network.gNodeBs.y_row; BS_Pow = Network.gNodeBs.tx_power_dBm_row;
Noise_6G_dBm = -174 + 10*log10(BW_6G) + Rx_Noise_Figure; 
Noise_6G_W = 10^((Noise_6G_dBm - 30)/10);
Raw_Rx_W = sparse(num_users, Actual_RIS_Count); Dist_2D = sparse(num_users, Actual_RIS_Count);

%% PASS 1: Simulating Sub-Terahertz Channels 
fprintf(' > Pass 1: Computing physical links (Rigorous)...\n');
for u = 1:num_users
    ue_x = Results_5G.UE.x_col(u); ue_y = Results_5G.UE.y_col(u); bs_idx = Results_5G.UE.served_cell_ids(u);
    if bs_idx > 0
        d2_vals = max(sqrt((ris_x - ue_x).^2 + (ris_y - ue_y).^2), 1);
        valid_ris_idx = find(d2_vals <= 800);
        if ~isempty(valid_ris_idx)
            d2_eval = d2_vals(valid_ris_idx);
            d1_eval = max(sqrt((BS_X(bs_idx) - ris_x(valid_ris_idx)).^2 + (BS_Y(bs_idx) - ris_y(valid_ris_idx)).^2), 1);

            P_LOS_1 = min(18 ./ d1_eval, 1) .* (1 - exp(-d1_eval / 36)) + exp(-d1_eval / 36);
            P_LOS_2 = min(18 ./ d2_eval, 1) .* (1 - exp(-d2_eval / 36)) + exp(-d2_eval / 36);

            is_los_1 = rand(length(valid_ris_idx), 1) < P_LOS_1;
            pl1 = zeros(length(valid_ris_idx), 1);
            pl1(is_los_1) = 32.4 + 21*log10(d1_eval(is_los_1)) + 20*log10(Freq_6G) + 4*randn(sum(is_los_1), 1);
            pl1(~is_los_1) = 22.4 + 35.3*log10(d1_eval(~is_los_1)) + 21.3*log10(Freq_6G) + 7.8*randn(sum(~is_los_1), 1);

            is_los_2 = rand(length(valid_ris_idx), 1) < P_LOS_2;
            pl2 = zeros(length(valid_ris_idx), 1);
            pl2(is_los_2) = 32.4 + 21*log10(d2_eval(is_los_2)) + 20*log10(Freq_6G) + 4*randn(sum(is_los_2), 1);
            pl2(~is_los_2) = 22.4 + 35.3*log10(d2_eval(~is_los_2)) + 21.3*log10(Freq_6G) + 7.8*randn(sum(~is_los_2), 1);

            CSI_Penalty = Max_CSI_Error_dB * rand(length(valid_ris_idx), 1);
            rx_dbm = BS_Pow(bs_idx) - pl1 - pl2 + Total_System_Gain_Ideal - CSI_Penalty;
            Raw_Rx_W(u, valid_ris_idx) = (10.^((rx_dbm - 30)/10))'; Dist_2D(u, valid_ris_idx) = d2_eval';
        end
    end
end

%% PASS 2: RIS-Centric Resource Allocation (PROPORTIONAL FAIR)
fprintf(' > Pass 2: Executing ADVANCED Proportional Fair Allocation...\n');
Eta_PF = sparse(num_users, Actual_RIS_Count);
for r = 1:Actual_RIS_Count
    users_in_range = find(Raw_Rx_W(:, r) > 0);
    if isempty(users_in_range), continue; end
    d2_r = full(Dist_2D(users_in_range, r));

    % LOGIC: 6G ADVANCED (PF based on historical 5G throughput starvation)
    valid_pf = users_in_range(d2_r <= 250);
    if ~isempty(valid_pf)
        % Calculate PF Weights: Inverse of 5G throughput (prioritize weak users)
        prior_tput = Results_5G.UE.throughput_mbps(valid_pf);
        pf_weights = 1 ./ (prior_tput + 10); % Add 10 Mbps floor to prevent infinity
        pf_weights = pf_weights / sum(pf_weights); % Normalize sum to 1.0

        Eta_PF(valid_pf, r) = pf_weights; % Distribute elements proportionally
    end
end

%% PASS 3: True SINR & Capacity Calculation
fprintf(' > Pass 3: Calculating Advanced True SINR...\n');
sinr_6g_pf_dB_col = -50 * ones(num_users, 1); tput_6g_pf_col = zeros(num_users, 1);
all_ris_indices = 1:Actual_RIS_Count;
for u = 1:num_users
    active_pf = find(Eta_PF(u, :) > 0);
    if ~isempty(active_pf)
        % Desired Signal (Coherent addition based on allocated fraction)
        p_pf = sum(full(Eta_PF(u, active_pf)) .* full(Raw_Rx_W(u, active_pf)));
        interfering = setdiff(all_ris_indices, active_pf);
        I_pf = sum(full(Raw_Rx_W(u, interfering))) * Isolation_Linear;
        sinr_lin = p_pf / (Noise_6G_W + I_pf);
        sinr_6g_pf_dB_col(u) = 10*log10(sinr_lin);
        tput_6g_pf_col(u) = BW_6G * log2(1 + sinr_lin);
    end
end

Results_6G_Advanced = Results_5G; 
Results_6G_Advanced.UE.throughput_mbps = Results_5G.UE.throughput_mbps + (tput_6g_pf_col / 1e6);
Results_6G_Advanced.UE.sinr_dB = max(Results_5G.UE.sinr_dB, sinr_6g_pf_dB_col);

% --- Metrics & Table ---
M_5G = calc_metrics(Results_5G.UE.throughput_mbps, Results_5G.UE.sinr_dB);
M_6G_PF = calc_metrics(Results_6G_Advanced.UE.throughput_mbps, Results_6G_Advanced.UE.sinr_dB);
print_table(M_5G, M_6G_PF);

%% ========================================================================
%  THESIS VISUALIZATION SUITE (Updated for Proportional Fair Variables)
% =========================================================================
fprintf('--- Generating IEEE-Formatted Figures ---\n');

% Define Plot Colors (IEEE Standard)
color_5g = [0 0.4470 0.7410];      % Deep Blue
color_6g_pf = [0.8500 0.3250 0.0980]; % Deep Orange

% Map Variables for Seamless Plotting
b_tput_mbps = Results_5G.UE.throughput_mbps;
b_tput_gbps = b_tput_mbps / 1000;
e_tput_pf_mbps = Results_6G_Advanced.UE.throughput_mbps;
e_tput_pf_gbps = e_tput_pf_mbps / 1000;

% Translate Cartesian to Geographic Coordinates for Heatmaps
[u_lat, u_lon] = xy2latlon(Results_5G.UE.x_col, Results_5G.UE.y_col, Config);
[ris_lat, ris_lon] = xy2latlon(ris_x, ris_y, Config);

% FIG 1: Deployment Map (Tripoli Shapefile)
figure('Name', '6G RIS Deployment', 'Color', 'w', 'Position', [100, 100, 900, 700]);
gx = geoaxes; geobasemap(gx, 'satellite'); hold(gx, 'on');
if isfield(Config, 'coastline_poly') && ~isempty(Config.coastline_poly.lon)
    geoplot(gx, Config.coastline_poly.lat, Config.coastline_poly.lon, 'w-', 'LineWidth', 2, 'DisplayName', 'Tripoli Bounds');
end
m_idx = Network.gNodeBs.layer_id_row == 1;
s_idx = Network.gNodeBs.layer_id_row == 2;
geoscatter(gx, Network.gNodeBs.lat(m_idx), Network.gNodeBs.lon(m_idx), 150, 'r', '^', 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Macro BS');
geoscatter(gx, Network.gNodeBs.lat(s_idx), Network.gNodeBs.lon(s_idx), 80, 'c', 's', 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Small Cell');
geoscatter(gx, ris_lat, ris_lon, 80, 'g', 'd', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1, 'DisplayName', sprintf('RIS (%d)', Actual_RIS_Count));
legend('Location', 'northeast', 'TextColor', 'k', 'Color', 'w');
title('6G Dense Hybrid Deployment (Tripoli GIS Bounded)');
geolimits(gx, Config.lat_bounds, Config.lon_bounds);

% FIG 2: CDF Comparison
figure('Name', '6G CDF Comparison', 'Color', 'w', 'Position', [150, 150, 600, 400]);
hold on; grid on;
h1 = cdfplot(b_tput_gbps); set(h1, 'Color', color_5g, 'LineWidth', 3); 
h2 = cdfplot(e_tput_pf_gbps); set(h2, 'Color', color_6g_pf, 'LineWidth', 3);
xlabel('User Throughput (Gbps)', 'FontWeight', 'bold'); 
ylabel('CDF', 'FontWeight', 'bold'); 
title('CDF Performance: 5G vs 6G Advanced (PF)', 'FontSize', 14); 
legend({'5G Baseline', '6G Advanced (PF)'}, 'Location', 'southeast', 'FontSize', 11);
ylim([0, 1.05]);
ax = gca;
ax.XAxis.Exponent = 0;   
ax.YAxis.Exponent = 0;   
xticks(0:5:30); 
xtickformat('%.0f');     
ytickformat('%.1f');     
set(ax, 'FontSize', 11, 'LineWidth', 1.2, 'Box', 'on');

% FIG 3: Metrics Bar Chart
figure('Name', 'Metrics Comparison', 'Color', 'w', 'Position', [200, 200, 500, 400]);
vals = [M_5G.Avg_Gbps, M_6G_PF.Avg_Gbps; M_5G.Edge_Mbps/1000, M_6G_PF.Edge_Mbps/1000; M_5G.Peak_Gbps, M_6G_PF.Peak_Gbps];
b = bar(vals); b(1).FaceColor = color_5g; b(2).FaceColor = color_6g_pf; 
xticklabels({'Avg Tput', 'Edge Tput', 'Peak Tput'}); ylabel('Throughput (Gbps)'); 
title('Performance Leap: 5G vs 6G Advanced'); 
legend({'5G Enhanced', '6G Advanced (PF)'}, 'Location', 'northwest'); grid on;

% FIG 4: Fairness vs Capacity (Shift Plot)
figure('Name', 'Fairness vs Capacity', 'Color', 'w', 'Position', [350, 150, 600, 500]);
plot([M_5G.Avg_Gbps, M_6G_PF.Avg_Gbps], [M_5G.Fairness, M_6G_PF.Fairness], 'k-', 'LineWidth', 1.5); hold on;
scatter(M_5G.Avg_Gbps, M_5G.Fairness, 150, color_5g, 's', 'filled', 'DisplayName', '5G Enhanced');
scatter(M_6G_PF.Avg_Gbps, M_6G_PF.Fairness, 200, color_6g_pf, '^', 'filled', 'DisplayName', '6G Advanced (PF)');
xlabel('Average User Capacity (Gbps)', 'FontWeight', 'bold'); ylabel('Jain''s Fairness Index', 'FontWeight', 'bold'); 
title('Capacity vs. Spatial Fairness Trade-off', 'FontSize', 12); grid on; legend('Location', 'northeast'); ylim([0 1]); xlim([0 max(M_6G_PF.Avg_Gbps)*1.3]);
text(M_6G_PF.Avg_Gbps, M_6G_PF.Fairness - 0.05, sprintf(' PF: %.2f', M_6G_PF.Fairness), 'Color', color_6g_pf, 'FontWeight', 'bold');

% FIG 5: Spatial Capacity Delta Map
figure('Name', 'Capacity Delta Map', 'Color', 'w', 'Position', [400, 200, 800, 600]);
gx = geoaxes; geobasemap(gx, 'satellite'); hold(gx, 'on');
if isfield(Config, 'coastline_poly') && ~isempty(Config.coastline_poly.lon)
    geoplot(gx, Config.coastline_poly.lat, Config.coastline_poly.lon, 'y-', 'LineWidth', 2, 'DisplayName', 'Tripoli Boundary');
end
delta_tput_gbps = (e_tput_pf_mbps - b_tput_mbps) / 1000;
geoscatter(gx, u_lat, u_lon, 40, delta_tput_gbps, 'filled', 'MarkerFaceAlpha', 0.9);
colormap(gx, parula); c = colorbar(gx); c.Label.String = 'Capacity Gain (Gbps)'; c.Label.FontWeight = 'bold';
title('Spatial Heatmap: Mapping 6G Capacity Gains');
geolimits(gx, Config.lat_bounds, Config.lon_bounds);

% FIG 6: Distance vs. Throughput
figure('Name', 'Distance vs Throughput', 'Color', 'w', 'Position', [450, 250, 700, 500]);
hold on; grid on;
dist_from_center_km = sqrt(Results_5G.UE.x_col.^2 + Results_5G.UE.y_col.^2) / 1000;
scatter(dist_from_center_km, b_tput_gbps, 25, color_5g, 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', '5G Enhanced');
scatter(dist_from_center_km, e_tput_pf_gbps, 25, color_6g_pf, 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', '6G Advanced (PF)');
xlabel('Distance from City Center (km)', 'FontWeight', 'bold'); ylabel('User Throughput (Gbps)', 'FontWeight', 'bold');
title('Capacity Across Distance: 5G vs 6G Advanced');
legend('Location', 'northeast');

fprintf('--- Visualization Completed. ---\n');

% --- Helper Functions ---
function M = calc_metrics(tput_mbps, sinr_db)
    M.Avg_Gbps = mean(tput_mbps) / 1000; M.Peak_Gbps = max(tput_mbps) / 1000;
    M.Edge_Mbps = prctile(tput_mbps, 5); M.Avg_SINR = mean(sinr_db);
    M.Fairness = (sum(tput_mbps)^2) / (length(tput_mbps) * sum(tput_mbps.^2));
end

function print_table(M5, M6P)
    fprintf('\n=========================================================\n');
    fprintf('        5G ENHANCED vs. 6G ADVANCED (PF Algorithm)       \n');
    fprintf('=========================================================\n');
    fprintf('%-20s | %-12s | %-12s\n', 'Metric', '5G Enh', '6G Adv (PF)');
    fprintf('---------------------------------------------------------\n');
    fprintf('%-20s | %6.2f Gbps | %6.2f Gbps\n', 'Avg Throughput', M5.Avg_Gbps, M6P.Avg_Gbps);
    fprintf('%-20s | %6.2f Mbps | %6.2f Mbps\n', 'Cell Edge (5%)', M5.Edge_Mbps, M6P.Edge_Mbps);
    fprintf('%-20s | %6.2f Gbps | %6.2f Gbps\n', 'Peak Throughput', M5.Peak_Gbps, M6P.Peak_Gbps);
    fprintf('%-20s | %6.4f      | %6.4f     \n', 'Fairness Index', M5.Fairness, M6P.Fairness);
    fprintf('%-20s | %6.2f dB   | %6.2f dB\n', 'Average SINR', M5.Avg_SINR, M6P.Avg_SINR);
    fprintf('=========================================================\n');
end

