function files = xdf_to_example_data(xdf_file, out_dir, varargin)
% XDF_TO_EXAMPLE_DATA  Convert one XDF recording (Movella DOT head sensor +
% Presentation marker stream, Walking-and-Thinking protocol) into the CSV
% files that example_animate_head_posture.m reads.
%
%   xdf_to_example_data('rec.xdf', 'example_data')            % defaults below
%   xdf_to_example_data('rec.xdf', 'my_data', 'cond1', 'phone', 'label1', 'phone', ...
%                       'epoch_nr', [2 2], 'seg_s', Inf)
%
% Requires load_xdf (xdf-Matlab, https://github.com/xdf-modules/xdf-Matlab)
% on the MATLAB path. Otherwise base MATLAB only.
%
% OUTPUT (in out_dir; columns time_s, roll_deg, pitch_deg, yaw_deg):
%   condition1_<label1>.csv     segment of the epoch_nr(1)-th epoch of cond1
%   condition2_<label2>.csv     segment of the epoch_nr(2)-th epoch of cond2
%   baseline_standing_1/2.csv   standing phase before each of those epochs
%   time_s runs from 0 at the start of each segment. No subject code is
%   written anywhere -- name the output folder as you like.
%   files = cell array of the written paths.
%
% OPTIONS (name-value), defaults reproduce the repository's example_data:
%   'cond1','cond2'    condition codes: 'walking_only' | 'phone' | 'gng'
%                      (default 'gng', 'walking_only')
%   'label1','label2'  used in the file names (default 'gonogo', 'walking_only')
%   'epoch_nr'         which epoch of each condition, chronological (default [1 1])
%   'seg_s'            seconds from each epoch's start (default 120; Inf = whole epoch)
%   'baseline_win'     window after the stand_start marker, s (default [1 9])
%   'movella_stream'   stream name contains this (default 'Movella DOT')
%   'marker_stream'    marker stream name (default 'Presentation')
%   'euler_rows'       rows of the Movella stream holding [roll pitch yaw] (default 4:6)
%
% PROCESSING (the same steps that produced example_data/, so the defaults
% reproduce those CSVs exactly from the original recording):
%   1. Movella timestamps de-jittered (the stream reports nominal_srate 0 and
%      arrives in bursts, so load_xdf does not de-jitter it): per stretch
%      between gaps > 1 s, a least-squares line of time vs sample index,
%      over the WHOLE recording.
%   2. Euler angles: filloutliers(..., 'linear', 'movmean', 20) over the
%      whole recording; touches essentially only the
%      +-180 deg wrap-arounds, which the animation is insensitive to anyway.
%   3. Epochs from the markers: walking epoch =
%      03_walk_start -> next 03_stand_start; its condition = the last
%      announcement (03_phone_start / 03_gng_start / ...) since the previous
%      03_stand_start, 'phone' / 'gng' by substring, otherwise walking_only.
%      Unprefixed marker spellings (walk_start, stand_start, ...) are mapped.
%   4. Standing baseline: baseline_win after the last 03_stand_start that
%      precedes the epoch start by > 1 s (the 10-s quiet stand before the
%      condition announcement).
% NOT handled: recordings split into several XDF files, and recordings
% with missing or mislabelled markers (check the epoch count it reports).

p = inputParser;
p.addParameter('cond1', 'gng');
p.addParameter('cond2', 'walking_only');
p.addParameter('label1', 'gonogo');
p.addParameter('label2', 'walking_only');
p.addParameter('epoch_nr', [1 1]);
p.addParameter('seg_s', 120);
p.addParameter('baseline_win', [1 9]);
p.addParameter('movella_stream', 'Movella DOT');
p.addParameter('marker_stream', 'Presentation');
p.addParameter('euler_rows', 4:6);
p.parse(varargin{:});
opt = p.Results;
if isscalar(opt.epoch_nr); opt.epoch_nr = opt.epoch_nr([1 1]); end
if exist('load_xdf', 'file') ~= 2
    error('load_xdf not found -- add xdf-Matlab (https://github.com/xdf-modules/xdf-Matlab) to the path');
end

% ---- streams ---------------------------------------------------------------
streams = load_xdf(xdf_file);
names   = cellfun(@(s) s.info.name, streams, 'UniformOutput', false);
im = find(contains(names, opt.movella_stream));
im = im(arrayfun(@(k) size(streams{k}.time_series, 2) > 0, im));   % skip empty ghost streams
ip = find(strcmp(names, opt.marker_stream));
if isempty(im); error('no %s stream with data in %s', opt.movella_stream, xdf_file); end
if isempty(ip); error('no %s stream in %s', opt.marker_stream, xdf_file); end
mov = streams{im(1)};  pres = streams{ip(1)};

t   = dejitter(mov.time_stamps(:), 1.0);
eul = double(mov.time_series(opt.euler_rows, :))';
eul = filloutliers(eul, 'linear', 'movmean', 20, 1);

% ---- markers -> walking epochs ------------------------------------------------
mt = pres.time_stamps(:);
ml = cellfun(@(v) strtrim(char(string(v))), pres.time_series(:), 'UniformOutput', false);
alias = {'stand_start', '03_stand_start'; 'walk_start', '03_walk_start'; 'end_run', '03_end_run'; ...
         'gng', '03_gng_start'; 'phone', '03_phone_start'};
[ia, ir] = ismember(ml, alias(:, 1));
ml(ia) = alias(ir(ia), 2);
announce = {'03_start_single', '03_walk_single_start', '03_phone_start', '03_gng_start'};
is_walk  = strcmp(ml, '03_walk_start');
is_stand = strcmp(ml, '03_stand_start');
is_cond  = ismember(ml, announce);

E = struct('t_start', {}, 't_end', {}, 'task', {});
for wi = find(is_walk)'
    t0 = mt(wi);
    t1 = mt(find(is_stand & mt > t0, 1));
    if isempty(t1); continue; end
    prev_stand = mt(find(is_stand & mt < t0, 1, 'last'));
    if isempty(prev_stand); prev_stand = -inf; end
    ci = find(is_cond & mt > prev_stand & mt < t0, 1, 'last');
    task = 'walking_only';
    if ~isempty(ci)
        if contains(ml{ci}, 'phone'); task = 'phone'; elseif contains(ml{ci}, 'gng'); task = 'gng'; end
    end
    E(end+1) = struct('t_start', t0, 't_end', t1, 'task', task); %#ok<AGROW>
end
stand_t = mt(is_stand);
fprintf('walking epochs found: walking_only %d, phone %d, gng %d\n', nnz(strcmp({E.task}, 'walking_only')), ...
    nnz(strcmp({E.task}, 'phone')), nnz(strcmp({E.task}, 'gng')));

% ---- write ----------------------------------------------------------------------
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
conds  = {opt.cond1, opt.cond2};
labels = {opt.label1, opt.label2};
files  = {};
for c = 1:2
    Ec = E(strcmp({E.task}, conds{c}));
    if numel(Ec) < opt.epoch_nr(c)
        error('%s: %d %s epoch(s) found, epoch_nr %d requested', xdf_file, numel(Ec), conds{c}, opt.epoch_nr(c));
    end
    ep = Ec(opt.epoch_nr(c));
    m  = t >= ep.t_start & t < ep.t_start + opt.seg_s & t <= ep.t_end;
    files{end+1} = write_csv(fullfile(out_dir, sprintf('condition%d_%s.csv', c, labels{c})), ...
        t(m) - ep.t_start, eul(m, :)); %#ok<AGROW>
    s0 = stand_t(find(stand_t < ep.t_start - 1, 1, 'last'));
    if isempty(s0)
        warning('no stand_start marker before the %s epoch -- baseline_standing_%d.csv not written', conds{c}, c);
        continue
    end
    m = t >= s0 + opt.baseline_win(1) & t <= s0 + opt.baseline_win(2);
    files{end+1} = write_csv(fullfile(out_dir, sprintf('baseline_standing_%d.csv', c)), ...
        t(m) - t(find(m, 1)), eul(m, :)); %#ok<AGROW>
end
end

% =============================================================================

function f = write_csv(f, t, eul)
    T = array2table([t eul], 'VariableNames', {'time_s', 'roll_deg', 'pitch_deg', 'yaw_deg'});
    writetable(T, f);
    fprintf('%s: %d samples, %.1f s\n', f, height(T), t(end) - t(1));
end

function ts = dejitter(ts, break_s)
% piecewise least-squares line of time vs sample index, new piece at every
% gap > break_s (same method as load_xdf's HandleJitterRemoval)
    ts = ts(:)';
    n  = numel(ts);
    br = find(abs(diff(ts)) > break_s);
    rg = reshape([1, reshape([br; br + 1], 1, []), n], 2, [])';
    for r = 1:size(rg, 1)
        idx = rg(r, 1):rg(r, 2);
        if numel(idx) < 2; continue; end
        ab = ts(idx) / [ones(1, numel(idx)); idx];
        ts(idx) = ab(1) + ab(2) * idx;
    end
    ts = ts(:);
end
