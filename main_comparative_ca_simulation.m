% % =========================================================================
% % MAIN_COMPARATIVE_CA_SIMULATION
% % Paper: The Spatial Fairness Penalty of 5G Carrier Aggregation
% % Objective: Compare 400 MHz (Single Carrier) vs. 800 MHz (2CC CA) 
% % Demonstrating the "Digital Divide" in Tripoli's Urban Topology
% % =========================================================================
% clc; clear; close all;
% fprintf('--- Starting 5G Carrier Aggregation Comparative Study ---\n');
% rng(97); % Reproducibility
% 
% % --- 1. Define Comparative Scenarios ---
% BW_scenarios = [400e6, 800e6];
% scenario_names = {'400 MHz (Single Carrier)', '800 MHz (2CC CA)'};
% colors = {[0, 0.4470, 0.7410], [0.850, 0.325, 0.098]}; % Standard IEEE Blue & Orange
% Results_Storage = cell(length(BW_scenarios), 1);
% Metrics_Storage = cell(length(BW_scenarios), 1);
% 
% % Base Configuration
% Base_Config = initialize_enhanced_mmwave_config();
% Base_Config.optimization.cre_offset_dB = 18; 
% 
% % Generate the Network and UEs ONCE to guarantee fair comparison
% [Network, UEs] = generate_hetnet_assets(Base_Config);
% 
% % --- 2. Execute Outer Loop Simulation ---
% for i = 1:length(BW_scenarios)
%     fprintf('\n======================================================\n');
%     fprintf(' Executing Scenario %d: %s\n', i, scenario_names{i});
%     fprintf('======================================================\n');
% 
%     Current_Config = Base_Config;
%     Current_Config.system.bandwidth_Hz = BW_scenarios(i);
% 
%     % Update the specific layer bandwidth used in throughput calculation
%     Current_Config.NetworkLayers{2}.bw_MHz = BW_scenarios(i) / 1e6;
% 
%     Current_Config.system.noise_figure_dB = 9; 
%     Current_Config.system.thermal_noise_dBm = -174 + 10*log10(BW_scenarios(i)) + Current_Config.system.noise_figure_dB;
% 
%     % Pass 3 inputs and expect 1 output
%     Results = run_hetnet_simulation(Current_Config, Network, UEs);
% 
%     % Store Results
%     Results_Storage{i} = Results;
% 
%     % Calculate Metrics
%     tput_mbps = Results.UE.throughput_mbps;
%     M.Avg_Gbps = mean(tput_mbps) / 1000;
%     M.Peak_Gbps = max(tput_mbps) / 1000;
%     M.Edge_Mbps = prctile(tput_mbps, 5);
%     M.Fairness = (sum(tput_mbps)^2) / (length(tput_mbps) * sum(tput_mbps.^2));
%     Metrics_Storage{i} = M;
% 
%     fprintf('  > Avg Tput: %.2f Gbps | Edge: %.2f Mbps | Fairness: %.4f\n', ...
%             M.Avg_Gbps, M.Edge_Mbps, M.Fairness);
% end
% 
% % Extract Data for plotting
% tput_400_gbps = Results_Storage{1}.UE.throughput_mbps / 1000;
% tput_800_gbps = Results_Storage{2}.UE.throughput_mbps / 1000;
% dist_km = sqrt(Results_Storage{1}.UE.x_col.^2 + Results_Storage{1}.UE.y_col.^2) / 1000;
% 
% % =========================================================================
% % --- 3. IEEE FORMATTED VISUALIZATIONS ---
% % =========================================================================
% fprintf('\n--- Generating IEEE Comparative Figures ---\n');
% 
% % Helper Function for strict IEEE Box/Font formatting
% format_ieee_axis = @(ax) set(ax, 'Box', 'on', 'Color', 'w', 'XGrid', 'on', 'YGrid', 'on', ...
%     'GridLineStyle', ':', 'LineWidth', 1.0, 'FontName', 'Times New Roman', 'FontSize', 11);
% 
% % FIG 1: CDF Comparison
% figure('Name', 'CDF Throughput Comparison', 'Color', 'w', 'Position', [100, 100, 600, 450]);
% hold on; 
% h1 = cdfplot(tput_400_gbps); set(h1, 'Color', colors{1}, 'LineWidth', 2.5, 'LineStyle', '-');
% h2 = cdfplot(tput_800_gbps); set(h2, 'Color', colors{2}, 'LineWidth', 2.5, 'LineStyle', '--');
% xlabel('User Throughput (Gbps)', 'FontWeight', 'bold'); ylabel('Cumulative Distribution Function (CDF)', 'FontWeight', 'bold');
% title(''); 
% legend(scenario_names, 'Location', 'southeast', 'FontName', 'Times New Roman');
% xlim([0 max(tput_800_gbps)+0.5]); ylim([0 1.05]);
% format_ieee_axis(gca);
% 
% % FIG 2: Bar Chart Comparison
% figure('Name', 'Key Metrics Comparison', 'Color', 'w', 'Position', [150, 150, 600, 400]);
% vals = [Metrics_Storage{1}.Avg_Gbps, Metrics_Storage{2}.Avg_Gbps; ...
%         Metrics_Storage{1}.Edge_Mbps/1000, Metrics_Storage{2}.Edge_Mbps/1000; ...
%         Metrics_Storage{1}.Peak_Gbps, Metrics_Storage{2}.Peak_Gbps];
% b = bar(vals, 'grouped');
% b(1).FaceColor = colors{1}; b(2).FaceColor = colors{2};
% xticklabels({'Average Tput', 'Cell Edge Tput', 'Peak Tput'});
% xlabel('Performance Metrics', 'FontWeight', 'bold');
% ylabel('Throughput (Gbps)', 'FontWeight', 'bold'); title('');
% legend(scenario_names, 'Location', 'northwest', 'FontName', 'Times New Roman');
% format_ieee_axis(gca);
% 
% % FIG 3: Throughput vs Distance Scatter Plot
% figure('Name', 'Distance vs Throughput', 'Color', 'w', 'Position', [250, 250, 700, 500]);
% hold on;
% scatter(dist_km, tput_400_gbps, 30, colors{1}, 'o', 'filled', 'MarkerFaceAlpha', 0.5);
% scatter(dist_km, tput_800_gbps, 30, colors{2}, '^', 'filled', 'MarkerFaceAlpha', 0.7);
% xlabel('Distance from City Center (km)', 'FontWeight', 'bold');
% ylabel('User Throughput (Gbps)', 'FontWeight', 'bold');
% legend({'400 MHz (Indoor/Edge Constrained)', '800 MHz (Outdoor/LOS Amplified)'}, 'Location', 'northeast', 'FontName', 'Times New Roman');
% format_ieee_axis(gca);
% 
% % FIG 4: Geographic Delta Map (Capacity Gain)
% figure('Name', 'Spatial Capacity Gain Map', 'Color', 'w', 'Position', [300, 300, 800, 600]);
% gx = geoaxes; geobasemap(gx, 'satellite'); hold(gx, 'on');
% 
% delta_tput_gbps = tput_800_gbps - tput_400_gbps;
% 
% % Convert XY to Lat/Lon
% [u_lat, u_lon] = xy2latlon(Results_Storage{1}.UE.x_col, Results_Storage{1}.UE.y_col, Base_Config);
% 
% % Plot Users
% h_users = geoscatter(gx, u_lat, u_lon, 50, delta_tput_gbps, 'filled', 'MarkerFaceAlpha', 0.85);
% colormap(gx, parula); 
% c = colorbar(gx);
% c.Label.String = 'Capacity Gain from 800 MHz Upgrade (Gbps)';
% c.Label.FontWeight = 'bold';
% c.Label.FontName = 'Times New Roman';
% 
% % Plot Towers
% m_idx = Network.gNodeBs.layer_id_row == 1;
% s_idx = Network.gNodeBs.layer_id_row == 2;
% h_macro = geoscatter(gx, Network.gNodeBs.lat(m_idx), Network.gNodeBs.lon(m_idx), 150, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
% h_small = geoscatter(gx, Network.gNodeBs.lat(s_idx), Network.gNodeBs.lon(s_idx), 80, 'c', 's', 'filled', 'MarkerEdgeColor', 'k');
% 
% geolimits(gx, Base_Config.lat_bounds, Base_Config.lon_bounds);
% title(''); 
% set(gx, 'FontName', 'Times New Roman', 'FontSize', 11);
% 
% % Add Description Box (Legend)
% legend(gx, [h_users, h_macro, h_small], {'Capacity Gain (Users)', 'Macro Base Station', 'Small Cell'}, 'Location', 'northeast', 'FontName', 'Times New Roman');
% 
% % =========================================================================
% % --- 4. COMMAND WINDOW METRICS TABLE ---
% % =========================================================================
% fprintf('\n======================================================================\n');
% fprintf('          400 MHz vs. 800 MHz CARRIER AGGREGATION COMPARISON         \n');
% fprintf('======================================================================\n');
% fprintf('%-20s | %-15s | %-15s\n', 'Metric', '400 MHz (SC)', '800 MHz (2CC)');
% fprintf('----------------------------------------------------------------------\n');
% fprintf('%-20s | %6.2f Gbps    | %6.2f Gbps\n', 'Avg Throughput', Metrics_Storage{1}.Avg_Gbps, Metrics_Storage{2}.Avg_Gbps);
% fprintf('%-20s | %6.2f Mbps    | %6.2f Mbps\n', 'Cell Edge (5%)', Metrics_Storage{1}.Edge_Mbps, Metrics_Storage{2}.Edge_Mbps);
% fprintf('%-20s | %6.2f Gbps    | %6.2f Gbps\n', 'Peak Throughput', Metrics_Storage{1}.Peak_Gbps, Metrics_Storage{2}.Peak_Gbps);
% fprintf('%-20s | %6.4f         | %6.4f\n', 'Fairness Index', Metrics_Storage{1}.Fairness, Metrics_Storage{2}.Fairness);
% fprintf('======================================================================\n');
% 
% fprintf('--- Complete. Data successfully generated for IEEE submission. ---\n');

% =========================================================================
% MAIN_COMPARATIVE_CA_SIMULATION (MONTE CARLO VERSION)
% Paper: The Spatial Fairness Penalty of 5G Carrier Aggregation
% =========================================================================
clc; clear; close all;
fprintf('--- Starting 5G Carrier Aggregation Monte Carlo Study ---\n');

% --- 1. Define Comparative Scenarios ---
BW_scenarios = [400e6, 800e6];
scenario_names = {'400 MHz (Single Carrier)', '800 MHz (2CC CA)'};
colors = {[0, 0.4470, 0.7410], [0.850, 0.325, 0.098]};

num_drops = 20; % SET TO 20 FOR FINAL PAPER, SET TO 2 FOR QUICK TESTING

% Matrices to store metrics across all drops
% Rows = Drops, Columns = Scenarios (1=400MHz, 2=800MHz)
Drop_Avg_Tput = zeros(num_drops, 2);
Drop_Edge_Tput = zeros(num_drops, 2);
Drop_Peak_Tput = zeros(num_drops, 2);
Drop_Fairness = zeros(num_drops, 2);

Base_Config = initialize_enhanced_mmwave_config();
Base_Config.optimization.cre_offset_dB = 18; 

% --- 2. Execute Outer Monte Carlo Loop ---
for drop = 1:num_drops
    fprintf('\n******************************************************\n');
    fprintf(' Executing Monte Carlo Drop %d of %d\n', drop, num_drops);
    fprintf('******************************************************\n');
    
    % Generate NEW random users for this specific drop
    % (But keep the base stations in the same place)
    rng(drop); % Change random seed for each drop
    [Network, UEs] = generate_hetnet_assets(Base_Config);

    % --- 3. Execute Inner Bandwidth Loop ---
    for i = 1:length(BW_scenarios)
        Current_Config = Base_Config;
        Current_Config.system.bandwidth_Hz = BW_scenarios(i);
        Current_Config.NetworkLayers{2}.bw_MHz = BW_scenarios(i) / 1e6;
        Current_Config.system.noise_figure_dB = 9; 
        Current_Config.system.thermal_noise_dBm = -174 + 10*log10(BW_scenarios(i)) + Current_Config.system.noise_figure_dB;
        
        % Run Engine (Suppressing text output to keep command window clean)
        evalc('Results = run_hetnet_simulation(Current_Config, Network, UEs);');
        
        % Calculate and Store Metrics for this Drop/Scenario
        tput_mbps = Results.UE.throughput_mbps;
        Drop_Avg_Tput(drop, i) = mean(tput_mbps) / 1000;
        Drop_Edge_Tput(drop, i) = prctile(tput_mbps, 5);
        Drop_Peak_Tput(drop, i) = max(tput_mbps) / 1000;
        Drop_Fairness(drop, i) = (sum(tput_mbps)^2) / (length(tput_mbps) * sum(tput_mbps.^2));
        
        % Save the last drop's results to generate the final plots
        if drop == num_drops
            Results_Storage{i} = Results;
        end
    end
    fprintf('  Drop %d Complete. Fairness (400MHz): %.4f | Fairness (800MHz): %.4f\n', ...
        drop, Drop_Fairness(drop, 1), Drop_Fairness(drop, 2));
end

% --- 4. Calculate Final Ensemble Averages and Margin of Error ---
Final_Avg_Tput = mean(Drop_Avg_Tput);
Final_Edge_Tput = mean(Drop_Edge_Tput);
Final_Peak_Tput = mean(Drop_Peak_Tput);
Final_Fairness = mean(Drop_Fairness);

% Calculate Margin of Error for Fairness (95% Confidence Interval)
std_fairness = std(Drop_Fairness);
moe_fairness = 1.96 * (std_fairness ./ sqrt(num_drops));

% =========================================================================
% --- 5. COMMAND WINDOW METRICS TABLE ---
% =========================================================================
fprintf('\n======================================================================\n');
fprintf('     FINAL ENSEMBLE AVERAGES (N = %d DROPS)     \n', num_drops);
fprintf('======================================================================\n');
fprintf('%-20s | %-15s | %-15s\n', 'Metric', '400 MHz (SC)', '800 MHz (2CC)');
fprintf('----------------------------------------------------------------------\n');
fprintf('%-20s | %6.2f Gbps    | %6.2f Gbps\n', 'Avg Throughput', Final_Avg_Tput(1), Final_Avg_Tput(2));
fprintf('%-20s | %6.2f Mbps    | %6.2f Mbps\n', 'Cell Edge (5%)', Final_Edge_Tput(1), Final_Edge_Tput(2));
fprintf('%-20s | %6.2f Gbps    | %6.2f Gbps\n', 'Peak Throughput', Final_Peak_Tput(1), Final_Peak_Tput(2));
fprintf('%-20s | %6.4f ±%.3f | %6.4f ±%.3f\n', 'Fairness Index', Final_Fairness(1), moe_fairness(1), Final_Fairness(2), moe_fairness(2));
fprintf('======================================================================\n');

% =========================================================================
% --- 6. GENERATE ALL FIGURES (FOR IEEE PAPER) ---
% =========================================================================
fprintf('\nGenerating Figures...\n');

% Extract the final drop data for spatial plots
UE_x = Results_Storage{1}.UE.x_col;
UE_y = Results_Storage{1}.UE.y_col;
Tput_400 = Results_Storage{1}.UE.throughput_mbps;
Tput_800 = Results_Storage{2}.UE.throughput_mbps;

% --- Figure 1: CDF of User Throughput ---
figure('Name', 'Fig 1: CDF of Throughput', 'Position', [100, 100, 600, 450]);
hold on; grid on;
h1 = cdfplot(Tput_400);
set(h1, 'Color', colors{1}, 'LineWidth', 2);
h2 = cdfplot(Tput_800);
set(h2, 'Color', colors{2}, 'LineWidth', 2);
title('CDF of User Throughput', 'FontName', 'Times New Roman');
xlabel('Throughput (Mbps)', 'FontName', 'Times New Roman');
ylabel('Cumulative Probability', 'FontName', 'Times New Roman');
legend(scenario_names, 'Location', 'southeast', 'FontName', 'Times New Roman');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 11);
xlim([0, 1500]); % Focus on where the divergence happens

% --- Figure 2: Bar Chart (Using Ensemble Averages) ---
figure('Name', 'Fig 2: Performance Metrics', 'Position', [150, 150, 600, 450]);
% Convert to Gbps for the bar chart
bar_data = [Final_Avg_Tput(1), Final_Avg_Tput(2); 
            (Final_Edge_Tput(1)/1000), (Final_Edge_Tput(2)/1000); 
            Final_Peak_Tput(1), Final_Peak_Tput(2)];

b = bar(bar_data, 'grouped');
b(1).FaceColor = colors{1};
b(2).FaceColor = colors{2};
grid on;
title('Network Performance Metrics', 'FontName', 'Times New Roman');
ylabel('Throughput (Gbps)', 'FontName', 'Times New Roman');
set(gca, 'XTickLabel', {'Average', 'Cell Edge (5%)', 'Peak'}, 'FontName', 'Times New Roman', 'FontSize', 11);
legend(scenario_names, 'Location', 'northwest', 'FontName', 'Times New Roman');

% --- Figure 3: Scatter Plot (Throughput vs Distance) ---
% Calculate roughly distance from center of map
center_x = mean(UE_x);
center_y = mean(UE_y);
dist_from_center = sqrt((UE_x - center_x).^2 + (UE_y - center_y).^2);

figure('Name', 'Fig 3: Spatial Fairness Scatter', 'Position', [200, 200, 600, 450]);
hold on; grid on;
scatter(dist_from_center, Tput_400, 15, colors{1}, 'filled', 'MarkerFaceAlpha', 0.6);
scatter(dist_from_center, Tput_800, 15, colors{2}, 'filled', 'MarkerFaceAlpha', 0.6);
title('User Throughput vs. Distance from City Center', 'FontName', 'Times New Roman');
xlabel('Distance from City Center (m)', 'FontName', 'Times New Roman');
ylabel('Throughput (Mbps)', 'FontName', 'Times New Roman');
legend(scenario_names, 'Location', 'northeast', 'FontName', 'Times New Roman');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 11);

% --- Figure 4: Spatial Capacity Gain Map (SATELLITE BACKGROUND) ---
fprintf('Generating Satellite Map...\n');

% 1. Extract Data
Tput_Gain_Gbps = (Tput_800 - Tput_400) / 1000; 
UE_x = Results_Storage{1}.UE.x_col;
UE_y = Results_Storage{1}.UE.y_col;

% 2. Convert local X/Y coordinates back to Latitude and Longitude
earth_R = 6371000;
lat_center = Base_Config.city_center_lat;
lon_center = Base_Config.city_center_lon;

u_lat = lat_center + (UE_y / earth_R) * (180/pi);
u_lon = lon_center + (UE_x ./ (earth_R * cosd(lat_center))) * (180/pi);

m_idx = Network.gNodeBs.layer_id_row == 1;
s_idx = Network.gNodeBs.layer_id_row == 2;
m_lat = lat_center + (Network.gNodeBs.y_row(m_idx) / earth_R) * (180/pi);
m_lon = lon_center + (Network.gNodeBs.x_row(m_idx) ./ (earth_R * cosd(lat_center))) * (180/pi);
s_lat = lat_center + (Network.gNodeBs.y_row(s_idx) / earth_R) * (180/pi);
s_lon = lon_center + (Network.gNodeBs.x_row(s_idx) ./ (earth_R * cosd(lat_center))) * (180/pi);

% 3. Plotting with Geographic Axes
figure('Name', 'Fig 4: Capacity Gain Map', 'Position', [250, 250, 800, 600]);
gx = geoaxes;
geobasemap(gx, 'satellite');
hold(gx, 'on');

% Plot elements
h_users = geoscatter(gx, u_lat, u_lon, 25, Tput_Gain_Gbps, 'filled', 'MarkerFaceAlpha', 0.9);
h_macro = geoscatter(gx, m_lat, m_lon, 120, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
h_small = geoscatter(gx, s_lat, s_lon, 50, 'c', 's', 'filled', 'MarkerEdgeColor', 'k');

% Formatting
colormap(gx, 'parula');
cb = colorbar(gx);
cb.Label.String = 'Capacity Gain from 800 MHz Upgrade (Gbps)';
cb.Label.FontName = 'Times New Roman';
geolimits(gx, Base_Config.lat_bounds, Base_Config.lon_bounds);
legend(gx, [h_users, h_macro, h_small], {'Capacity Gain (Users)', 'Macro Base Station', 'Small Cell'}, 'Location', 'northeast', 'FontName', 'Times New Roman');
set(gx, 'FontName', 'Times New Roman', 'FontSize', 11);
fprintf('Done! All figures generated successfully.\n');