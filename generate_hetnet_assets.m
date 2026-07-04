function [Network, UEs] = generate_hetnet_assets(Config)
% GENERATE_HETNET_ASSETS: Stochastic & Deterministic Geometry Engine
% FIX: Centered Grid generation (Fixes the quadrant clipping bug)
% ENHANCEMENT: Non-Homogeneous spatial modeling for Metro/Suburban zones.

    fprintf('Generating Network Assets (Hexagonal Grid & NHPPP Models)...\n');

    % --- 1. Load Shapefile ---
    if ~exist(Config.shapefile_path, 'file')
        error('CRITICAL ERROR: Shapefile "%s" not found.', Config.shapefile_path);
    end

    coastline = shaperead(Config.shapefile_path);
    if length(coastline) > 1
         combined_lon = [coastline.X]; combined_lat = [coastline.Y];
    else
         combined_lon = coastline.X; combined_lat = coastline.Y;
    end
    
    if max(abs(combined_lon), [], 'omitnan') > 180
        [combined_lat, combined_lon] = utm_zone33n_to_deg(combined_lon, combined_lat);
    end
    Config.coastline_poly.lon = combined_lon; 
    Config.coastline_poly.lat = combined_lat;
    
    % Zoning Boundaries (from original logic)
    r_metro = 6.0;  % km
    r_sub = 18.0;   % km

    all_gNB_lat = []; all_gNB_lon = []; 
    all_height = []; all_layer_id = []; all_freq = []; 
    all_bw = []; all_power = []; all_ant_type = {};

    % --- 2. Generate Base Stations via Spatial Models ---
    for i = 1:length(Config.NetworkLayers)
        layer = Config.NetworkLayers{i};
        
        % Handle Uniform vs. Zoned Densities
        if length(layer.site_density) == 1
            d_metro = layer.site_density(1);
            d_sub = layer.site_density(1);
        else
            d_metro = layer.site_density(1);
            d_sub = layer.site_density(2);
        end
        
        if i == 1 % LAYER 1: MACRO CELLS (Deterministic Hexagonal Grid)
            fprintf('  > Layer 1 (Macro): Multi-Tier Hexagonal Grid...\n');
            
            % Math: Calculate Inter-Site Distances (ISD) from densities
            ISD_m = sqrt(2 * (1 / d_metro) / sqrt(3));
            ISD_s = sqrt(2 * (1 / d_sub) / sqrt(3));
            
            % Generate Metro Grid (-18km to +18km safely covers all)
            dx_m = ISD_m; dy_m = ISD_m * sqrt(3) / 2;
            [X_m, Y_m] = meshgrid(-r_sub:dx_m:r_sub, -r_sub:dy_m:r_sub);
            X_m(2:2:end, :) = X_m(2:2:end, :) + dx_m/2; % Hex offset
            R_m = sqrt(X_m.^2 + Y_m.^2);
            valid_m = R_m <= r_metro; % Keep only points inside 6km
            
            % Generate Suburban Grid
            dx_s = ISD_s; dy_s = ISD_s * sqrt(3) / 2;
            [X_s, Y_s] = meshgrid(-r_sub:dx_s:r_sub, -r_sub:dy_s:r_sub);
            X_s(2:2:end, :) = X_s(2:2:end, :) + dx_s/2; % Hex offset
            R_s = sqrt(X_s.^2 + Y_s.^2);
            valid_s = (R_s > r_metro) & (R_s <= r_sub); % Keep points from 6km to 18km
            
            % Combine and convert to geographic coordinates
            site_x = [X_m(valid_m); X_s(valid_s)] * 1000; % to meters
            site_y = [Y_m(valid_m); Y_s(valid_s)] * 1000;
            [site_lat, site_lon] = xy2latlon(site_x, site_y, Config);
            
        else % LAYER 2: SMALL CELLS (Non-Homogeneous PPP)
            fprintf('  > Layer 2 (Small): Non-Homogeneous PPP...\n');
            
            % Metro PPP (Dense)
            area_m = pi * r_metro^2;
            N_m = poissrnd(d_metro * area_m);
            theta_m = 2 * pi * rand(N_m, 1);
            rad_m = r_metro * sqrt(rand(N_m, 1)); % Uniform distribution in circle
            x_m = rad_m .* cos(theta_m);
            y_m = rad_m .* sin(theta_m);
            
            % Suburban PPP (Sparse)
            area_s = pi * (r_sub^2 - r_metro^2);
            N_s = poissrnd(d_sub * area_s);
            theta_s = 2 * pi * rand(N_s, 1);
            rad_s = sqrt(r_metro^2 + rand(N_s, 1) * (r_sub^2 - r_metro^2)); % Uniform in ring
            x_s = rad_s .* cos(theta_s);
            y_s = rad_s .* sin(theta_s);
            
            site_x = [x_m; x_s] * 1000;
            site_y = [y_m; y_s] * 1000;
            [site_lat, site_lon] = xy2latlon(site_x, site_y, Config);
        end
        
        % Filter generated points strictly to the Tripoli Shapefile polygon
        in_poly = inpolygon(site_lon, site_lat, Config.coastline_poly.lon, Config.coastline_poly.lat);
        site_lat = site_lat(in_poly);
        site_lon = site_lon(in_poly);
        
        if isempty(site_lat), continue; end
        
        num_sectors = layer.sectors;
        gNB_lat = repelem(site_lat, num_sectors);
        gNB_lon = repelem(site_lon, num_sectors);
        
        all_gNB_lat = [all_gNB_lat; gNB_lat];
        all_gNB_lon = [all_gNB_lon; gNB_lon];
        
        n_new = length(gNB_lat);
        all_height = [all_height; repmat(layer.height_m, n_new, 1)];
        all_layer_id = [all_layer_id; repmat(i, n_new, 1)];
        all_freq = [all_freq; repmat(layer.freq_GHz, n_new, 1)];
        all_bw = [all_bw; repmat(layer.bw_MHz*1e6, n_new, 1)];
        all_power = [all_power; repmat(layer.tx_power_dBm, n_new, 1)];
        all_ant_type = [all_ant_type; repmat({layer.antenna_type}, n_new, 1)];
    end

    Network = struct();
    [gNBs_x, gNBs_y] = latlon2xy(all_gNB_lat, all_gNB_lon, Config);
    Network.num_gNodeBs = length(all_gNB_lat);
    Network.gNodeBs.x_row = gNBs_x'; 
    Network.gNodeBs.y_row = gNBs_y';
    Network.gNodeBs.lat = all_gNB_lat; 
    Network.gNodeBs.lon = all_gNB_lon;
    Network.gNodeBs.height_m_row = all_height'; 
    
    Network.gNodeBs.azimuth_deg_row = repmat([0, 120, 240], 1, ceil(Network.num_gNodeBs/3));
    if ~isempty(Network.gNodeBs.azimuth_deg_row)
        Network.gNodeBs.azimuth_deg_row = Network.gNodeBs.azimuth_deg_row(1:Network.num_gNodeBs);
    end
    Network.gNodeBs.tx_power_dBm_row = all_power';
    Network.gNodeBs.freq_GHz_row = all_freq';
    Network.gNodeBs.bw_Hz_row = all_bw';
    Network.gNodeBs.layer_id_row = all_layer_id';
    Network.gNodeBs.antenna_type = all_ant_type';

    % --- 3. Deploy UEs (Poisson Point Process) ---
    fprintf('  > Users: Generating Poisson Point Process (PPP)...\n');
    
    % --- DYNAMIC LOAD FIX ---
    % Calculate total UEs based on generated sectors instead of a hardcoded 1000
    total_sectors = Network.num_gNodeBs;
    Config.num_UEs_total = total_sectors * Config.ues_per_sector;
    fprintf('  > Dynamic Load: %d sectors * %d UEs/sector = %d Total UEs\n', ...
             total_sectors, Config.ues_per_sector, Config.num_UEs_total);
             
    % Generate excess points across the full radius to account for Tripoli shapefile trimming
    N_ue_gen = Config.num_UEs_total * 4; 
    theta_ue = 2 * pi * rand(N_ue_gen, 1);
    rad_ue = r_sub * sqrt(rand(N_ue_gen, 1));
    ue_x_cand = rad_ue .* cos(theta_ue) * 1000;
    ue_y_cand = rad_ue .* sin(theta_ue) * 1000;
    
    [ue_lat_cand, ue_lon_cand] = xy2latlon(ue_x_cand, ue_y_cand, Config);
    in_poly_ue = inpolygon(ue_lon_cand, ue_lat_cand, Config.coastline_poly.lon, Config.coastline_poly.lat);
    
    ue_lat = ue_lat_cand(in_poly_ue); 
    ue_lon = ue_lon_cand(in_poly_ue);
    
    % Trim to the exact dynamically calculated number 
    if length(ue_lat) > Config.num_UEs_total
        ue_lat = ue_lat(1:Config.num_UEs_total); 
        ue_lon = ue_lon(1:Config.num_UEs_total);
    else
        fprintf('  > Warning: Shapefile constraint resulted in fewer UEs than configured.\n');
    end
    [ue_x, ue_y] = latlon2xy(ue_lat, ue_lon, Config);
    UEs = struct('num_UEs', length(ue_x), 'x_col', ue_x, 'y_col', ue_y);
    UEs.slice_id_col = randi(length(Config.slices), length(ue_x), 1);
end

% --- Helpers ---
function [x, y] = latlon2xy(lat, lon, Config)
    R = 6371000; 
    x = R * deg2rad(lon - Config.city_center_lon) * cosd(Config.city_center_lat);
    y = R * deg2rad(lat - Config.city_center_lat);
end

function [lat, lon] = xy2latlon(x, y, Config)
    R = 6371000; 
    lat = Config.city_center_lat + rad2deg(y/R);
    lon = Config.city_center_lon + rad2deg(x./(R*cosd(Config.city_center_lat)));
end

function [lat, lon] = utm_zone33n_to_deg(x, y)
    a = 6378137; f = 1/298.257223563; k0 = 0.9996; lon0 = 15; e2 = 2*f - f^2;
    e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2));
    x = x - 500000; M = y / k0;
    mu = M / (a * (1 - e2/4 - 3*e2^2/64 - 5*e2^3/256));
    phi1 = mu + (3*e1/2 - 27*e1^3/32)*sin(2*mu) + (21*e1^2/16 - 55*e1^4/32)*sin(4*mu) + (151*e1^3/96)*sin(6*mu);
    N1 = a ./ sqrt(1 - e2 * sin(phi1).^2); T1 = tan(phi1).^2; C1 = e2 * cos(phi1).^2 ./ (1 - e2);
    R1 = a * (1 - e2) ./ (1 - e2 * sin(phi1).^2).^1.5; D = x ./ (N1 * k0);
    lat = rad2deg(phi1 - (N1 .* tan(phi1) ./ R1) .* (D.^2/2 - (5 + 3*T1 + 10*C1 - 4*C1.^2 - 9*e2/ (1-e2)) .* D.^4/24));
    lon = lon0 + rad2deg((D - (1 + 2*T1 + C1) .* D.^3/6 + (5 - 2*C1 + 28*T1 - 3*C1.^2 + 8*e2/(1-e2) + 24*T1.^2) .* D.^5/120) ./ cos(phi1));
end