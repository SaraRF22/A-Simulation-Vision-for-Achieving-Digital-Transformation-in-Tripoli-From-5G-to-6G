function display_summary_results(Results)
% DISPLAY_SUMMARY_RESULTS
% Calculates and prints the Final Simulation Summary box.
% UPDATED: UE Throughput displayed in Gbps, includes Peak 95th Percentile.

    % --- 1. Calculate Metrics ---
    
    % A. Network Throughput
    avg_net_tput_mbps = mean(Results.aggregate.net_throughput_mbps, 'omitnan');
    avg_net_tput_tbps = avg_net_tput_mbps / 1e6; % Convert to Tbps
    
    % B. UE Throughput (Average)
    avg_ue_tput_mbps = mean(Results.UE.throughput_mbps, 'omitnan');
    avg_ue_tput_gbps = avg_ue_tput_mbps / 1000; % Convert to Gbps
    
    % C. UE Throughput (PEAK 95th Percentile)
    peak_ue_tput_mbps = prctile(Results.UE.throughput_mbps, 95);
    peak_ue_tput_gbps = peak_ue_tput_mbps / 1000; % Convert to Gbps
    
    % D. Average SINR
    avg_sinr_db = mean(Results.aggregate.avg_sinr_dB, 'omitnan');
    
    % E. Average Spectral Efficiency (bps/Hz)
    if isfield(Results.UE, 'spectral_efficiency')
        avg_se = mean(Results.UE.spectral_efficiency, 'omitnan');
    else
        sinr_lin = 10.^(Results.UE.sinr_dB ./ 10);
        avg_se = mean(log2(1 + sinr_lin), 'omitnan');
    end

    % --- 2. Print Summary Box ---
    fprintf('\n=============================================================\n');
    fprintf('              FINAL SIMULATION SUMMARY\n');
    fprintf('=============================================================\n');
    fprintf('1- Total Network Throughput   : %.4f Tbps\n', avg_net_tput_tbps);
    fprintf('2- Average UE Throughput      : %.4f Gbps\n', avg_ue_tput_gbps);
    fprintf('3- PEAK UE Throughput (95%%)   : %.4f Gbps\n', peak_ue_tput_gbps);
    fprintf('4- Average Network SINR       : %.2f dB\n', avg_sinr_db);
    fprintf('5- Average Spectral Efficiency: %.2f bps/Hz\n', avg_se);
    fprintf('=============================================================\n');
end