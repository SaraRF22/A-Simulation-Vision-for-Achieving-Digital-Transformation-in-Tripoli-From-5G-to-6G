% =========================================================================
% EXTRA 6G THESIS METRICS: Energy Efficiency & Outage Probability
% Run this directly after your main 6G script finishes.
% =========================================================================
fprintf('\n--- Calculating Advanced 6G Thesis Metrics ---\n');

% 1. ENERGY EFFICIENCY (Mbps per Watt)
% Estimate 5G Power: Macro (1000W) + Small Cells (100W each)
num_macros = sum(Network.gNodeBs.layer_id_row == 1);
num_small_cells = sum(Network.gNodeBs.layer_id_row == 2);
Total_Power_5G_W = (num_macros * 1000) + (num_small_cells * 100);

% Estimate 6G Power: Macro (1000W) + RIS Panels (Passive, ~5W each)
Total_Power_6G_W = (num_macros * 1000) + (Actual_RIS_Count * 5);

% Calculate EE (Network Throughput Mbps / Total Power Watts)
EE_5G = sum(Results_5G.UE.throughput_mbps) / Total_Power_5G_W;
EE_6G = sum(Results_6G_Advanced.UE.throughput_mbps) / Total_Power_6G_W;

% 2. OUTAGE PROBABILITY
% Define the minimum acceptable speed for a "Smart City" (e.g., 50 Mbps)
Outage_Threshold_Mbps = 50.0;
Outage_5G_pct = (sum(Results_5G.UE.throughput_mbps < Outage_Threshold_Mbps) / num_users) * 100;
Outage_6G_pct = (sum(Results_6G_Advanced.UE.throughput_mbps < Outage_Threshold_Mbps) / num_users) * 100;

% --- PRINT NEW TABLE ---
fprintf('=========================================================\n');
fprintf('        SECONDARY RESULTS: EFFICIENCY & RELIABILITY      \n');
fprintf('=========================================================\n');
fprintf('%-22s | %-12s | %-12s\n', 'Metric', '5G Enhanced', '6G Adv (RIS)');
fprintf('---------------------------------------------------------\n');
fprintf('%-22s | %6.2f %s | %6.2f %s\n', 'Energy Efficiency', EE_5G, 'Mbps/W', EE_6G, 'Mbps/W');
fprintf('%-22s | %6.2f %%     | %6.2f %%\n', 'Outage Rate (<50 Mbps)', Outage_5G_pct, Outage_6G_pct);
fprintf('=========================================================\n');
fprintf('Thesis Argument: RIS achieves %0.1fx the Energy Efficiency of active 5G cells.\n', EE_6G / EE_5G);