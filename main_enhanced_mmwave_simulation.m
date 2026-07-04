% MAIN_ENHANCED_MMWAVE_SIMULATION
% Orchestrates the "Enhanced" Scenario (CSO + Interference Rejection).

clc; clear; close all;

fprintf('==================================================\n');
fprintf('   STARTING ENHANCED SIMULATION (Optimized 5G)    \n');
fprintf('==================================================\n');

% 1. Load Config (Enhanced Settings: CSO=6dB, Rejection=3dB)
Config = initialize_enhanced_mmwave_config();
Config.scenario_name = 'Enhanced 5G';

% 2. Generate Assets
[Network, UEs] = generate_hetnet_assets(Config);

% 3. Run Simulation (USING REAL PHYSICS ENGINE)
Results = run_hetnet_simulation(Config, Network, UEs);

% 4. Save Results
Results.Config = Config;
Results.Network = Network; 
save('Results_Enhanced.mat', 'Results', 'Network', 'UEs', 'Config');
fprintf('>> Enhanced Results saved to Results_Enhanced.mat\n');

% 5. Display Summary
display_summary_results(Results);