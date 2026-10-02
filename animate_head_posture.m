function out_file = animate_head_posture(eul1, eul2, name1, name2, varargin)
% ANIMATE_HEAD_POSTURE  Side-by-side video of head tilt in two conditions,
% from the Euler angles of a head-mounted Movella DOT sensor, replayed
% faster than real time. Visualisation only.
%
%   animate_head_posture(eul1, eul2, name1, name2, 'fs', fs)
%   animate_head_posture(..., 'baseline', eul_standing)    % reference = standing
%   animate_head_posture(..., 'still_t', 17)               % one PNG frame, no video
%
% INPUT
%   eul1, eul2    N x 3 Euler angles [roll pitch yaw] in degrees, one
%                 recording segment (e.g. one walking epoch) per condition.
%                 Convention: Movella/Xsens ZYX, R_sensor->earth =
%                 Rz(yaw) * Ry(pitch) * Rx(roll) (Movella DOT manual 4.2.3).
%   name1, name2  condition names (char/string), used for titles and the
%                 file name, e.g. 'Go/No-Go', 'Walking only'.
%   'fs'          sampling rate in Hz (required unless 'time1'/'time2' are given)
%
% OPTIONS (name-value)
%   'baseline'    standing data as the 0-deg reference: N x 3 Euler angles,
%                 or a cell array of such matrices (several standing
%                 phases, pooled). Without it, the reference is the median
%                 posture over BOTH conditions pooled -- the difference
%                 between the conditions is kept, but 0 deg then means
%                 "this person's average posture in these data", not
%                 upright.
%   'time1','time2' timestamps (s) of eul1 / eul2. Default: evenly
%                 sampled at fs. With timestamps, gaps > 1 s are not
%                 filtered across and are shaded in the time plots.
%   'speed'       playback speed factor (default 8)
%   'fps'         video frame rate (default 30)
%   'lowpass_hz'  posture low-pass (default 0.5 Hz: removes the step-by-
%                 step bounce, keeps posture; Inf = unfiltered)
%   'style'       'box' (default), 'stick' (stick figure) or 'profile'
%                 (flat head silhouette). Body/neck never move: only the
%                 head is measured.
%   'forward_axis' sensor axis pointing to the nose, default [0 1 0]
%                 (sensor y; our mount: glued behind the left ear, x up,
%                 y to the nose, z to the left)
%   'title'       figure title, e.g. the subject ID (default '')
%   'colors'      {rgb1, rgb2} (default orange, blue)
%   'max_s'       render only the first max_s seconds (default Inf)
%   'still_t'     time (s): write one PNG frame at that time instead of a video
%   'out_file'    output path without extension (default
%                 head_posture_<name1>_vs_<name2>_<style> in the current folder);
%                 '_x<speed>.mp4' or '_t<still_t>.png' is appended
%
% OUTPUT  path of the written .mp4 (or .png)
%
% WHAT IS SHOWN
%   Head TILT relative to the reference posture: pitch (nodding, nose
%   down/up) and roll (ear towards shoulder). No yaw: the head always faces
%   the same way on screen (absolute yaw turns with the walking path and,
%   relative to the walking direction, is not reliably available).
%   - up-vector u(t) = earth-vertical seen from the sensor, from roll and
%     pitch only: u = [-sin(p), cos(p) sin(r), cos(p) cos(r)] (3rd row of
%     R); no gimbal-lock / wrap-around problems; low-passed (zero-phase
%     2nd-order Butterworth) and renormalised;
%   - reference u0 = median up-vector of the baseline (or of both
%     conditions); head frame: forward = 'forward_axis' made perpendicular
%     to u0, left = u0 x forward;
%   - displayed head orientation = the SMALLEST rotation that tips the
%     upright head so that world-up, seen from the head, equals u(t) (a
%     pure swing, no twist about the vertical);
%   - per condition: side view (nodding) and front view (ear to shoulder),
%     dashed outline = reference posture; below, the forward / left tilt
%     time courses with a moving cursor. Both conditions start together
%     at t = 0; the shorter one freezes at its end.
%   Needs base MATLAB only (R2020b+ for tiledlayout features; no toolboxes).
%
% Standalone example with data: example_animate_head_posture.m (this folder).
%
% EXAMPLE with dual task walking data (run from src/, with this folder on
% the path, e.g. via main.m's addpath(genpath(pwd))): Go/No-Go vs walking
% only, first epoch each, standing baseline = the 10-s standing phase before
% each of the two epochs (1-9 s after the stand_start marker; note that
% inspect_head_posture.m pools ALL standing phases of the subject instead)
%   subj = 'recording_name_here';
%   f = load(fullfile('data', 'ana02_filtered', ['filtered_' subj '.mat']), ...
%       'euler_angles_raw', 'timestamps', 'presentation_data');
%   t = f.timestamps(:);  eul = f.euler_angles_raw;
%   g = load(fullfile('data', 'ana03_epochs', 'gng_epochs.mat'));
%   g = g.cond_epochs(strcmp({g.cond_epochs.rec_name}, subj));
%   w = load(fullfile('data', 'ana03_epochs', 'walking_only_epochs.mat'));
%   w = w.cond_epochs(strcmp({w.cond_epochs.rec_name}, subj));
%   mk = cellfun(@(v) char(string(v)), f.presentation_data.time_series, 'UniformOutput', false);
%   ts = f.presentation_data.time_stamps(endsWith(mk, 'stand_start'));
%   pre  = @(ep) ts(find(ts < ep.t_start - 1, 1, 'last'));
%   base = arrayfun(@(ep) eul(t >= pre(ep) + 1 & t <= pre(ep) + 9, :), [g(1) w(1)], 'UniformOutput', false);
%   in = @(ep) t >= ep.t_start & t <= ep.t_end;
%   animate_head_posture(eul(in(g(1)), :), eul(in(w(1)), :), 'Go/No-Go', 'Walking only', ...
%       'time1', t(in(g(1))), 'time2', t(in(w(1))), 'baseline', base, 'title', subj, ...
%       'out_file', fullfile('results', 'head_posture_animation', [subj '_gng_vs_walking_only']));

p = inputParser;
p.addParameter('fs', []);
p.addParameter('baseline', []);
p.addParameter('time1', []);
p.addParameter('time2', []);
p.addParameter('speed', 8);
p.addParameter('fps', 30);
p.addParameter('lowpass_hz', 0.5);
p.addParameter('style', 'box');
p.addParameter('forward_axis', [0 1 0]);
p.addParameter('title', '');
p.addParameter('colors', {[1.0 0.6 0.1], [0.2 0.6 1.0]});
p.addParameter('max_s', Inf);
p.addParameter('still_t', []);
p.addParameter('out_file', '');
p.parse(varargin{:});
opt = p.Results;
names = {char(name1), char(name2)};
gap_s = 1.0;   % timestamp gaps larger than this split the filtering

% ---- per condition: time, up-vector ---------------------------------------
E = {eul1, eul2};  T = {opt.time1, opt.time2};
P = struct('t', {}, 'u', {}, 'uh', {}, 'tip', {}, 'gap', {});
for c = 1:2
    if ~isnumeric(E{c}) || size(E{c}, 2) ~= 3
        error('eul%d must be an N x 3 matrix [roll pitch yaw] in degrees', c);
    end
    if isempty(T{c})
        if isempty(opt.fs); error('give ''fs'' or ''time%d''', c); end
        tt = (0:size(E{c}, 1) - 1)' / opt.fs;
    else
        tt = T{c}(:) - T{c}(1);
        if numel(tt) ~= size(E{c}, 1); error('time%d and eul%d differ in length', c, c); end
    end
    fs = opt.fs;
    if isempty(fs); fs = 1 / median(diff(tt)); end
    u = up_vector(double(E{c}));
    P(c).u = u;   % unfiltered, for the pooled reference
    if isfinite(opt.lowpass_hz); u = lowpass_unit(u, tt, fs, opt.lowpass_hz, gap_s); end
    P(c).t = tt;  P(c).uh = u;
    ig = find(diff(tt) > gap_s);
    P(c).gap = [tt(ig), tt(ig + 1)];
end

% ---- reference posture + head frame ---------------------------------------
if isempty(opt.baseline)
    u0 = median([P(1).u; P(2).u], 1);
    ref_txt = 'median posture of both conditions';
else
    B = opt.baseline;
    if ~iscell(B); B = {B}; end
    u0 = median(up_vector(double(vertcat(B{:}))), 1);
    ref_txt = 'standing baseline';
end
u0 = u0 / norm(u0);
fa = opt.forward_axis(:)' / norm(opt.forward_axis);
e_fwd  = fa - dot(fa, u0) * u0;  e_fwd = e_fwd / norm(e_fwd);
e_left = cross(u0, e_fwd);
Hs = [e_fwd; e_left; u0];   % rows: head axes in sensor coords
for c = 1:2
    uh = P(c).uh * Hs';                               % [fwd left up] components
    tilt = acosd(min(1, uh(:, 3)));
    az   = atan2(uh(:, 2), uh(:, 1));
    P(c).uh  = uh;
    P(c).tip = -tilt .* [cos(az), sin(az)];           % head-tip [forward left], deg
end

% ---- figure --------------------------------------------------------------
T_end  = min(max(arrayfun(@(q) q.t(end), P)), opt.max_s);
dt     = opt.speed / opt.fps;                         % data seconds per video frame
tf     = 0:dt:T_end;
lim    = max(5, ceil(max(arrayfun(@(q) max(abs(q.tip(:))), P)) / 5) * 5);

fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [50 50 1280 800], 'Visible', 'off');
tl  = tiledlayout(fig, 4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ttl = sprintf('head tilt relative to %s  -  %gx speed', ref_txt, opt.speed);
if ~isempty(opt.title); ttl = [char(opt.title) '  -  ' ttl]; end
title(tl, ttl, 'Interpreter', 'none', 'FontWeight', 'bold');
subtitle(tl, sprintf('+ forward = nose down / looking down;   + left = left ear towards shoulder;   dashed outline = %s', ref_txt), 'FontSize', 9);
% two views per condition: side (from the subject's right, nose to the
% right) shows nodding, front (face to the viewer, subject's left on
% screen right) shows ear-to-shoulder tilt
views  = {[0 0], [90 0]};
if strcmp(opt.style, 'box'); views = {[20 10], [90 10]}; end   % side slightly oblique: shows the face side
vnames = {'side', 'front'};
H = struct('xf', {}, 'cur', {}, 'txt', {});
hax = gobjects(0);
for c = 1:2
    col = opt.colors{c};
    xf = gobjects(1, 2);
    % nested layout per condition: its title = condition, its xlabel = live readout
    inner = tiledlayout(tl, 1, 2, 'TileSpacing', 'none', 'Padding', 'none');
    inner.Layout.Tile = c;  inner.Layout.TileSpan = [2 1];
    title(inner, names{c}, 'FontSize', 13, 'FontWeight', 'bold', 'Color', col * 0.8, 'Interpreter', 'none');
    txt = xlabel(inner, '', 'FontName', 'Consolas', 'FontSize', 11);
    for v = 1:2
        ax = nexttile(inner, v);
        hax(end+1) = ax; %#ok<AGROW>
        hold(ax, 'on'); axis(ax, 'equal', 'off');
        axis(ax, [-1.6 2.0 -1.6 1.6 -2.0 2.0]);
        view(ax, views{v});
        if ~strcmp(opt.style, 'box'); ax.SortMethod = 'childorder'; end   % flat 2D: draw order = stacking
        draw_body(ax, opt.style, v);
        draw_head(hgtransform(ax), opt.style, v, [0.5 0.5 0.5], true);   % ghost = reference posture
        xf(v) = hgtransform(ax);
        draw_head(xf(v), opt.style, v, col, false);
        text(ax, 0, 0, 1.95, [vnames{v} ' view'], 'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4], 'FontSize', 9);
    end
    % time courses
    cur = gobjects(2, 1);
    ylab = {'forward (deg)', 'left (deg)'};
    for r = 1:2
        axt = nexttile(tl, 4 + c + 2*(r-1));
        hold(axt, 'on'); box(axt, 'off');
        yline(axt, 0, 'k:');
        for g = 1:size(P(c).gap, 1)
            patch(axt, P(c).gap(g, [1 2 2 1]), [-lim -lim lim lim], [0.9 0.9 0.9], 'EdgeColor', 'none');
        end
        plot(axt, P(c).t, P(c).tip(:, r), '-', 'Color', col, 'LineWidth', 1);
        cur(r) = xline(axt, 0, 'k-', 'LineWidth', 1.5);
        xlim(axt, [0 T_end]); ylim(axt, [-lim lim]);
        ylabel(axt, ylab{r});
        if r == 2; xlabel(axt, 'time (s)'); end
    end
    H(c).xf = xf;  H(c).cur = cur;  H(c).txt = txt;
end
% same zoom in all head views (auto view angle differs between side and front)
set(hax, 'CameraViewAngle', 0.7 * max([hax.CameraViewAngle]));   % 0.7: zoom in on the head

stem = opt.out_file;
if isempty(stem)
    clean = @(s) regexprep(s, '[^\w-]+', '_');
    stem = sprintf('head_posture_%s_vs_%s_%s', clean(names{1}), clean(names{2}), opt.style);
end
od = fileparts(stem);
if ~isempty(od) && ~exist(od, 'dir'); mkdir(od); end
if ~isempty(opt.still_t)
    set_frame(H, P, opt.still_t);
    out_file = sprintf('%s_t%g.png', stem, opt.still_t);
    exportgraphics(fig, out_file, 'Resolution', 100);
    close(fig);
    fprintf('frame at t = %g s -> %s\n', opt.still_t, out_file);
    return
end
out_file = sprintf('%s_x%g.mp4', stem, opt.speed);
vw = VideoWriter(out_file, 'MPEG-4');
vw.FrameRate = opt.fps;  vw.Quality = 90;
open(vw);
cl = onCleanup(@() close(vw));
for i = 1:numel(tf)
    set_frame(H, P, tf(i));
    drawnow;
    writeVideo(vw, getframe(fig));
end
clear cl;
close(fig);
fprintf('%d frames (%.0f s of data at %gx = %.0f s video) -> %s\n', ...
    numel(tf), T_end, opt.speed, numel(tf) / opt.fps, out_file);
end

function set_frame(H, P, t_now)
% pose both panels at epoch time t_now (the shorter epoch holds its last sample)
    for c = 1:2
        q = P(c);
        tc = min(max(t_now, q.t(1)), q.t(end));
        in_gap = any(tc > q.gap(:, 1) & tc < q.gap(:, 2));
        uh = interp1(q.t, q.uh, tc, 'linear');  uh = uh / norm(uh);
        tip = interp1(q.t, q.tip, tc, 'linear');
        set(H(c).xf, 'Matrix', swing_to(uh));
        set(H(c).cur, 'Value', tc);
        s = sprintf('t = %5.1f s   forward %+5.1f   left %+5.1f deg', tc, tip(1), tip(2));
        if t_now > q.t(end); s = [s '   (epoch ended)']; end
        if in_gap; s = [s '   (data gap)']; end
        H(c).txt.String = s;
    end
end

% =========================================================================

function M = swing_to(uh)
% 4x4 transform tipping the upright head (head coords: x fwd, y left,
% z up) so that world-up seen from the head is uh: the smallest rotation R
% with R' * [0 0 1]' = uh', i.e. rotate uh onto z (no twist about vertical).
    z = [0 0 1];
    ax = cross(uh, z);  s = norm(ax);  c = dot(uh, z);
    if s < 1e-9
        R = eye(3);
    else
        k = ax / s;
        K = [0 -k(3) k(2); k(3) 0 -k(1); -k(2) k(1) 0];
        R = eye(3) + s * K + (1 - c) * (K * K);   % Rodrigues
    end
    M = eye(4);  M(1:3, 1:3) = R;
end

function draw_head(parent, style, v, col, ghost)
% head-fixed geometry (x = forward / nose, y = left, z = up), origin at the
% pivot (~ upper neck). The 2D styles draw view-specific outlines: in the
% x-z plane for the side view (v = 1), in the y-z plane for the front view
% (v = 2); tilt about the other axis then shows as foreshortening.
% ghost = dashed grey outline only (standing posture).
    if ghost
        lo = {'Color', col, 'LineStyle', '--', 'LineWidth', 1};
    else
        lo = {'Color', col * 0.6, 'LineWidth', 2.5};
    end
    gz = {'Color', col * 0.6, 'LineStyle', '--', 'LineWidth', 1.5};   % gaze line
    switch style
        case 'stick'
            a = linspace(0, 2*pi, 80);  r = 0.55;  zc = 0.75;
            ln(parent, v, r * cos(a), r * sin(a) + zc, lo{:});
            if ghost; return; end
            if v == 1
                ln(parent, v, [0.52 0.75 0.52], [zc+0.1 zc-0.08 zc-0.12], lo{:});   % nose
                dot2(parent, v, 0.3, zc + 0.15, 0.06, col * 0.4);                    % eye
                ln(parent, v, [0.6 1.9], [zc+0.15 zc+0.15], gz{:});
            else
                dot2(parent, v, [-0.2 0.2], [zc+0.15 zc+0.15], 0.06, col * 0.4);   % eyes
                ln(parent, v, [0 0], [zc+0.05 zc-0.1], lo{:});                      % nose
                ln(parent, v, [-0.18 0.18], [zc-0.28 zc-0.28], lo{:});              % mouth
                for sg = [-1 1]
                    ln(parent, v, sg * [0.55 0.66 0.55], zc + [0.14 0 -0.14], lo{:});   % ears
                end
            end
        case 'profile'
            if v == 1   % side profile facing right: back of head over the top, face, neck
                th = linspace(3.98, 0.35, 60)';
                S = [0.82 * cos(th) - 0.05, 0.85 * sin(th) + 0.95;
                     0.80 1.02; 0.84 0.88; 0.82 0.80; 1.00 0.62; 0.86 0.55; 0.88 0.45;
                     0.82 0.38; 0.86 0.28; 0.75 0.10; 0.45 0.00; 0.30 -0.25; -0.30 -0.25; -0.48 0.25];
            else        % front: face oval
                th = linspace(0, 2*pi, 80)';
                S = [0.68 * cos(th), 0.95 * sin(th) + 0.85];
            end
            if ghost
                ln(parent, v, S([1:end 1], 1), S([1:end 1], 2), lo{:});
                return
            end
            e = linspace(0, 2*pi, 30)';
            pt(parent, v, S(:, 1), S(:, 2), col);
            if v == 1
                pt(parent, v, 0.10 * cos(e) - 0.05, 0.18 * sin(e) + 0.85, col * 0.7);   % ear
                dot2(parent, v, 0.62, 1.0, 0.06, [0.15 0.15 0.15]);                       % eye
                ln(parent, v, [0.9 1.9], [1.0 1.0], gz{:});
            else
                for sg = [-1 1]
                    pt(parent, v, sg * 0.70 + 0.07 * cos(e), 0.2 * sin(e) + 0.85, col * 0.7);   % ears
                end
                dot2(parent, v, [-0.25 0.25], [1.0 1.0], 0.07, [0.15 0.15 0.15]);   % eyes
                ln(parent, v, [0 0.05 -0.05], [0.9 0.6 0.6], 'Color', col * 0.5, 'LineWidth', 1.5);   % nose
                ln(parent, v, [-0.2 0.2], [0.35 0.35], 'Color', col * 0.5, 'LineWidth', 1.5);         % mouth
            end
        case 'box'
            [V, F] = cuboid([-0.55 0.55], [-0.45 0.45], [0.1 1.4]);
            if ghost
                patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceColor', 'none', ...
                    'EdgeColor', col, 'LineStyle', '--');
                return
            end
            fc = repmat(col, 6, 1);
            fc(2, :) = col * 0.45;   % +x = face side
            fc(6, :) = col * 0.8;    % top
            patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceVertexCData', fc, ...
                'FaceColor', 'flat', 'EdgeColor', col * 0.4, 'LineWidth', 1.5);
            plot3([0.55 1.9], [0 0], [0.85 0.85], 'Parent', parent, gz{:});
        otherwise
            error('unknown style ''%s'' (stick / profile / box)', style);
    end
end

function draw_body(ax, style, v)
% static neck + shoulders, grey (never moves: only the head is measured)
    g = [0.78 0.78 0.78];
    if strcmp(style, 'profile')
        if v == 1
            pt(ax, v, [-0.30 0.30 0.35 0.60 0.65 -0.75 -0.60 -0.30], [0 0 -0.6 -0.9 -2.3 -2.3 -0.9 -0.6], g);
        else
            pt(ax, v, [-0.3 0.3 0.3 1.3 1.5 1.45 -1.45 -1.5 -1.3 -0.3], ...
                [0 0 -0.55 -0.75 -1.0 -2.3 -2.3 -1.0 -0.75 -0.55], g);
        end
    else
        lo = {'Color', g * 0.8, 'LineWidth', 4};
        ln(ax, v, [0 0], [0.2 -1.9], lo{:});                                  % neck + trunk
        if v == 1
            ln(ax, v, [0 0.15 0.3], [-0.6 -1.3 -1.85], lo{:});               % arm
        else
            ln(ax, v, [-1.2 -1 1 1.2], [-1.75 -0.55 -0.55 -1.75], lo{:});       % shoulders + arms
        end
    end
end

function ln(parent, v, a, z, varargin)
% line in the view plane: a = forward (side view) or left (front view)
    a = a(:);  z = z(:);  o = zeros(size(a));
    if v == 1
        plot3(a, o, z, 'Parent', parent, varargin{:});
    else
        plot3(o, a, z, 'Parent', parent, varargin{:});
    end
end

function pt(parent, v, a, z, col)
% filled polygon in the view plane
    a = a(:);  z = z(:);  o = zeros(size(a));
    if v == 1
        patch(a, o, z, col, 'Parent', parent, 'EdgeColor', 'none');
    else
        patch(o, a, z, col, 'Parent', parent, 'EdgeColor', 'none');
    end
end

function dot2(parent, v, a, z, r, col)
    th = linspace(0, 2*pi, 20);
    for k = 1:numel(a)
        pt(parent, v, a(k) + r * cos(th), z(k) + r * sin(th), col);
    end
end

function [V, F] = cuboid(xr, yr, zr)
% vertex index = 1 + (x hi) + 2 (y hi) + 4 (z hi); faces -x +x -y +y -z +z
    [X, Y, Z] = ndgrid(xr, yr, zr);
    V = [X(:) Y(:) Z(:)];
    F = [1 3 7 5; 2 4 8 6; 1 2 6 5; 3 4 8 7; 1 2 4 3; 5 6 8 7];
end

% ---- signal helpers (base MATLAB only) -------------------------------------

function u = up_vector(eul_deg)
% earth-vertical expressed in the sensor frame: 3rd row of
% R = Rz(yaw) Ry(pitch) Rx(roll); independent of yaw.
    r = eul_deg(:, 1); p = eul_deg(:, 2);
    u = [-sind(p), cosd(p) .* sind(r), cosd(p) .* cosd(r)];
end

function u = lowpass_unit(u, t, fs, fc, gap_s)
% zero-phase 2nd-order Butterworth low-pass on the unit-vector components
% (not on angles -- no wrap-around issues), separately for each gap-free
% stretch, renormalised. Same result as butter(2, fc/(fs/2)) + filtfilt,
% without the Signal Processing Toolbox.
    K = tan(pi * fc / fs);
    n = 1 / (1 + sqrt(2) * K + K^2);
    b = [K^2, 2 * K^2, K^2] * n;
    a = [1, 2 * (K^2 - 1) * n, (1 - sqrt(2) * K + K^2) * n];
    brk = [0; find(diff(t(:)) > gap_s); numel(t)];
    for s = 1:numel(brk) - 1
        idx = brk(s) + 1 : brk(s + 1);
        if numel(idx) > 27                      % as filtfilt: > 3 x padding length
            u(idx, :) = filtfilt0(b, a, u(idx, :), 6);   % 6 = filtfilt's padding for 2nd order
        end
    end
    u = u ./ vecnorm(u, 2, 2);
end

function y = filtfilt0(b, a, x, np)
% forward-backward filtering with odd reflection padding of np samples
% (column-wise), filter states started at the first padded value
    xp = [2 * x(1, :) - x(np+1:-1:2, :); x; 2 * x(end, :) - x(end-1:-1:end-np, :)];
    zi = ((eye(2) - [-a(2:3)' [1; 0]]) \ (b(2:3)' - a(2:3)' * b(1)));   % steady-state for unit step
    y = filter(b, a, xp, zi * xp(1, :));
    y = flipud(filter(b, a, flipud(y), zi * y(end, :)));
    y = y(np+1:end-np, :);
end
