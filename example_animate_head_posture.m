% example_animate_head_posture.m
%
% Example for animate_head_posture.m: side-by-side video of head tilt in
% two conditions, from the Euler angles of a head-mounted Movella DOT.
% Run this script from any folder; it only needs the files in this folder
% (base MATLAB R2020b or later, no toolboxes).
%
% EXAMPLE DATA (example_data/, one participant of Sophies
% dual-task study, anonymised, 60 Hz):
%   condition1_gonogo.csv        first 120 s of walking with the Go/No-Go task
%   condition2_walking_only.csv  first 120 s of walking only
%   baseline_standing_1/2.csv    8 s of quiet standing (looking forward)
%                                before each of the two walking periods
%   columns: time_s (from segment start), roll_deg, pitch_deg, yaw_deg
%            = Movella Euler angles (Xsens ZYX convention)
%   Sensor mount: glued behind the left ear, sensor x up, y towards the
%   nose, z to the left -- animate_head_posture's default 'forward_axis'
%   [0 1 0]. Change 'forward_axis' if your sensor is mounted differently.
%
% OUTPUT (output/):
%   1. a still frame with the standing baseline as reference
%   2. the same frame without a baseline (reference = median posture of
%      both conditions; the difference between conditions is the same,
%      only the zero point moves)
%   3. the video, 8x speed (120 s of data -> 15 s of video)
%
% With your own data: pass one N x 3 matrix [roll pitch yaw] (deg) per
% condition, the two condition names, and either 'fs' (Hz) or the
% timestamps ('time1', 'time2'). See help animate_head_posture for all
% options (speed, style, colours, ...).

here = fileparts(mfilename('fullpath'));
addpath(here);
data_dir = fullfile(here, 'example_data');
out_dir  = fullfile(here, 'output');

% ---- load ----------------------------------------------------------------
c1 = readtable(fullfile(data_dir, 'condition1_gonogo.csv'));
c2 = readtable(fullfile(data_dir, 'condition2_walking_only.csv'));
eul_cols = {'roll_deg', 'pitch_deg', 'yaw_deg'};
eul1 = c1{:, eul_cols};
eul2 = c2{:, eul_cols};
% standing baseline: several standing phases are passed as a cell array
% and pooled
b1 = readtable(fullfile(data_dir, 'baseline_standing_1.csv'));
b2 = readtable(fullfile(data_dir, 'baseline_standing_2.csv'));
baseline = {b1{:, eul_cols}, b2{:, eul_cols}};

% ---- 1. still frame, standing baseline as reference ------------------------
animate_head_posture(eul1, eul2, 'Go/No-Go', 'Walking only', ...
    'time1', c1.time_s, 'time2', c2.time_s, 'baseline', baseline, ...
    'title', 'example participant', 'still_t', 17, ...
    'out_file', fullfile(out_dir, 'example_baseline'));

% ---- 2. same frame without baseline (reference = median of both) ----------
animate_head_posture(eul1, eul2, 'Go/No-Go', 'Walking only', ...
    'fs', 60, 'title', 'example participant', 'still_t', 17, ...
    'out_file', fullfile(out_dir, 'example_no_baseline'));

% ---- 3. video, 8x speed (takes ~1 min) --------------------------------------
animate_head_posture(eul1, eul2, 'Go/No-Go', 'Walking only', ...
    'time1', c1.time_s, 'time2', c2.time_s, 'baseline', baseline, ...
    'title', 'example participant', 'speed', 8, ...
    'out_file', fullfile(out_dir, 'example_baseline'));
