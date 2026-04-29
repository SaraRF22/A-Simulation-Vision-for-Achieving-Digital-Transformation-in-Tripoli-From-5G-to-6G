% GENERATE_TP_VS_SINR_COMPARISON_V2
% Comparison: Linear Tput, Log Tput, and Spectral Efficiency
% Accounts for 5G vs 6G Bandwidth differences defined in README

clc; clear; close all;

% --- 1. Load Data ---
try
    B = load('Results_Baseline.mat');
    E = load('Results_Enhanced.mat');
catch
    error('Missing .mat files. Run main_baseline_mmwave_simulation.m and main_enhanced_mmwave_simulation.m first.');
end

% Create a comprehensive figure
figure('Name', '5G vs 6G Performance Analysis', 'Color', 'w', 'Position', [100, 100, 1500, 500]);

% =========================================================================
% SUBPLOT 1: Raw Throughput (Linear) - "The Magnitude Gap"
% =========================================================================
subplot(1, 3, 1);
hold on; grid on;
scatter(B.Results.UE.sinr_dB, B.Results.UE.throughput_mbps, 15, 'b', 'filled', 'DisplayName', '5G Baseline');
scatter(E.Results.UE.sinr_dB, E.Results.UE.throughput_mbps, 15, 'r', 'filled', 'DisplayName', '6G RIS Enhanced');
xlabel('SINR (dB)');
ylabel('Throughput (Mbps)');
title({'Raw Throughput (Linear)', 'Dominance of 1.2GHz Bandwidth'});
legend('Location', 'northwest');
% Set limit to see the massive 6G peak
ylim([0, max(E.Results.UE.throughput_mbps)*1.1]);

% =========================================================================
% SUBPLOT 2: Raw Throughput (Logarithmic) - "Visibility for 5G"
% =========================================================================
subplot(1, 3, 2);
hold on; grid on;
scatter(B.Results.UE.sinr_dB, B.Results.UE.throughput_mbps, 15, 'b', 'filled', 'DisplayName', '5G Baseline');
scatter(E.Results.UE.sinr_dB, E.Results.UE.throughput_mbps, 15, 'r', 'filled', 'DisplayName', '6G RIS Enhanced');

% KEY FIX: Log Scale allows us to see the 5G curve clearly
set(gca, 'YScale', 'log'); 
xlabel('SINR (dB)');
ylabel('Throughput (Mbps) - Log Scale');
title({'Throughput (Log Scale)', 'Reveals 5G Performance Curve'});
legend('Location', 'northwest');
ylim([10, 20000]); % Ignore noise below 10 Mbps

% =========================================================================
% SUBPLOT 3: Spectral Efficiency - "The Fair Fight"
% =========================================================================
subplot(1, 3, 3);
hold on; grid on;

% Note: If 'spectral_efficiency' is not pre-calculated in your .mat, 
% we calculate it here roughly using the Bandwidths from README.
% 5G Avg BW approx 100-400MHz, 6G BW = 1200MHz.
% Ideally, use the variable B.Results.UE.spectral_efficiency if it exists.

if isfield(B.Results.UE, 'spectral_efficiency')
    b_se = B.Results.UE.spectral_efficiency;
    e_se = E.Results.UE.spectral_efficiency;
else
    % Fallback Calculation (approximate based on README)
    b_se = B.Results.UE.throughput_mbps / 100; % Assuming 100MHz avg for baseline
    e_se = E.Results.UE.throughput_mbps / 1200; % 1.2GHz for 6G
end

scatter(B.Results.UE.sinr_dB, b_se, 20, 'b', 'filled', 'DisplayName', '5G Efficiency');
scatter(E.Results.UE.sinr_dB, e_se, 10, 'r', 'filled', 'DisplayName', '6G Efficiency');

% Theoretical Shannon Limit
sinr_lin = 10.^(-5/10:0.1:35/10); 
shannon = log2(1 + sinr_lin);
plot(10*log10(sinr_lin), shannon, 'k--', 'LineWidth', 2, 'DisplayName', 'Shannon Limit');

xlabel('SINR (dB)');
ylabel('Spectral Efficiency (bps/Hz)');
title({'Spectral Efficiency', 'Normalized by Bandwidth'});
legend('Location', 'best');
ylim([0, 12]);

saveas(gcf, 'Comparison_v2_Log_and_Efficiency.png');