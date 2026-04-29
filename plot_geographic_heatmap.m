function plot_geographic_heatmap(Network, UEs, Config)
% PLOT_GEOGRAPHIC_HEATMAP
% Visualizes the network assets on a REAL SATELLITE MAP of Tripoli.
% Features:
% - Single unified map for Urban, Suburban, and Rural.
% - Satellite background for realism.
% - Visualizes the 6km and 18km zone boundaries.

    % Create Figure with Geographic Axes
    figure('Name', 'Network Deployment - Tripoli', 'Color', 'w', 'Position', [100, 100, 1200, 900]);
    gx = geoaxes;
    hold(gx, 'on');
    
    % --- 1. Set Real Map Background ---
    % 'satellite' gives the realistic photographic look.
    geobasemap(gx, 'satellite'); 

    % --- 2. Plot Zone Boundaries (Visual Guide) ---
    % Urban Circle (6km)
    [lat_u, lon_u] = generate_circle_coords(Config.city_center_lat, Config.city_center_lon, 6.0);
    geoplot(gx, lat_u, lon_u, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Urban Boundary (6km)');
    
    % Suburban Circle (18km)
    [lat_s, lon_s] = generate_circle_coords(Config.city_center_lat, Config.city_center_lon, 18.0);
    geoplot(gx, lat_s, lon_s, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Suburban Boundary (18km)');

    % --- 3. Plot Users (UEs) ---
    % Plot a sample of users to avoid cluttering the map
    step = 1;
    if UEs.num_UEs > 1500, step = 5; end % Downsample for display speed if huge
    
    % Convert Simulation XY to Lat/Lon
    [ue_lat, ue_lon] = xy2latlon(UEs.x_col(1:step:end), UEs.y_col(1:step:end), Config);
    
    geoscatter(gx, ue_lat, ue_lon, 5, [0.9 0.9 0.9], 'filled', ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', 'Users (UEs)');

    % --- 4. Plot Base Stations ---
    % Separate Macro and Small Cells
    is_macro = (Network.gNodeBs.layer_id_row == 1);
    is_small = (Network.gNodeBs.layer_id_row == 2);
    
    % Small Cells (28 GHz) - Blue Dots
    if any(is_small)
        geoscatter(gx, Network.gNodeBs.lat(is_small), Network.gNodeBs.lon(is_small), ...
            25, 'b', 'filled', 'MarkerEdgeColor', 'w', 'DisplayName', 'Small Cells (28 GHz)');
    end
    
    % Macro Cells (3.5 GHz) - Red Triangles
    if any(is_macro)
        geoscatter(gx, Network.gNodeBs.lat(is_macro), Network.gNodeBs.lon(is_macro), ...
            80, 'r', '^', 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'Macro BS (3.5 GHz)');
    end

    % --- 5. Formatting ---
    title({'Network Deployment', 'Greater Tripoli Area (Urban/Suburban/Rural)'}, 'FontSize', 12);
    legend(gx, 'Location', 'best');
    
    % Force view to cover the whole simulated area
    geolimits(gx, Config.lat_bounds, Config.lon_bounds);
    
    drawnow;
end

% --- Helper Functions ---
function [lat, lon] = generate_circle_coords(lat0, lon0, radius_km)
    % Generates lat/lon points for a circle of radius_km
    theta = linspace(0, 360, 100);
    radius_deg = radius_km / 111.32; % Approx conversion
    lat = lat0 + radius_deg * cosd(theta);
    lon = lon0 + radius_deg * sind(theta) / cosd(lat0);
end

function [lat, lon] = xy2latlon(x, y, Config)
    % Inverse of the flat-earth projection used in simulation
    lat = Config.city_center_lat + (y / 111320);
    lon = Config.city_center_lon + (x ./ (111320 * cosd(Config.city_center_lat)));
end