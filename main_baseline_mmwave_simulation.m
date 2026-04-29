% MAIN_BASELINE_MMWAVE_SIMULATION
% Orchestrates the "Control" Scenario for M.Sc. Thesis.

clc; clear; close all;

fprintf('==================================================\n');
fprintf('   STARTING BASELINE SIMULATION (Control Group)   \n');
fprintf('==================================================\n');

% 1. Load Config (Metropolitan Zoning)
Config = initialize_baseline_mmwave_config();

% 2. Generate Assets
[Network, UEs] = generate_hetnet_assets(Config);

% 3. Show "Real" Deployment Map
if Config.enable_plotting
    fprintf('Displaying Deployment Map...\n');
    plot_geographic_heatmap(Network, UEs, Config);
    drawnow;
end

% 4. Run Simulation
Results = run_hetnet_simulation(Config, Network, UEs);

% 5. Save Results
Results.Config = Config;
Results.Network = Network; 
timestamp = datestr(now, 'yyyy_mm_dd_HHMM');
save('Results_Baseline.mat', 'Results', 'Network', 'UEs', 'Config');
fprintf('>> Baseline Results saved to Results_Baseline.mat\n');

% 6. DISPLAY SUMMARY
display_summary_results(Results);