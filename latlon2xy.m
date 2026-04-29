function [x, y] = latlon2xy(lat, lon, Config)
% LATLON2XY Converts geographic coordinates (lat, lon) to Cartesian (x, y).
    dlat = deg2rad(lat - Config.city_center_lat);
    dlon = deg2rad(lon - Config.city_center_lon);
    x = Config.earth_radius_m * dlon .* cos(deg2rad(Config.city_center_lat));
    y = Config.earth_radius_m * dlat;
end
