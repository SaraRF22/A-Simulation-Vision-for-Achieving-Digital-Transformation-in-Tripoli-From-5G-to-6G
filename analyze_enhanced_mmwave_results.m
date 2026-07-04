function analyze_enhanced_mmwave_results()
% ANALYZE_ENHANCED_MMWAVE_RESULTS
% 1. Prints Zone-Specific Stats (Urban/Suburban/Rural).
% 2. Plots Standard CDF/Scatter charts (Original Style).
% 3. Plots Realistic Satellite Heatmap (Unified Map).

    clc; close all;
    fprintf('==================================================\n');
    fprintf('   ANALYZING ENHANCED SCENARIO RESULTS            \n');
    fprintf('==================================================\n');

    % --- 1. Load Latest Results ---
    files = dir('Results_Enhanced_*.mat');
    if isempty(files)
        if exist('Results_Enhanced.mat', 'file')
            load('Results_Enhanced.mat');
        else
            error('No Results_Enhanced.mat found. Run simulation first.');
        end
    else
        [~, idx] = sort([files.datenum], 'descend');
        load(files(idx(1)).name);
    end

    % Unpack
    UE_x = Results.UE.x_col;
    UE_y = Results.UE.y_col;
    SINR = Results.UE.sinr_dB;
    TPut = Results.UE.throughput_mbps;
    Config = Results.Config;

    % --- 2. Zone-Based Statistics (Separated Analysis) ---
    fprintf('\n--- ZONE PERFORMANCE (Separated Analysis) ---\n');
    dists_km = sqrt(UE_x.^2 + UE_y.^2) / 1000;
    
    idx_urban = dists_km <= 6.0;
    idx_suburban = (dists_km > 6.0) & (dists_km <= 18.0);
    idx_rural = dists_km > 18.0;
    
    print_stats('URBAN (0-6km)', idx_urban, SINR, TPut);
    print_stats('SUBURBAN (6-18km)', idx_suburban, SINR, TPut);
    print_stats('RURAL (>18km)', idx_rural, SINR, TPut);

    % --- 3. Standard Plots (Original Style) ---
    % These plots use standard figure windows, not maps, 
    % preserving the style of your original code.
    figure('Name', 'Statistical Analysis', 'Color', 'w');
    
    subplot(2,1,1);
    cdfplot(SINR);
    title('SINR Distribution (Global)');
    xlabel('SINR (dB)'); ylabel('Probability'); grid on;
    
    subplot(2,1,2);
    scatter(dists_km, TPut, 10, 'filled', 'MarkerFaceAlpha', 0.4);
    title('Throughput vs Distance from Center');
    xlabel('Distance (km)'); ylabel('Throughput (Mbps)'); grid on;
    xline(6, 'r--', 'Urban'); xline(18, 'g--', 'Suburban');

    % --- 4. REALISTIC SATELLITE HEATMAP (Unified Map) ---
    % This is the "Real" map showing the entire Tripoli area
    figure('Name', 'SINR Coverage Map - Tripoli', 'Color', 'w', 'Position', [100, 100, 1000, 800]);
    gx = geoaxes;
    geobasemap(gx, 'satellite'); % Real satellite background
    hold(gx, 'on');

    % Convert UE XY to Lat/Lon
    [ue_lat, ue_lon] = xy2latlon(UE_x, UE_y, Config);

    % Plot Heatmap Points
    geoscatter(gx, ue_lat, ue_lon, 15, SINR, 'filled', 'MarkerFaceAlpha', 0.6);
    
    % Add Colorbar
    c = colorbar;
    c.Label.String = 'SINR (dB)';
    caxis(gx, [-5 30]); 
    colormap(gx, 'jet');
    
    % Plot Base Stations (Context)
    geoscatter(gx, Results.Network.gNodeBs.lat, Results.Network.gNodeBs.lon, ...
        10, 'k', 'filled', 'MarkerFaceAlpha', 0.3);

    % Formatting
    title({'SINR Coverage Heatmap', 'Entire Tripoli Area'});
    geolimits(gx, Config.lat_bounds, Config.lon_bounds);
    
    fprintf('\nAnalysis Complete. Satellite Heatmap generated.\n');
end

function print_stats(name, idx, sinr, tput)
    if sum(idx) > 0
        fprintf('%-20s | Users: %d | Avg SINR: %.1f dB | Avg Tput: %.1f Mbps\n', ...
            name, sum(idx), mean(sinr(idx)), mean(tput(idx)));
    end
end

function [lat, lon] = xy2latlon(x, y, Config)
    lat = Config.city_center_lat + (y / 111320);
    lon = Config.city_center_lon + (x ./ (111320 * cosd(Config.city_center_lat)));
end