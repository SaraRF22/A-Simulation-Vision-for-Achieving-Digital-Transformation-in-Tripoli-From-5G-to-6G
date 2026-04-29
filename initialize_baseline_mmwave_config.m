function Config = initialize_baseline_mmwave_config()
% INITIALIZE_BASELINE_MMWAVE_CONFIG 
% Updated: Includes GIS Fix AND Scenario Name to prevent errors.

    fprintf('Loading Baseline Configuration...\n');
    Config = struct();
    
    % --- 0. Scenario Identity (FIXED) ---
    Config.scenario_name = 'Baseline (Standard 5G)';
    
    % --- 1. Simulation Control ---
    Config.simulation_time_s = 60;
    Config.time_step_s = 0.001;
    Config.enable_plotting = true;
    Config.slicing_enabled = true;
    
    % --- 2. Geographic Parameters ---
    Config.city_center_lat = 32.8872;  
    Config.city_center_lon = 13.1913;
    Config.earth_radius_m = 6371000;
    Config.radius_urban_km = 6.0;    
    Config.radius_suburban_km = 18.0; 
    Config.lat_bounds = [32.72, 33.05]; 
    Config.lon_bounds = [13.00, 13.38];

    % [FIX] Use relative path (looks in current folder)
    % Ensure 'eara.shp', 'eara.shx', and 'eara.dbf' are in the same folder!
    Config.shapefile_path = 'C:\Users\Sara RF\Documents\MATLAB\Examples\R2024a\nrx5g\GetStartedWith6GExplorationLibraryExample\My_Thesis_Simulations\Small Selection mmWave 28GHz\T.MAP\eara.shp'; 

    % --- 3. Optimization Factors (OFF for Baseline) ---
    Config.small_cell_offset_dB = 0;       
    Config.cso_sll_rejection_dB = 0;       

    % --- 4. Network Layers ---
    Config.NetworkLayers = {
        % Layer 1: Macro
        struct('type', 'Macro', 'freq_GHz', 3.5, 'bw_MHz', 100, 'tx_power_dBm', 46, ...
               'site_density', [3.0, 0.8, 0.0], ... 
               'height_m', 30, 'sectors', 3, 'antenna_type', 'Conventional'),

        % Layer 2: Small Cell
        struct('type', 'SmallCell', 'freq_GHz', 28, 'bw_MHz', 800, 'tx_power_dBm', 35, ...
               'site_density', [8.0, 1.5, 0.0], ... 
               'height_m', 10, 'sectors', 1, 'antenna_type', 'Conventional')
    };

    % --- 5. Antenna Models ---
    Config.Antenna.Conventional = struct('max_gain_dBi', 18, 'theta_3db', 65, 'front_to_back', 25);
    
    % --- 6. User (UE) Configuration ---
   
    Config.ues_per_sector = 1;        % Simulating peak capacity / light load
    Config.ue_pop_density = [];       
    Config.ue_height_m = 1.5;          
    Config.max_ue_speed_ms = 15;       
    Config.indoor_user_percentage = 0.7; % KEEP THIS: 70% of traffic is indoor
    
    % --- 7. Channel ---
    Config.noise_figure_dB = 9;
    Config.Temperature_K = 290;
    Config.k_Boltzmann = 1.380649e-23;
    Config.building_penetration_loss_dB = 20;
    Config.slices = {struct('name', 'eMBB', 'proportion', 0.6, 'req_mbps', 50, 'priority', 1)};
    Config.dBm_to_W = @(dBm) 10.^((dBm - 30)/10);
end