% % In validate_spectral_efficiency.m
% 
% function validate_spectral_efficiency(Results)
%     % VALIDATE_SPECTRAL_EFFICIENCY Compares simulation results to the Shannon Limit.
% 
%     fprintf('\n--- Validating Spectral Efficiency against Shannon Limit ---\n');
% 
%     sinr_dB_sim = Results.UE.sinr_dB;
%     spec_eff_sim = Results.UE.spectral_efficiency;
% 
%     % Calculate theoretical Shannon capacity
%     sinr_linear_theory = 10.^(-3:0.1:4); % SINR range from -30 dB to 40 dB
%     sinr_dB_theory = 10*log10(sinr_linear_theory);
%     shannon_limit_bps_hz = log2(1 + sinr_linear_theory);
% 
%     fig = figure('Name', 'Spectral Efficiency Validation', 'Position', [200, 200, 800, 600]);
%     hold on; grid on;
% 
%     % Plot the simulation results as a scatter plot
%     scatter(sinr_dB_sim, spec_eff_sim, 'b.', 'DisplayName', 'Simulated UE Performance');
% 
%     % Plot the theoretical Shannon limit
%     plot(sinr_dB_theory, shannon_limit_bps_hz, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Shannon Capacity Limit');
% 
%     % Plot the quantized mapping from your function
%     sinr_levels = -5:0.5:20;
%     se_levels = get_spectral_efficiency_from_sinr(sinr_levels);
%     plot(sinr_levels, se_levels, 'k--', 'LineWidth', 2, 'DisplayName', '3GPP Quantized Mapping');
% 
% 
%     title('Validation: Spectral Efficiency vs. SINR');
%     xlabel('Signal-to-Interference-plus-Noise Ratio (SINR) [dB]');
%     ylabel('Spectral Efficiency (bps/Hz)');
%     legend('show', 'Location', 'northwest');
%     xlim([-10, 30]);
%     ylim([0, 10]);
%     hold off;
% 
%     saveas(fig, '11_SE_Validation_vs_Shannon.png');
% end

% In validate_spectral_efficiency.m

function validate_spectral_efficiency(Results)
    % VALIDATE_SPECTRAL_EFFICIENCY Compares simulation results to the Shannon Limit and 3GPP Specs.

    fprintf('\n--- Validating Spectral Efficiency against Shannon Limit & Real-World Specs ---\n');

    sinr_dB_sim = Results.UE.sinr_dB;
    spec_eff_sim = Results.UE.spectral_efficiency;

    % Calculate theoretical Shannon capacity
    sinr_linear_theory = 10.^(-3:0.1:4); % SINR range from -30 dB to 40 dB
    sinr_dB_theory = 10*log10(sinr_linear_theory);
    shannon_limit_bps_hz = log2(1 + sinr_linear_theory);

    fig = figure('Name', 'Spectral Efficiency Validation', 'Position', [200, 200, 800, 600]);
    hold on; grid on;

    % --- NEW CODE: REAL-WORLD 3GPP EMPIRICAL BOUNDS ---
    
    % FR2 (28 GHz) Expected Range
    % Real-world SINR: -5 to 25 dB | Real-world SE: 1.5 to 8.0 bps/Hz
    fr2_x = [-5, 25, 25, -5];
    fr2_y = [1.5, 1.5, 8.0, 8.0];
    patch(fr2_x, fr2_y, 'red', 'FaceAlpha', 0.05, 'EdgeColor', 'r', 'LineStyle', ':', 'DisplayName', 'Real-World 28GHz Bounds');

    % FR1 (3.5 GHz) Expected Range
    % Real-world SINR: 0 to 22 dB | Real-world SE: 3.0 to 6.5 bps/Hz
    fr1_x = [0, 22, 22, 0];
    fr1_y = [3.0, 3.0, 6.5, 6.5];
    patch(fr1_x, fr1_y, 'blue', 'FaceAlpha', 0.1, 'EdgeColor', 'b', 'LineStyle', '--', 'DisplayName', 'Real-World 3.5GHz Bounds');
    
    % --------------------------------------------------

    % Plot the simulation results as a scatter plot
    scatter(sinr_dB_sim, spec_eff_sim, 'b.', 'DisplayName', 'Simulated UE Performance');

    % Plot the theoretical Shannon limit
    plot(sinr_dB_theory, shannon_limit_bps_hz, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Shannon Capacity Limit');

    % Plot the quantized mapping from your function
    sinr_levels = -5:0.5:20;
    se_levels = get_spectral_efficiency_from_sinr(sinr_levels);
    plot(sinr_levels, se_levels, 'k--', 'LineWidth', 2, 'DisplayName', '3GPP Quantized Mapping');

    title('Validation: Spectral Efficiency vs. SINR');
    xlabel('Signal-to-Interference-plus-Noise Ratio (SINR) [dB]');
    ylabel('Spectral Efficiency (bps/Hz)');
    legend('show', 'Location', 'northwest');
    xlim([-10, 30]);
    ylim([0, 10]);
    hold off;

    % Save as PNG for quick viewing, and EPS for high-quality manuscript rendering
    saveas(fig, '11_SE_Validation_vs_Shannon.png');
    saveas(fig, '11_SE_Validation_vs_Shannon.eps', 'epsc');
end