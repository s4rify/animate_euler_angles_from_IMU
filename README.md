# animate_euler_angles_from_IMU
Use IMU Euler angles provided by a gyroscope sensor placed at the head and use these angles to animate the head movement. Animation is being rendered as video and replayed at 8x playback speed on default.

## Files

| File | What it does |
|---|---|
| `animate_head_posture.m` | The animation: two conditions side by side (side + front view, tilt time courses). Input: one N x 3 matrix of Euler angles `[roll pitch yaw]` (deg) per condition, optional standing baseline. Base MATLAB only. `help animate_head_posture` lists all options. |
| `example_animate_head_posture.m` | Runs the animation on `example_data/` (still frames + video in `output/`). |
| `example_data/` | Anonymised example: 120 s of walking with a Go/No-Go task, 120 s of walking only, and two 8-s standing phases, 60 Hz. Columns `time_s, roll_deg, pitch_deg, yaw_deg`. |
| `xdf_to_example_data.m` | Converts an XDF recording (Movella DOT stream + Presentation marker stream) into the `example_data/` CSV structure. Needs [`load_xdf`](https://github.com/xdf-modules/xdf-Matlab) on the path. |

## Quick start

```matlab
% example data
example_animate_head_posture

% your own recording: XDF -> CSV (same structure as example_data/)
xdf_to_example_data('my_recording.xdf', 'my_data')
xdf_to_example_data('my_recording.xdf', 'my_data_phone', 'cond1', 'phone', 'label1', 'phone')
```

Then load the CSVs and call `animate_head_posture` as `example_animate_head_posture.m` does (adjust `data_dir` and the file names there).

The sensor-mount convention (default: sensor y-axis towards the nose) is set with `'forward_axis'` in `animate_head_posture`.
