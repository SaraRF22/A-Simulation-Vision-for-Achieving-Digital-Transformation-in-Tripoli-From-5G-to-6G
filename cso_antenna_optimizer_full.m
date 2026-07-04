% =========================================================================
%  APPENDIX A: HYBRID CAT SWARM OPTIMIZATION (CSO) FOR 5G BEAMFORMING
%  Purpose: Optimizes antenna array weights to minimize Side Lobe Levels (SLL).
%  Target: Reduce interference by >25 dB for the "Enhanced" HetNet scenario.
% =========================================================================

clc; clear; close all;
fprintf('--- Starting CSO Antenna Optimization (Iterative Mode) ---\n');

% --- 1. System Parameters ---
N = 16;                 % Number of Antenna Elements
num_cats = 40;          % Population size (Number of "cats")
max_iter = 200;         % Maximum iterations
target_SLL = -26.0;     % Target SLL in dB (The 25dB improvement goal)

% CSO Algorithm Constants
SMP = 5;                % Seeking Memory Pool (Copies of the cat)
SRD = 0.2;              % Seeking Range of Dimension (Mutation rate)
CDC = 0.8;              % Counts of Dimension to Change
MR = 0.3;               % Mixture Ratio (Ratio of tracing vs seeking cats)
c1 = 2.0;               % Acceleration constant
w_max = 0.9; w_min = 0.4; % Inertia weight limits

% --- 2. Initialization ---
% We optimize N/2 weights (symmetric array) to ensure a symmetric beam
dim = N / 2; 

% Initialize Cats (Position = Amplitude Weights [0, 1])
% Start with Uniform weights (all 1s) + small noise to help search start
cats_pos = ones(num_cats, dim) + 0.1 * randn(num_cats, dim);
cats_pos = max(0.1, min(1.0, cats_pos)); % Bound constraints

cats_vel = zeros(num_cats, dim); % Velocity vectors
cats_fitness = zeros(num_cats, 1);

best_pos = zeros(1, dim);
best_fitness = 0; % 0 dB is bad, we want -30 dB
convergence_curve = zeros(max_iter, 1);

% Evaluate Initial Fitness
for i = 1:num_cats
    cats_fitness(i) = evaluate_SLL(cats_pos(i, :), N);
end
[best_fitness, idx] = min(cats_fitness);
best_pos = cats_pos(idx, :);

% --- 3. Main Optimization Loop ---
fprintf('Optimizing... (Target: %.1f dB)\n', target_SLL);

for t = 1:max_iter
    % Dynamic Inertia Weight
    w = w_max - (w_max - w_min) * t / max_iter;
    
    % Sort cats into Seeking (Local Search) or Tracing (Global Search)
    num_tracing = round(num_cats * MR);
    
    % Shuffle cats randomly
    perm_idx = randperm(num_cats);
    
    for k = 1:num_cats
        i = perm_idx(k); % Current Cat Index
        
        if k <= num_tracing
            % --- TRACING MODE (Global Exploration) ---
            % Velocity Update: v = w*v + c*rand*(best - current)
            r = rand(1, dim);
            cats_vel(i, :) = w * cats_vel(i, :) + c1 * r .* (best_pos - cats_pos(i, :));
            
            % Position Update
            cats_pos(i, :) = cats_pos(i, :) + cats_vel(i, :);
            
            % Boundary Check [0.1, 1.0]
            cats_pos(i, :) = max(0.1, min(1.0, cats_pos(i, :)));
            
        else
            % --- SEEKING MODE (Local Refinement) ---
            % Create copies (candidates) and mutate them
            candidates = repmat(cats_pos(i, :), SMP, 1);
            
            % Mutate specific dimensions
            for s = 1:SMP
                if rand() < CDC
                    % Apply mutation +/- SRD
                    mutation = 1 + (rand(1, dim) - 0.5) * 2 * SRD;
                    candidates(s, :) = candidates(s, :) .* mutation;
                end
            end
            
            % Evaluate Candidates
            cand_scores = zeros(SMP, 1);
            for s = 1:SMP
                % Bounds check
                candidates(s, :) = max(0.1, min(1.0, candidates(s, :)));
                cand_scores(s) = evaluate_SLL(candidates(s, :), N);
            end
            
            % Pick best candidate to replace current cat
            [min_score, best_cand_idx] = min(cand_scores);
            cats_pos(i, :) = candidates(best_cand_idx, :);
            cats_fitness(i) = min_score;
        end
        
        % Update Fitness
        cats_fitness(i) = evaluate_SLL(cats_pos(i, :), N);
        
        % Update Global Best
        if cats_fitness(i) < best_fitness
            best_fitness = cats_fitness(i);
            best_pos = cats_pos(i, :);
        end
    end
    
    convergence_curve(t) = best_fitness;
    
    if mod(t, 20) == 0
        fprintf('Iter %d: Best SLL = %.2f dB\n', t, best_fitness);
    end
end

fprintf('--- Optimization Complete ---\n');
fprintf('Final Optimized SLL: %.2f dB\n', best_fitness);

% --- 4. Plotting Results ---
figure('Name', 'CSO Optimization Results', 'Color', 'w', 'Position', [100, 100, 1000, 500]);

% Subplot 1: Convergence
subplot(1, 2, 1);
plot(convergence_curve, 'LineWidth', 2, 'Color', 'b');
yline(target_SLL, 'r--', 'Target (-26dB)');
title('Algorithm Convergence (CSO)');
xlabel('Iteration'); ylabel('Peak SLL (dB)');
grid on;

% Subplot 2: Beam Pattern (Before vs After)
subplot(1, 2, 2);
theta = linspace(-90, 90, 1000);
% Baseline (Uniform)
w_uniform = ones(1, dim);
[pattern_base, ~] = get_pattern(w_uniform, N, theta);
% Optimized
[pattern_opt, ~] = get_pattern(best_pos, N, theta);

plot(theta, pattern_base, 'k--', 'LineWidth', 1.5); hold on;
plot(theta, pattern_opt, 'r-', 'LineWidth', 2.0);
yline(best_fitness, 'r:', 'Optimized SLL');
legend('Baseline (Uniform)', 'CSO Optimized');
title(sprintf('Beam Pattern (Improv: %.1f dB)', max(pattern_base(pattern_base<-5)) - best_fitness));
xlabel('Angle (deg)'); ylabel('Magnitude (dB)');
ylim([-60 0]); xlim([-90 90]);
grid on;

sgtitle('Appendix A: Cat Swarm Optimization for 5G Antenna Arrays', 'FontSize', 14, 'FontWeight', 'bold');


% --- 5. Helper Functions ---

function sll = evaluate_SLL(weights_half, N)
    % Reconstruct full array from symmetric weights
    theta = linspace(-90, 90, 300); % Coarse grid for speed
    [pattern_dB, ~] = get_pattern(weights_half, N, theta);
    
    % Find Peak SLL (exclude main lobe region +/- 10 deg)
    mask = abs(theta) > 12; 
    sidelobes = pattern_dB(mask);
    
    if isempty(sidelobes)
        sll = 0;
    else
        sll = max(sidelobes);
    end
end

function [pattern_dB, AF] = get_pattern(w_half, N, theta)
    % Symmetric Array Factor Calculation
    % w_half: [w1, w2, ... w8] corresponding to elements 1..8
    full_weights = [fliplr(w_half), w_half];
    d = 0.5; % spacing in wavelengths
    
    % Positions centered at 0
    pos = (-(N-1)/2 : (N-1)/2) * d;
    
    k = 2*pi;
    theta_rad = deg2rad(theta);
    
    % Calculate AF
    AF = zeros(size(theta));
    for n = 1:N
        AF = AF + full_weights(n) * exp(1j * k * pos(n) * sin(theta_rad));
    end
    
    % Element Pattern (Cosine approximation for patch antenna)
    EP = cos(theta_rad).^1.2;
    
    % Total Pattern
    Total = abs(AF .* EP);
    Total = Total / max(Total); % Normalize
    pattern_dB = 20*log10(Total + 1e-6); % Avoid log(0)
end