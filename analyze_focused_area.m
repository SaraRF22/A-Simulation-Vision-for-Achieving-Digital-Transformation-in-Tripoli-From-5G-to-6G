function analyze_focused_area(Results, Config, Network)
% Analyzes and plots a focused cross-section of the simulation results.
% This acts as a "zoomed-in lens" on a specific area like the Old City.

    fprintf('\n--- Generating Focused Lens plots for Tripoli Old City ---\n');

    % --- Define the new, tighter bounds for the "focused lens" area ---
    focused_lat_bounds = [32.895, 32.905];
    focused_lon_bounds = [13.175, 13.195];
    
    scenario_str = strrep(Config.scenario_name, '_', ' ');

    % --- FOCUSED FIGURE 1: Deployment Map ---
    fig_focus_1 = figure('Name', 'Focused Deployment: Old City', 'Position', [100, 100, 800, 700]);
    geobasemap('satellite');
    hold on;
    
    % Find which gNodeBs are inside the focused area
    gnb_indices_in_area = find(Network.gNodeBs.lat >= focused_lat_bounds(1) & Network.gNodeBs.lat <= focused_lat_bounds(2) & ...
                               Network.gNodeBs.lon >= focused_lon_bounds(1) & Network.gNodeBs.lon <= focused_lon_bounds(2));
    
    colors = {'r', 'c'}; markers = {'^', 's'};
    for i = 1:length(Config.NetworkLayers)
        layer = Config.NetworkLayers{i};
        % Find gNodeBs of this layer type that are ALSO in our focused area
        indices_to_plot = intersect(find(Network.gNodeBs.layer_id_row == i), gnb_indices_in_area);
        if isempty(indices_to_plot), continue; end
        
        geoscatter(Network.gNodeBs.lat(indices_to_plot), Network.gNodeBs.lon(indices_to_plot), 120, ...
                   colors{i}, markers{i}, 'filled', ...
                   'DisplayName', [layer.type ' (' num2str(layer.freq_GHz) ' GHz)'], 'MarkerEdgeColor', 'k');
    end
    
    geolimits(focused_lat_bounds, focused_lon_bounds);
    legend('show', 'Location', 'best');
    title(['Focused Deployment (Old City): ' scenario_str], 'FontSize', 14);
    grid off;
    hold off;
    saveas(fig_focus_1, '9_Focused_Deployment_Area.png');


    % --- FOCUSED FIGURE 2: SINR Heatmap ---
    fig_focus_2 = figure('Name', 'Focused SINR: Old City', 'Position', [950, 100, 800, 700]);
    geobasemap('satellite');
    hold on;
    
    % Convert UE final positions to Lat/Lon
    [ue_lat, ue_lon] = xy2latlon(Results.UE.x_col, Results.UE.y_col, Config);
    
    % Find which UEs are inside the focused area
    ue_indices_in_area = find(ue_lat >= focused_lat_bounds(1) & ue_lat <= focused_lat_bounds(2) & ...
                              ue_lon >= focused_lon_bounds(1) & ue_lon <= focused_lon_bounds(2));

    % Plot only the UEs within the focused area
    if ~isempty(ue_indices_in_area)
        geoscatter(ue_lat(ue_indices_in_area), ue_lon(ue_indices_in_area), 50, Results.UE.sinr_dB(ue_indices_in_area), 'filled', 'MarkerFaceAlpha', 0.7);
    end
    
    h = colorbar;
    ylabel(h, 'SINR (dB)');
    colormap('jet');
    
    geolimits(focused_lat_bounds, focused_lon_bounds);
    title(['Focused SINR Heatmap (Old City): ' scenario_str], 'FontSize', 16);
    grid off;
    hold off;
    saveas(fig_focus_2, '10_Focused_SINR_Heatmap.png');

end

function [lat, lon] = xy2latlon(x, y, Config)
% Helper function to convert local Cartesian coordinates back to geographic
    dlat = y / Config.earth_radius_m;
    lat = rad2deg(dlat) + Config.city_center_lat;
    
    dlon = x / (Config.earth_radius_m * cos(deg2rad(Config.city_center_lat)));
    lon = rad2deg(dlon) + Config.city_center_lon;
end