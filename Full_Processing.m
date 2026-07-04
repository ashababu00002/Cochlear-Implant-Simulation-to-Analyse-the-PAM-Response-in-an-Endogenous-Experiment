% =========================================================================
% Signal Processing & Analysis
% Master's Thesis — Auditory Attention Decoding
%
% Pipeline:
%   1. EOG calibration (regression-based artifact removal)
%   2. Trigger-locked signal extraction (5-min window)
%   3. Bandpass filtering + 50 Hz notch
%   4. 1-s energy segmentation with artifact rejection
%   5. Condition-wise normalised energy (ipsi vs contra)
%   6. Temporal dynamics via 10-s segments
%
% Channels:  Time      = CH01
%            Right PAM = CH02 - CH03
%            Left  PAM = CH04 - CH05
%            Right SAM = CH06 - CH07
%            Left  SAM = CH08 - CH09
%            Right AAM = CH10 - CH11
%            Left  AAM = CH12 - CH13
%            EOG       = CH14 - CH15
%            Trigger   = CH18
%
% Author: ASHA BABU
% =========================================================================

clc; clear; close all;
data_folder = 'C:\Users\HP\Documents\Thesis & Project\master_thesis\measurements\Raw_Data\P12';
fs          = 4800;          
ds_factor   = 2;            
fs_ds       = fs / ds_factor;
trial_dur   = 300;          

files = dir(fullfile(data_folder, '*.mat'));
if isempty(files)
    error('No .mat files found in: %s', data_folder);
end
fprintf('Found %d files in folder.\n\n', length(files));

% -------------------------------------------------------------------------
% Pre-build AAM filters (done once, reused for every trial)
%   - Bandpass : 10-1000 Hz, FIR order 2000 (zero-phase via filtfilt)
%   - Notch    : 50 Hz IIR (removes power-line interference)
% -------------------------------------------------------------------------
fn           = fs / 2;
b_bandpass   = fir1(2000, [10 1000] / fn, 'bandpass');
[b_notch, a_notch] = iirnotch(50/fn, (50/fn)/35);

% -------------------------------------------------------------------------
% EOG Calibration
%
% The calibration recording contains deliberate horizontal saccades.
% We use the saccade peaks to estimate how much EOG signal leaks into
% each AAM channel (beta coefficients). These betas are then used to
% subtract the eye-movement artifact from every trial.
% -------------------------------------------------------------------------
fprintf('--- Step 1: EOG Calibration ---\n');

calib_path = fullfile(data_folder, 'EOG_Calib.mat');
if ~isfile(calib_path)
    error('Calibration file not found: %s', calib_path);
end

cal       = load(calib_path);
y_cal     = double(cal.y);   
fprintf('Calibration: %d channels x %d samples\n', size(y_cal,1), size(y_cal,2));

% Extract and filter the EOG signal (0.01-20 Hz bandpass + 50 Hz notch)
eog_raw  = y_cal(14,:) - y_cal(15,:);
eog_cal  = filter_eog(eog_raw, fs);

% Filter Muscle channels through the same pipeline before computing betas

PAM_r_cal = filtfilt(b_bandpass, 1, double(y_cal(10,:) - y_cal(11,:)));
PAM_r_cal = filtfilt(b_notch, a_notch, PAM_r_cal);
PAM_l_cal = filtfilt(b_bandpass, 1, double(y_cal(12,:) - y_cal(13,:)));
PAM_l_cal = filtfilt(b_notch, a_notch, PAM_l_cal);

% Detect saccade peaks (positive = +30 right, negative = -30 left)
thresh_pos = 0.6 * max(eog_cal);
thresh_neg = 0.6 * abs(min(eog_cal));

[~, idx_pos] = findpeaks( eog_cal, 'MinPeakHeight', thresh_pos, 'MinPeakDistance', 2*fs);
[~, idx_neg] = findpeaks(-eog_cal, 'MinPeakHeight', thresh_neg, 'MinPeakDistance', 2*fs);
fprintf('Saccade peaks detected — rightward: %d | leftward: %d\n', length(idx_pos), length(idx_neg));

if isempty(idx_pos) || isempty(idx_neg)
    figure; plot((0:length(eog_cal)-1)/fs, eog_cal);
    title('Filtered EOG — No Peaks Found');
    xlabel('Time (s)'); ylabel('Amplitude (µV)'); grid on;
    error('Calibration failed: could not detect EOG peaks. Check the plot.');
end

% Regression coefficients:filtered / EOG at saccade peaks
beta_r = mean([PAM_r_cal(idx_pos), PAM_r_cal(idx_neg)]) / ...
         mean([eog_cal(idx_pos),   -eog_cal(idx_neg)]);
beta_l = mean([PAM_l_cal(idx_pos), PAM_l_cal(idx_neg)]) / ...
         mean([eog_cal(idx_pos),   -eog_cal(idx_neg)]);

fprintf('Beta coefficients — Right: %.6f | Left: %.6f\n', beta_r, beta_l);
if abs(beta_r) > 5 || abs(beta_l) > 5
    warning('Beta values are unusually large. Check electrode placement.');
end
fprintf('\n');

% -------------------------------------------------------------------------
% Main Trial Processing Loop
% -------------------------------------------------------------------------
results     = struct();   % Stores mean energy per condition (Step 2)
results_10s = struct();   % Stores 10-s time series per condition (Step 3)
n_processed = 0;

for k = 1:length(files)

    fname = files(k).name;

    % Skip the calibration file and anything without condition labels
    if contains(fname, 'EOG')
        continue;
    end
    if ~(contains(fname,'Front') || contains(fname,'Back')) || ...
       ~(contains(fname,'Easy')  || contains(fname,'Difficult'))
        fprintf('Skipping %s — condition tags missing.\n', fname);
        continue;
    end


    % Load trial data
    tmp = load(fullfile(files(k).folder, fname));
    y   = double(tmp.y);

    % --- Trigger detection (CH18) ---
    % Trigger goes high at audio onset; find the first active sample
    trigger      = double(y(18,:));
    onset_sample = find(trigger > 0, 1, 'first');

    if isempty(onset_sample)
        fprintf('  No trigger found — skipping.\n');
        continue;
    end

    % Extract the 5-minute window starting from audio onset
    end_sample = min(onset_sample + trial_dur*fs - 1, size(y,2));
    y_trial    = y(:, onset_sample:end_sample);
    fprintf('  Trigger at %.2f s | Trial window: %d samples\n', ...
             onset_sample/fs, size(y_trial,2));

    % EOG artifact removal 
    % Subtract the EOG-correlated component from each PAM channel
    eog_trial   = filter_eog(y_trial(14,:) - y_trial(15,:), fs);
    PAM_r_raw   = double(y_trial(10,:) - y_trial(11,:));
    PAM_l_raw   = double(y_trial(12,:) - y_trial(13,:));
    PAM_r_clean = PAM_r_raw - beta_r * eog_trial;
    PAM_l_clean = PAM_l_raw - beta_l * eog_trial;

    %  filtering (bandpass 10-1000 Hz + 50 Hz notch) 
    PAM_r = filtfilt(b_bandpass, 1, PAM_r_clean);
    PAM_r = filtfilt(b_notch, a_notch, PAM_r);
    PAM_l = filtfilt(b_bandpass, 1, PAM_l_clean);
    PAM_l = filtfilt(b_notch, a_notch, PAM_l);

    % Downsample to 2400 Hz
    PAM_r = downsample(PAM_r, ds_factor);
    PAM_l = downsample(PAM_l, ds_factor);

    % -----------------------------------------------------------------------
    % 1-second segmentation with energy-based artifact rejection
    %
    % Segments whose energy deviates by more than 2 SD from the mean are
    % discarded. Rejection is applied per channel; a segment is kept only
    % if both channels pass.
    % -----------------------------------------------------------------------
    seg_len_1s = floor(fs_ds);

    segs_r = buffer(PAM_r, seg_len_1s, 0, 'nodelay');
    segs_l = buffer(PAM_l, seg_len_1s, 0, 'nodelay');

    energy_r = mean(segs_r.^2, 1);
    energy_l = mean(segs_l.^2, 1);

    keep_r = abs(energy_r - mean(energy_r)) <= 2 * std(energy_r);
    keep_l = abs(energy_l - mean(energy_l)) <= 2 * std(energy_l);
    keep   = keep_r & keep_l;

    fprintf('  1-s segments: %d kept / %d rejected\n', sum(keep), sum(~keep));

    if sum(keep) == 0
        fprintf('  All segments rejected — skipping trial.\n');
        continue;
    end

    mean_energy_r = mean(energy_r(keep));
    mean_energy_l = mean(energy_l(keep));

    % -----------------------------------------------------------------------
    % 10-second segmentation for temporal dynamics
    %
    % Energy is computed in consecutive 10-s windows and normalised to the
    % maximum across both channels within the trial, following the approach
    % described in the paper.
    % -----------------------------------------------------------------------
    seg_len_10s = 10 * floor(fs_ds);

    segs_r_10s = buffer(PAM_r, seg_len_10s, 0, 'nodelay');
    segs_l_10s = buffer(PAM_l, seg_len_10s, 0, 'nodelay');

    energy_r_10s = mean(segs_r_10s.^2, 1);
    energy_l_10s = mean(segs_l_10s.^2, 1);

    % Normalise within this trial
    trial_max        = max([energy_r_10s, energy_l_10s]);
    energy_r_10s_norm = energy_r_10s / trial_max;
    energy_l_10s_norm = energy_l_10s / trial_max;
    n_segs_10s        = length(energy_r_10s);

    % Condition and laterality labels 
    if contains(fname, 'Front'),     position   = 'Front';     else, position   = 'Back';      end
    if contains(fname, 'Easy'),      difficulty = 'Easy';      else, difficulty = 'Difficult'; end
    if contains(fname, 'Left'),      side       = 'L';         else, side       = 'R';         end

    % Assign ipsi/contra relative to the attended speaker side
    if side == 'L'
        ipsi_mean  = mean_energy_l;      contra_mean  = mean_energy_r;
        ipsi_10s   = energy_l_10s_norm;  contra_10s   = energy_r_10s_norm;
    else
        ipsi_mean  = mean_energy_r;      contra_mean  = mean_energy_l;
        ipsi_10s   = energy_r_10s_norm;  contra_10s   = energy_l_10s_norm;
    end

    % Store results 1s segments
    cond_label = [difficulty '_' position];
    ki = ['ipsi_'   cond_label];
    kc = ['contra_' cond_label];

    if ~isfield(results, ki)
        results.(ki) = [];
        results.(kc) = [];
    end
    results.(ki) = [results.(ki), ipsi_mean];
    results.(kc) = [results.(kc), contra_mean];

    % Store results 10s segments
    ki10 = ['ipsi_10s_'         cond_label];
    kc10 = ['contra_10s_'       cond_label];
    ki10_n = ['ipsi_10s_count_'   cond_label];
    kc10_n = ['contra_10s_count_' cond_label];

    if ~isfield(results_10s, ki10)
        results_10s.(ki10)   = zeros(1, n_segs_10s);
        results_10s.(kc10)   = zeros(1, n_segs_10s);
        results_10s.(ki10_n) = 0;
        results_10s.(kc10_n) = 0;
    end

    n_common = min(n_segs_10s, length(results_10s.(ki10)));
    results_10s.(ki10)(1:n_common)   = results_10s.(ki10)(1:n_common)   + ipsi_10s(1:n_common);
    results_10s.(kc10)(1:n_common)   = results_10s.(kc10)(1:n_common)   + contra_10s(1:n_common);
    results_10s.(ki10_n)             = results_10s.(ki10_n) + 1;
    results_10s.(kc10_n)             = results_10s.(kc10_n) + 1;

    n_processed = n_processed + 1;
end

if n_processed == 0
    error('No trials were processed. Check filenames and trigger channel.');
end
fprintf('\nCompleted: %d trials processed.\n\n', n_processed);

% -------------------------------------------------------------------------
% Results — Average and normalise across trials
%
% Each condition's mean energy is averaged across repetitions, then
% normalised to the largest value across all conditions so that results
% are expressed relative to the participant's maximum response.
% -------------------------------------------------------------------------
fprintf('--- Step 2: Normalised Mean Energy ---\n');

cond_fields = fieldnames(results);
avg  = struct();
norm_Energy = struct();

for i = 1:length(cond_fields)
    avg.(cond_fields{i}) = mean(results.(cond_fields{i}));
end

max_val = max(struct2array(avg));
for i = 1:length(cond_fields)
    norm_Energy.(cond_fields{i}) = avg.(cond_fields{i}) / max_val;
end

disp(norm_Energy);

% -------------------------------------------------------------------------
% Results — Temporal dynamics plot (10s segments)
% -------------------------------------------------------------------------
conditions = {'Easy_Front', 'Easy_Back', 'Difficult_Front', 'Difficult_Back'};
time_axis  = (1:30) * 10;   % 30 segments x 10 s = 300 s

figure('Name', 'Temporal Dynamics of Auricular EMG', 'NumberTitle', 'off');

for c = 1:length(conditions)
    cond = conditions{c};
    ki10   = ['ipsi_10s_'         cond];
    kc10   = ['contra_10s_'       cond];
    ki10_n = ['ipsi_10s_count_'   cond];
    kc10_n = ['contra_10s_count_' cond];

    if ~isfield(results_10s, ki10), continue; end

    avg_ipsi   = results_10s.(ki10) / results_10s.(ki10_n);
    avg_contra = results_10s.(kc10) / results_10s.(kc10_n);
    n_plot     = min([length(avg_ipsi), length(avg_contra), length(time_axis)]);

    subplot(2, 2, c);
    plot(time_axis(1:n_plot), avg_ipsi(1:n_plot),   'b-o', 'LineWidth', 1.5); hold on;
    plot(time_axis(1:n_plot), avg_contra(1:n_plot), 'r-o', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Normalised Energy');
    title(strrep(cond, '_', ' '), 'FontWeight', 'bold');
    legend('Ipsilateral', 'Contralateral', 'Location', 'best');
    ylim([0 1.1]); grid on;
end

sgtitle('Temporal Dynamics of Auricular EMG (10-s segments)', 'FontSize', 13);

% =========================================================================
% EOG bandpass filter (0.01–20 Hz + 50 Hz notch)
% =========================================================================
function eog_filtered = filter_eog(raw_eog, fs)
    signal = detrend(double(raw_eog), 'constant');
    [b_n, a_n] = iirnotch(50/(fs/2), (50/(fs/2))/35);
    signal = filtfilt(b_n, a_n, signal);
    [b_bp, a_bp] = butter(2, [0.01 20] / (fs/2), 'bandpass');
    eog_filtered = filtfilt(b_bp, a_bp, signal);
end