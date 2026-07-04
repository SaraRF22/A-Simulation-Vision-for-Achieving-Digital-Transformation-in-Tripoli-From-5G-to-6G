function UEs = assign_ues_to_slices(UEs, Config)
% Assigns each UE to a network slice based on configured ratios.
    num_UEs = UEs.num_UEs;
    slice_ids = zeros(num_UEs, 1);
    start_idx = 1;

    for s = 1:length(Config.slices)
        slice = Config.slices{s};
        num_ue_in_slice = round(num_UEs * slice.user_ratio);
        end_idx = min(start_idx + num_ue_in_slice - 1, num_UEs);
        if start_idx > end_idx, continue; end
        slice_ids(start_idx:end_idx) = s;
        start_idx = end_idx + 1;
    end

    % Fill any remaining UEs due to rounding
    if start_idx <= num_UEs
        slice_ids(start_idx:end) = length(Config.slices);
    end
    UEs.slice_id_col = slice_ids(randperm(num_UEs)); % Shuffle assignments
end