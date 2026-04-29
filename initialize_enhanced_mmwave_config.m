% function Config = initialize_enhanced_mmwave_config()
% % INITIALIZE_ENHANCED_MMWAVE_CONFIG
% % Optimized 5G: Matches User's Thesis/Paper Constraints.
% % Argument: Tripoli topology causes high interference, requiring aggressive
% % CSO optimization (25dB rejection) and aggressive offloading.
% 
%     % 1. Start with Baseline
%     Config = initialize_baseline_mmwave_config();
% 
%     % --- Apply Enhancements ---
%     Config.scenario_name = 'Enhanced (CSO 25dB + CRE)';
% 
%     % 2. Cell Range Expansion (CRE) / Bias
%     % Standard is 6dB. You argued for high offloading.
%     % We set this to 15dB (Very Aggressive). 
%     % Note: If you strictly want 25dB as per your paper, change 15.0 to 25.0,
%     % but be aware this might force users onto very weak signals.
%     Config.small_cell_offset_dB = 8.0; 
% 
%     % 3. CSO Interference Rejection
%     % THESIS ARGUMENT: Tripoli topology causes severe interference.
%     % Your optimizer proves CSO can reduce SLL by ~25dB.
%     % We apply this huge gain here to represent that "cleaner" spectrum.
%     Config.cso_sll_rejection_dB = 25.0; 
% 
%     % 4. Update Antenna Types to "Smart"
%     Config.NetworkLayers{1}.antenna_type = 'Massive MIMO';
%     Config.NetworkLayers{2}.antenna_type = 'Smart Array';
% 
%     fprintf('>> Config Loaded: Enhanced Mode\n');
%     fprintf('   - CSO Interference Rejection: %.1f dB (Thesis Argument)\n', Config.cso_sll_rejection_dB);
%     fprintf('   - Small Cell Offloading Bias: %.1f dB\n', Config.small_cell_offset_dB);
% end

function Config = initialize_enhanced_mmwave_config()
% INITIALIZE_ENHANCED_MMWAVE_CONFIG
% Optimized 5G: Matches User's Thesis/Paper Constraints.
% Argument: Tripoli topology causes high interference, requiring aggressive
% CSO optimization (25dB rejection) and aggressive offloading.

    % 1. Start with Baseline
    Config = initialize_baseline_mmwave_config();
    
    % --- Apply Enhancements ---
    Config.scenario_name = 'Enhanced (CSO 25dB + CRE)';
    
    % 2. Cell Range Expansion (CRE) / Bias
    % Reduced to 5.0 dB to prevent forcing indoor users onto dead 28GHz signals
    Config.small_cell_offset_dB = 18.0; 
    
    % 3. CSO Interference Rejection
    % THESIS ARGUMENT: Tripoli topology causes severe interference.
    % Your optimizer proves CSO can reduce SLL by ~25dB.
    Config.cso_sll_rejection_dB = 25.0; 
    
    % 4. Update Antenna Types to "Smart"
    Config.NetworkLayers{1}.antenna_type = 'Massive MIMO';
    Config.NetworkLayers{2}.antenna_type = 'Smart Array';
    
    % 5. Ensure Small Cells have power and Commercial Bandwidth (800 MHz)
    Config.NetworkLayers{2}.tx_power_dBm = 35;
    Config.NetworkLayers{2}.bw_MHz = 800; % Carrier Aggregation for Gbps speeds
    
    fprintf('>> Config Loaded: Enhanced Mode\n');
    fprintf('   - CSO Interference Rejection: %.1f dB (Thesis Argument)\n', Config.cso_sll_rejection_dB);
    fprintf('   - Small Cell Offloading Bias: %.1f dB\n', Config.small_cell_offset_dB);
end