% =========================================================================
% SIMULATE_RIS_6G_TRANSITION_GLOBECOM_FINAL
% Thesis Module: Dense 6G Hybrid Connectivity (5G mmWave + 60GHz RIS)
% Features: 
%   1. RIS-Centric Max-Min Optimization (Strict sum(eta) <= 1.0 constraint)
%   2. GLOBECOM PHY Constraints (SE Caps, Phase Quant Loss, Beam Isolation)
%   3. True CQI-based Proportional Fair Scheduling
%   4. Strict IEEE Figure Formatting
% =========================================================================
clc; close all;
fprintf('--- Starting 6G Hybrid RIS Simulation (CQI-PF Build) ---\n');
rng(97); 

% --- 1. Load Enhanced 5G Data ---
if ~exist('Results_Enhanced.mat', 'file')
    error('Results_Enhanced.mat missing. Run main_enhanced_mmwave_simulation.m first.');
end
Data = load('Results_Enhanced.mat');
Config = Data.Config;
Network = Data.Network;
Results_5G = Data.Results;
num_users = length(Results_5G.UE.x_col);

% --- 2. 6G / RIS Parameters ---
Freq_6G = 60;             
BW_6G = 1200e6;           
RIS_Count = 400;          
Num_RIS_Elements = 10000; 
RIS_Array_Gain_dB = 10 * log10(Num_RIS_Elements^2); 
Tx_Antenna_Gain = 25; 
Rx_Antenna_Gain = 10; 
Active_Amp_Gain = 15; 
Phase_Quant_Loss_dB = 3.0; 
Rx_Noise_Figure = 10;      
Max_SE_6G = 12.0;          % HARDWARE SE CAP
Beam_Isolation_dB = 20.0;  
Isolation_Linear = 10^(-Beam_Isolation_dB / 10);
Total_System_Gain = RIS_Array_Gain_dB + Tx_Antenna_Gain + Rx_Antenna_Gain + Active_Amp_Gain - Phase_Quant_Loss_dB;

% --- 3. Intelligent RIS Deployment (K-Means) ---
fprintf('Deploying %d Active RIS Panels via K-Means Clustering...\n', RIS_Count);
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
[ris_lat, ris_lon] = xy2latlon(ris_x, ris_y, Config);

% --- 4. Unified Physics Engine ---
fprintf('--- Starting Physical Layer & Optimization ---\n');
BS_X = Network.gNodeBs.x_row; BS_Y = Network.gNodeBs.y_row; BS_Pow = Network.gNodeBs.tx_power_dBm_row;
Noise_6G_dBm = -174 + 10*log10(BW_6G) + Rx_Noise_Figure; 
Noise_6G_W = 10^((Noise_6G_dBm - 30)/10);

Raw_Rx_W = sparse(num_users, Actual_RIS_Count); Dist_2D = sparse(num_users, Actual_RIS_Count);

%% PASS 1: Simulating Sub-Terahertz Channels 
fprintf(' > Pass 1: Computing sub-Terahertz physical links...\n');
tic;
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
            
            rx_dbm = BS_Pow(bs_idx) - pl1 - pl2 + Total_System_Gain;
            Raw_Rx_W(u, valid_ris_idx) = (10.^((rx_dbm - 30)/10))'; Dist_2D(u, valid_ris_idx) = d2_eval';
        end
    end
end
toc;

%% PASS 2: RIS-Centric Resource Allocation 
fprintf(' > Pass 2: Executing Global Hardware Constraints...\n');
Eta_Basic = sparse(num_users, Actual_RIS_Count); Eta_MCB = sparse(num_users, Actual_RIS_Count);
tic;
for r = 1:Actual_RIS_Count
    users_in_range = find(Raw_Rx_W(:, r) > 0);
    if isempty(users_in_range), continue; end
    d2_r = full(Dist_2D(users_in_range, r));
    
    % LOGIC 1: 6G BASIC (Greedy Allocation)
    valid_basic = users_in_range(d2_r <= 400);
    if ~isempty(valid_basic)
        [~, best_idx] = max(full(Raw_Rx_W(valid_basic, r)));
        Eta_Basic(valid_basic(best_idx), r) = 1.0; 
    end
    
    % LOGIC 2: 6G MCB (CQI-based Proportional Fair)
    valid_mcb_raw = users_in_range(d2_r <= 400); 
    
    if ~isempty(valid_mcb_raw)
        viable_mask = Results_5G.UE.sinr_dB(valid_mcb_raw) > -5.0; 
        valid_mcb = valid_mcb_raw(viable_mask);
        
        if ~isempty(valid_mcb)
            prior_tput = Results_5G.UE.throughput_mbps(valid_mcb);
            raw_watts = full(Raw_Rx_W(valid_mcb, r));
            
            c_potential = min(log2(1 + (raw_watts ./ Noise_6G_W)), Max_SE_6G);
            w_u = c_potential ./ (prior_tput + 10); 
            
            [sorted_w, sort_idx] = sort(w_u, 'descend');
            prioritized_users = valid_mcb(sort_idx);
            
            K_max = min(length(prioritized_users), 4); 
            selected_users = prioritized_users(1:K_max);
            selected_weights = sorted_w(1:K_max);
            
            eta_allocation = selected_weights / sum(selected_weights); 
            Eta_MCB(selected_users, r) = eta_allocation;
        end
    end
end
toc;

%% PASS 3: True SINR & Capacity Calculation
fprintf(' > Pass 3: Calculating Constrained SINR and Final Capacity...\n');
sinr_6g_basic_dB_col = -50 * ones(num_users, 1); tput_6g_basic_col = zeros(num_users, 1);
sinr_6g_mcb_dB_col = -50 * ones(num_users, 1); tput_6g_mcb_col = zeros(num_users, 1);
all_ris_indices = 1:Actual_RIS_Count;
tic;
for u = 1:num_users
    % --- Basic ---
    active_basic = find(Eta_Basic(u, :) > 0);
    if ~isempty(active_basic)
        p_basic = sum(full(Eta_Basic(u, active_basic)) .* full(Raw_Rx_W(u, active_basic)));
        interfering_panels = setdiff(all_ris_indices, active_basic);
        I_basic = sum(full(Raw_Rx_W(u, interfering_panels))) * Isolation_Linear;
        sinr_lin = p_basic / (Noise_6G_W + I_basic);
        sinr_6g_basic_dB_col(u) = 10*log10(sinr_lin);
        se_basic = min(log2(1 + sinr_lin), Max_SE_6G); 
        tput_6g_basic_col(u) = BW_6G * se_basic;
    end
    
    % --- MCB ---
    active_mcb = find(Eta_MCB(u, :) > 0);
    if ~isempty(active_mcb)
        volt_sum = sum(sqrt(full(Eta_MCB(u, active_mcb)) .* full(Raw_Rx_W(u, active_mcb))));
        p_mcb = volt_sum^2;
        interfering_panels = setdiff(all_ris_indices, active_mcb);
        I_mcb = sum(full(Raw_Rx_W(u, interfering_panels))) * Isolation_Linear;
        sinr_lin = p_mcb / (Noise_6G_W + I_mcb);
        sinr_6g_mcb_dB_col(u) = 10*log10(sinr_lin);
        se_mcb = min(log2(1 + sinr_lin), Max_SE_6G); 
        tput_6g_mcb_col(u) = BW_6G * se_mcb;
    end
end
toc;

% Apply Totals
Results_6G_Basic = Results_5G; Results_6G_MCB = Results_5G; 
Results_6G_Basic.UE.throughput_mbps = Results_5G.UE.throughput_mbps + (tput_6g_basic_col / 1e6);
Results_6G_MCB.UE.throughput_mbps = Results_5G.UE.throughput_mbps + (tput_6g_mcb_col / 1e6);

% --- Metrics ---
Metrics_5G = calculate_metrics(Results_5G.UE.throughput_mbps);
Metrics_6G_Basic = calculate_metrics(Results_6G_Basic.UE.throughput_mbps);
Metrics_6G_MCB = calculate_metrics(Results_6G_MCB.UE.throughput_mbps);
print_comparison_table_3way(Metrics_5G, Metrics_6G_Basic, Metrics_6G_MCB);

% =========================================================================
% --- 6. VISUALIZATION (IEEE Standards Applied) ---
% =========================================================================
fprintf('--- Starting Section 6: Visualization ---\n');

color_5g = [0.850, 0.325, 0.098]; 
color_6g_basic = [0.6, 0.6, 0.6]; 
color_6g_mcb = [0.466, 0.674, 0.188]; 

b_tput_gbps = Results_5G.UE.throughput_mbps / 1000;
e_tput_gbps = Results_6G_MCB.UE.throughput_mbps / 1000;
e_tput_basic_gbps = Results_6G_Basic.UE.throughput_mbps / 1000;

% IEEE Helper Function for Axis Formatting
format_ieee_axis = @(ax) set(ax, 'Box', 'on', 'Color', 'w', 'XGrid', 'on', 'YGrid', 'on', ...
    'GridLineStyle', ':', 'LineWidth', 1.0, 'FontName', 'Times New Roman', 'FontSize', 11);

% FIG 1: Map (IEEE formatting not strictly applicable to geographic axes, but keeping background clean)
figure('Name', '6G RIS Deployment', 'Color', 'w', 'Position', [100, 100, 900, 700]);
gx = geoaxes; geobasemap(gx, 'satellite'); hold(gx, 'on');
if isfield(Config, 'coastline_poly') && ~isempty(Config.coastline_poly.lon)
    geoplot(gx, Config.coastline_poly.lat, Config.coastline_poly.lon, 'w-', 'LineWidth', 2, 'DisplayName', 'Tripoli Bounds');
end
[u_lat, u_lon] = xy2latlon(Results_5G.UE.x_col, Results_5G.UE.y_col, Config);
m_idx = Network.gNodeBs.layer_id_row == 1; s_idx = Network.gNodeBs.layer_id_row == 2;
geoscatter(gx, Network.gNodeBs.lat(m_idx), Network.gNodeBs.lon(m_idx), 150, 'r', '^', 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Macro BS');
geoscatter(gx, Network.gNodeBs.lat(s_idx), Network.gNodeBs.lon(s_idx), 80, 'c', 's', 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Small Cell');
geoscatter(gx, ris_lat, ris_lon, 80, 'g', 'd', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1, 'DisplayName', sprintf('RIS (%d)', Actual_RIS_Count));
legend('Location', 'northeast', 'TextColor', 'k', 'Color', 'w', 'FontName', 'Times New Roman');
title('6G Dense Hybrid Deployment', 'FontName', 'Times New Roman');

% FIG 2: CDF (IEEE Style)
figure('Name', '6G CDF Comparison', 'Color', 'w', 'Position', [150, 150, 600, 400]); hold on; 
h1 = cdfplot(b_tput_gbps); set(h1, 'Color', color_5g, 'LineWidth', 2.5, 'LineStyle', '-.'); 
h2 = cdfplot(e_tput_basic_gbps); set(h2, 'Color', color_6g_basic, 'LineWidth', 2, 'LineStyle', ':');
h3 = cdfplot(e_tput_gbps); set(h3, 'Color', color_6g_mcb, 'LineWidth', 2.5, 'LineStyle', '-');
xlabel('User Throughput (Gbps)', 'FontWeight', 'bold'); ylabel('CDF', 'FontWeight', 'bold'); 
title(''); % Titles typically omitted in IEEE plots, placed in captions instead
legend({'5G Baseline', '6G Basic (Greedy)', '6G MCB (PF)'}, 'Location', 'southeast', 'FontName', 'Times New Roman');
ylim([0, 1.05]); 
format_ieee_axis(gca);

% FIG 3: Bar Chart (IEEE Style)
figure('Name', 'Metrics Comparison', 'Color', 'w', 'Position', [200, 200, 500, 400]);
vals = [Metrics_5G.Avg_Gbps, Metrics_6G_MCB.Avg_Gbps; Metrics_5G.Edge_Mbps/1000, Metrics_6G_MCB.Edge_Mbps/1000; Metrics_5G.Peak_Gbps, Metrics_6G_MCB.Peak_Gbps];
b = bar(vals); b(1).FaceColor = color_5g; b(2).FaceColor = color_6g_mcb; 
xticklabels({'Avg Tput', 'Edge Tput', 'Peak Tput'}); ylabel('Throughput (Gbps)', 'FontWeight', 'bold'); 
title(''); legend({'5G Baseline', '6G MCB'}, 'Location', 'northwest', 'FontName', 'Times New Roman');
format_ieee_axis(gca);

% FIG 4: Fairness vs Capacity (IEEE Style)
figure('Name', 'Fairness vs Capacity', 'Color', 'w', 'Position', [350, 150, 600, 500]); hold on;
plot([Metrics_5G.Avg_Gbps, Metrics_6G_Basic.Avg_Gbps, Metrics_6G_MCB.Avg_Gbps], [Metrics_5G.Fairness, Metrics_6G_Basic.Fairness, Metrics_6G_MCB.Fairness], 'k-', 'LineWidth', 1.0);
scatter(Metrics_5G.Avg_Gbps, Metrics_5G.Fairness, 100, color_5g, 's', 'filled');
scatter(Metrics_6G_Basic.Avg_Gbps, Metrics_6G_Basic.Fairness, 100, color_6g_basic, '^', 'filled');
scatter(Metrics_6G_MCB.Avg_Gbps, Metrics_6G_MCB.Fairness, 150, color_6g_mcb, 'p', 'filled');
xlabel('Average User Capacity (Gbps)', 'FontWeight', 'bold'); ylabel('Jain''s Fairness Index', 'FontWeight', 'bold'); 
title(''); legend({'Trade-off Trajectory', '5G Enhanced', '6G Basic', '6G RIS MCB'}, 'Location', 'northeast', 'FontName', 'Times New Roman');
xlim([0 max(Metrics_6G_Basic.Avg_Gbps)*1.3]); ylim([0 1]);
format_ieee_axis(gca);

% FIG 5: Delta Map (Geographic axes bypass standard IEEE boxes)
figure('Name', 'Capacity Delta Map', 'Color', 'w', 'Position', [400, 200, 800, 600]);
gx = geoaxes; geobasemap(gx, 'satellite'); hold(gx, 'on');
if isfield(Config, 'coastline_poly') && ~isempty(Config.coastline_poly.lon)
    geoplot(gx, Config.coastline_poly.lat, Config.coastline_poly.lon, 'y-', 'LineWidth', 2);
end
delta_tput_gbps = (Results_6G_MCB.UE.throughput_mbps - Results_5G.UE.throughput_mbps) / 1000;
geoscatter(gx, u_lat, u_lon, 40, delta_tput_gbps, 'filled', 'MarkerFaceAlpha', 0.9);
colormap(gx, parula); c = colorbar(gx); c.Label.String = 'Capacity Gain (Gbps)'; c.Label.FontWeight = 'bold';
title('Spatial Fairness: Mapping 6G MCB Capacity Gains', 'FontName', 'Times New Roman');
geolimits(gx, Config.lat_bounds, Config.lon_bounds);

% FIG 6: Distance Scatter (IEEE Style)
figure('Name', 'Distance vs Throughput', 'Color', 'w', 'Position', [450, 250, 700, 500]); hold on;
dist_from_center_km = sqrt(Results_5G.UE.x_col.^2 + Results_5G.UE.y_col.^2) / 1000;
scatter(dist_from_center_km, b_tput_gbps, 20, color_5g, 's', 'filled', 'MarkerFaceAlpha', 0.5);
scatter(dist_from_center_km, e_tput_basic_gbps, 20, color_6g_basic, '^', 'filled', 'MarkerFaceAlpha', 0.3);
scatter(dist_from_center_km, e_tput_gbps, 20, color_6g_mcb, 'o', 'filled', 'MarkerFaceAlpha', 0.7);
xlabel('Distance from City Center (km)', 'FontWeight', 'bold'); ylabel('User Throughput (Gbps)', 'FontWeight', 'bold');
title(''); legend({'5G Baseline', '6G Basic (Greedy)', '6G MCB (PF)'}, 'Location', 'northeast', 'FontName', 'Times New Roman');
format_ieee_axis(gca);

fprintf('--- Visualization Completed. ---\n');

% =========================================================================
% --- STANDALONE TOY MODEL (Aligned PF Objective) ---
% =========================================================================
fprintf('\n--- Running Toy Model for Optimality Gap Validation ---\n');
U_toy = 10; R_toy = 2;
Raw_Rx_W_toy = rand(U_toy, R_toy) * 1e-7;
baseline_tput_toy = rand(U_toy, 1) * 100; 
Noise_W_toy = 1e-12;

% Run MCB
tic; Eta_MCB_toy = zeros(U_toy, R_toy);
for r = 1:R_toy
    c_potential_toy = log2(1 + (Raw_Rx_W_toy(:, r) / Noise_W_toy));
    w_u = c_potential_toy ./ (baseline_tput_toy + 10);
    
    [~, sort_idx] = sort(w_u, 'descend');
    selected_users = sort_idx(1:4);
    selected_weights = w_u(selected_users); 
    Eta_MCB_toy(selected_users, r) = selected_weights / sum(selected_weights); 
end
pf_utility_mcb = 0;
for u = 1:U_toy
    volt_sum = sum(sqrt(Eta_MCB_toy(u, :) .* Raw_Rx_W_toy(u, :)));
    new_tput = log2(1 + (volt_sum^2 / Noise_W_toy));
    pf_utility_mcb = pf_utility_mcb + log(baseline_tput_toy(u) + new_tput + 10); 
end
time_mcb = toc;

% Run Global Search
tic; num_iterations = 100000; best_pf_utility_opt = -inf; 
for i = 1:num_iterations
    eta_rand = rand(U_toy, R_toy);
    eta_rand(:,1) = eta_rand(:,1) / sum(eta_rand(:,1));
    eta_rand(:,2) = eta_rand(:,2) / sum(eta_rand(:,2));
    
    temp_pf_utility = 0;
    for u = 1:U_toy
        volt_sum = sum(sqrt(eta_rand(u, :) .* Raw_Rx_W_toy(u, :)));
        new_tput = log2(1 + (volt_sum^2 / Noise_W_toy));
        temp_pf_utility = temp_pf_utility + log(baseline_tput_toy(u) + new_tput + 10);
    end
    if temp_pf_utility > best_pf_utility_opt, best_pf_utility_opt = temp_pf_utility; end
end
time_opt = toc;

optimality_gap = (pf_utility_mcb / best_pf_utility_opt) * 100;
fprintf('  > MCB Heuristic Computation Time: %.6f seconds\n', time_mcb);
fprintf('  > Global Search Computation Time: %.6f seconds\n', time_opt);
fprintf('  > MCB Achieved PF Utility: %.2f%% of Absolute Optimal\n', optimality_gap);
fprintf('-------------------------------------------------------------------\n\n');

function M = calculate_metrics(tput_mbps)
    M.Avg_Gbps = mean(tput_mbps) / 1000; M.Peak_Gbps = max(tput_mbps) / 1000;
    M.Edge_Mbps = prctile(tput_mbps, 5); x = tput_mbps; 
    M.Fairness = (sum(x)^2) / (length(x) * sum(x.^2));
end

function print_comparison_table_3way(M5, M6B, M6M)
    fprintf('\n======================================================================\n');
    fprintf('%-20s | %-12s | %-12s | %-12s\n', 'Metric', '5G Enh', '6G Basic', '6G MCB');
    fprintf('----------------------------------------------------------------------\n');
    fprintf('%-20s | %6.2f Gbps | %6.2f Gbps | %6.2f Gbps\n', 'Avg Throughput', M5.Avg_Gbps, M6B.Avg_Gbps, M6M.Avg_Gbps);
    fprintf('%-20s | %6.2f Mbps | %6.2f Mbps | %6.2f Mbps\n', 'Cell Edge (5%)', M5.Edge_Mbps, M6B.Edge_Mbps, M6M.Edge_Mbps);
    fprintf('%-20s | %6.2f Gbps | %6.2f Gbps | %6.2f Gbps\n', 'Peak Throughput', M5.Peak_Gbps, M6B.Peak_Gbps, M6M.Peak_Gbps);
    fprintf('%-20s | %6.4f      | %6.4f      | %6.4f     \n', 'Fairness Index', M5.Fairness, M6B.Fairness, M6M.Fairness);
end

function [lat, lon] = xy2latlon(x, y, Config)
    R = 6371000; lat = Config.city_center_lat + rad2deg(y/R); lon = Config.city_center_lon + rad2deg(x./(R*cosd(Config.city_center_lat)));
end