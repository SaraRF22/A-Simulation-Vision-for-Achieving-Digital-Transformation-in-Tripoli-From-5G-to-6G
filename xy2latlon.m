function [lat, lon] = xy2latlon(x, y, Config)
% XY2LATLON Translates Cartesian (X,Y) coordinates in meters back into 
% Geographic (Latitude, Longitude) coordinates for mapping.

    % Define Earth's radius in meters
    if isfield(Config, 'earth_radius_m')
        R = Config.earth_radius_m;
    else
        R = 6371000; 
    end

    % Extract the reference origin point (Tripoli City Center)
    lat0 = Config.city_center_lat;
    lon0 = Config.city_center_lon;

    % Calculate coordinate offsets
    % Latitude changes purely with Y (North/South)
    lat_offset = (y ./ R) .* (180 / pi);
    
    % Longitude changes with X (East/West), scales with the cosine of Latitude
    lon_offset = (x ./ (R .* cosd(lat0))) .* (180 / pi);

    % Calculate final geographic coordinates
    lat = lat0 + lat_offset;
    lon = lon0 + lon_offset;
end