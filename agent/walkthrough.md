# Walkthrough - Docker Compose Configuration

The implementation of Docker Compose for running the HBOT simulation, SLAM, and Nav2 navigation stack is complete.

---

## 🛠️ Changes Implemented

### 🐳 Docker Configuration

1. **[Dockerfile](file:///home/huy/Documents/03.MyProjects/hbot_ws/docker/laptop/Dockerfile)**
   * Upgraded to copy the workspace metadata (`src` package directories) inside the build context to execute `rosdep update && rosdep install` during the Docker image build phase.
   * This caches all system and ROS dependencies (including navigation, SLAM, and Gazebo plugins) so they do not have to download on every container startup.

2. **[docker-compose.yaml](file:///home/huy/Documents/03.MyProjects/hbot_ws/docker/laptop/docker-compose.yaml)**
   * Created inside the `docker/laptop` folder.
   * Configured for GPU-accelerated X11 forwarding mapping `/dev/dri`, `${XAUTHORITY}`, and `/tmp/.X11-unix`.
   * Set network mode to `host` and IPC mode to `host` for zero-overhead ROS 2 DDS communication.
   * Added parameter configuration through default environment variables (`SIMULATION_MODE`, `SLAM`, `ENABLE_NAVIGATION`, `RUN_RVIZ`).
   * Configured volume mounts for mounting the workspace source files and using isolated anonymous volumes for `build`, `install`, and `log`.

### 📖 Documentation

3. **[README.md](file:///home/huy/Documents/03.MyProjects/hbot_ws/docker/laptop/README.md)**
   * Created inside `docker/laptop` to serve as a user guide.
   * Outlines steps to grant X11 access on the host (`xhost +local:root`), build, run, clean up, and execute commands within the running container.

### 🐛 Bug Fixes

4. **[hbot_description/package.xml](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_description/package.xml) & [hbot_simulation/package.xml](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_simulation/package.xml)**
   * Changed the dependency declaration `<exec_depend>rviz</exec_depend>` to `<exec_depend>rviz2</exec_depend>` in both packages. The older `rviz` key belongs to ROS 1 and could not be resolved by `rosdep` under ROS 2 Humble, which threw build errors.

---

## 🧪 Validation & Verification

1. **Syntax Validation**: We successfully verified the `docker-compose.yaml` syntax by running `docker compose config` inside the `docker/laptop` directory. The configuration parser confirmed the correctness of build context, volumes, X11 variables, and device mappings.
2. **Build Success**: Executed `docker compose build` inside the `./docker/laptop` directory. The image successfully compiled in 187.6 seconds, resolving and installing all system dependencies correctly via `rosdep` and creating the `hbot_laptop:latest` Docker image.
3. **Interactive Debugging**: Configured `ROS_DOMAIN_ID` and `CONTROLLER` as environment variables directly in `docker-compose.yaml`. This ensures that interactive bash shells entered via `docker exec -it` inherit these variables and can immediately see and inspect running nodes (e.g. via `ros2 node list`).

---

## 🚀 Quick Run Guide

To start the simulation on your laptop:

1. **Authorize X11 on the host**:
   ```bash
   xhost +local:root
   ```
2. **Build and start the container**:
   ```bash
   cd docker/laptop
   docker compose build
   docker compose up
   ```
3. **Customize parameters** (optional):
   ```bash
   SLAM=False docker compose up
   ```

---

# Walkthrough: Robot Web Dashboard (hbot_web)

We created and compiled the `hbot_web` ROS 2 package. This package provides a premium, responsive, dark-themed dashboard to drive the robot, monitor hardware telemetry, and manage WiFi modes.

## Created Structure

The new package is fully integrated into the ROS 2 workspace.

- **Package Configuration**:
  - [package.xml](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/package.xml): Declares dependencies on standard ROS 2 messaging/nodes and execution dependencies (`python3-flask`, `python3-flask-socketio`, `python3-psutil`, `python3-eventlet`).
  - [setup.py](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/setup.py) & [setup.cfg](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/setup.cfg): Installs the executable entrypoint `web_node` and packs template/static files.
- **Backend Node**:
  - [web_node.py](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/hbot_web/web_node.py): Runs a multi-threaded Flask-SocketIO server, manages publisher to `/cmd_vel`, subscribers to `/battery/*` topics, gathers hardware statistics, and calls `nmcli` to interface with NetworkManager.
- **Frontend Dashboard**:
  - [index.html](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/hbot_web/templates/index.html): Responsive glassmorphic container layout.
  - [style.css](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/hbot_web/static/css/style.css): Neon theme variables, animations, custom sliders, gauges, and modal styles.
  - [main.js](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_web/hbot_web/static/js/main.js): Integrates the HTML5 canvas joystick, keyboard mapping, Socket.io data binding, and WiFi connection modals.

---

## Deployment & Verification on Raspberry Pi

Follow these steps to deploy and start the dashboard on your robot:

### Step 1: Sync to Raspberry Pi
Since we have successfully compiled the package using Docker (`linux/arm64`), you can sync the compiled build outputs and scripts to your Pi:
```bash
./sync_to_pi.sh root hbot.local
```

Next, copy the systemd service file from your laptop to the Pi workspace:
```bash
scp hbot_web.service root@hbot.local:/root/hbot_ws/
```

### Step 2: SSH into the Pi
```bash
ssh root@hbot.local
```

### Step 3: Launch Driver & Web Dashboard in the Background

> [!IMPORTANT]
> The node requires `flask`, `flask-socketio`, `psutil`, and `eventlet` in the Python environment where it is run.
> - **If running directly on the Raspberry Pi host (outside Docker)**, make sure to install them first:
>   ```bash
>   sudo apt update && sudo apt install -y python3-flask python3-flask-socketio python3-psutil python3-eventlet
>   ```
> - **If running inside a Docker container on the Pi**, make sure to rebuild the Docker image to include the dependencies we added to [Dockerfile](file:///home/huy/Documents/03.MyProjects/hbot_ws/docker/pi/Dockerfile):
>   ```bash
>   docker compose -f docker/pi/docker-compose.yaml build --no-cache
>   ```

Sourcing the workspace install and launching both `hbot_driver` and `hbot_web` in the background:

#### Option A: Running as a systemd service (Recommended)
A `hbot_web.service` configuration file has been created to handle automatic startup, logging, and restarts on the Pi:
1. **Copy the service file** to the systemd folder:
   ```bash
   sudo cp /root/hbot_ws/hbot_web.service /etc/systemd/system/
   ```
2. **Reload systemd and enable the service** (to run automatically at boot):
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable hbot_web.service
   ```
3. **Start the service**:
   ```bash
   sudo systemctl start hbot_web.service
   ```
4. **Monitor logs live**:
   ```bash
   journalctl -u hbot_web.service -f
   ```
5. **Stop the service**:
   ```bash
   sudo systemctl stop hbot_web.service
   ```

#### Option B: Running via manual background script
Alternatively, launch the script in the background:
```bash
nohup ./scripts/web_bringup.sh > log/web_bringup.log 2>&1 &
```
- To monitor logs live:
  ```bash
  tail -f log/web_bringup.log
  ```
- To stop the background nodes manually:
  ```bash
  pkill -f web_node
  pkill -f hbot_driver
  ```

### Step 4: Access and Test the Dashboard
1. Open a browser and navigate to `http://<pi_ip>` (e.g., `http://192.168.1.100` or `http://hbot.local`).
2. **Teleoperation**: Drive the robot using WASD or touch-dragging the on-screen joystick. Observe the `/cmd_vel` output:
   ```bash
   ros2 topic echo /cmd_vel
   ```
3. **Telemetry**: Check if CPU/RAM/Disk stats are updated. Launch the robot driver (which publishes `/battery/voltage` and `/battery/percent`) and verify the battery widget.
4. **WiFi Management**:
   - Switch between **STA** and **AP** modes using the operation toggle.
   - Scan for surrounding networks, click one, and enter the password to connect.
   - Use the **Refresh** button under Saved Connections to view connections stored in NetworkManager, and test deleting/quick-reconnecting to them.

---

## 🛠️ Troubleshooting

### `AttributeError: can't set attribute 'session'`
If you see this traceback error in the terminal when the web interface connects, there is a package version mismatch (e.g. newer `Flask 3.x` from pip alongside older `Flask-SocketIO` from apt). 

To resolve this conflict and restore web dashboard metrics:
- **If running directly on the Raspberry Pi host (outside Docker)**, run:
  ```bash
  python3 -m pip install --upgrade flask flask-socketio
  ```
- **If running inside a Docker container on the Pi**, you can rebuild the container or run pip upgrade inside the container to ensure matching versions.

---

## 🧭 PID Calibration Script Fix & Driver Safety/Smoothing Updates (2026-08-18)

### 🐛 Bug Fixes
1. **[calibrate_pid.py](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_driver/test/calibrate_pid.py)**
   * The file had two `plot_matplotlib()` definitions; the second (which wins, since Python keeps the last redefinition) indexed `s['m3_rpm']` / `s['m4_rpm']` on each sample dict. `run_step_test()` only ever collects `time`, `target`, `m1_rpm`, `m2_rpm` (this is a 2-motor diff-drive robot, no M3/M4 telemetry), so `--plot` / interactive option `[5]` crashed with `KeyError`.
   * Removed the dead duplicate definition and rewrote the surviving one to only plot M1/M2.
   * Fixed `export_csv()`'s `fieldnames` (`target_rpm`→`target`, dropped `m3_rpm`/`m4_rpm`) to match the actual sample dict keys — was silently writing empty/misaligned CSV columns rather than crashing (wrapped in try/except).
   * Note: `hbot_driver` is a submodule — this fix needs to be committed/pushed inside its own repo separately.

### 🛠️ Changes Implemented

2. **cmd_vel watchdog** — [hbot_driver_yahboom_node.cpp](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_driver/src/hbot_driver_yahboom_node.cpp)
   * Added `cmd_vel_timeout` parameter (default `0.5s`, in [hbot_driver/config/params.yaml](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_driver/config/params.yaml) and [hbot_bringup/config/yahboom_driver_params.yaml](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_bringup/config/yahboom_driver_params.yaml)).
   * `cmdVelCallback` now records `last_cmd_vel_time_`. A new wall timer (`cmdVelWatchdogCallback`, firing at `cmd_vel_timeout/5`) checks elapsed time since the last `cmd_vel` message and zeroes the motors once it exceeds the timeout, logging a warning. Guarded by a `cmd_vel_stopped_` flag so it only issues the stop command once per timeout event (not spammed every tick), and resets on the next real `cmd_vel` message. Prevents the robot coasting on a stale command forever if the publisher (teleop browser tab, Nav2, etc.) dies or the network drops.
   * Verified with `./build_packages.sh hbot_driver_yahboom` — builds clean (only pre-existing unrelated `write()` return-value warnings in `rosmaster.cpp`).

3. **Teleop cmd_vel through velocity_smoother** — [base_bringup.launch.py](file:///home/huy/Documents/03.MyProjects/hbot_ws/src/hbot_bringup/launch/base_bringup.launch.py)
   * `hbot_web`'s `web_node` now publishes teleop commands on `cmd_vel_teleop` (via its existing `cmd_vel_topic` parameter) instead of `cmd_vel` directly.
   * Added a `nav2_velocity_smoother` node (remapped `cmd_vel`→`cmd_vel_teleop` in, `cmd_vel_smoothed`→`cmd_vel` out) plus its own `lifecycle_manager_smoother` (autostart) so it activates standalone, since `base_bringup.launch.py` doesn't otherwise bring up Nav2's lifecycle manager.
   * Reuses the existing `velocity_smoother` block in `nav2_params.yaml` (new `smoother_params_file` launch arg, defaults there) so teleop and Nav2-driven motion get identical rate/accel limiting — no duplicated tuning source of truth. Explicitly overrides `use_sim_time: False` on top of the yaml (which defaults it `True` for the sim/Nav2 case) since this launch file only runs on real hardware.
   * Verified by executing `generate_launch_description()` directly — builds without error (9 actions: 4 launch args + driver, web, smoother, lifecycle manager, EKF).

---

## 2026-08-19: Nav2 local controller swapped to RPP + narrow-corridor costmap tuning

Changed [`src/hbot_bringup/config/nav2_params.yaml`](../src/hbot_bringup/config/nav2_params.yaml):

- **Robot footprint corrected**: `local_costmap`/`global_costmap` previously used a leftover
  TurtleBot3-Waffle `robot_radius: 0.22` circle. HBOT's real footprint comes from
  `base_length: 0.17` (`hbot_description`) and `wheel_track: 0.2` +
  `wheel_width: 0.025` (`yahboom_driver_params.yaml`), giving a ~0.17m x 0.225m
  rectangle. Replaced `robot_radius` with an explicit rectangular
  `footprint: "[[0.09, 0.12], [0.09, -0.12], [-0.09, -0.12], [-0.09, 0.12]]"`
  (padded slightly to 0.18m x 0.24m, `footprint_padding: 0.01`) on both costmaps —
  inscribed radius 0.09m, circumscribed radius 0.15m. A circular footprint can't
  fit through gaps the actual (narrower) rectangle would clear when
  traveling straight through them.
- **`controller_server.FollowPath`**: replaced `dwb_core::DWBLocalPlanner` with
  `nav2_regulated_pure_pursuit_controller::RegulatedPurePursuitController` (RPP),
  with lookahead distances (0.25-0.5m) and speed (`desired_linear_vel: 0.2`)
  scaled down for this robot's small footprint, and regulated/cost-based
  velocity scaling enabled so it slows down instead of clipping walls in tight
  corridors.
- **`inflation_layer`** (both costmaps): `cost_scaling_factor` raised
  3.0 -> 8.0 and `inflation_radius` reduced 0.55 -> 0.12, so a corridor with
  only ~0.10m clearance on each side of the robot doesn't get inflated into a
  blanket high-cost/no-go zone. `FollowPath.inflation_cost_scaling_factor` is
  kept in sync (8.0) with the costmap's `cost_scaling_factor`.

**Not changed / flagged for follow-up**: `hbot_description`'s
`hbot.urdf.xacro` still computes `wheel_separation` as
`base_width (0.14) + 2 * wheel_ygap (0.015) = 0.17m`, which no longer matches
the driver's actual `wheel_track: 0.2`. This only affects simulated
odometry/footprint visuals (Gazebo diff-drive plugin + RViz), not the real
robot (the driver already uses 0.2m for real odometry) — left untouched
pending confirmation this should be updated too.

**Not yet validated**: no sim/hardware run performed against these values;
per `PHASE0_RUNBOOK.md` baseline acceptance, this should be exercised with
`slam:=True enable_navigation:=True` and a real narrow-corridor test before
being considered final.

---

## 2026-08-20: Fixed Nav2 not accepting goals — `velocity_smoother` node name collision

**Symptom**: after starting SLAM/navigation mode from the web dashboard,
publishing a goal (from RViz or the dashboard) produced *no* reaction and no
log output at all — not even a planning failure.

**Root cause** (found via the actual `log/navigation_<>.log`, not the
nav2_params.yaml tuning from the entry above): [base_bringup.launch.py](../src/hbot_bringup/launch/base_bringup.launch.py)
(run permanently by `hbot_web.service`) brings up its own
`nav2_velocity_smoother` node named `velocity_smoother` to rate-limit teleop
`cmd_vel_teleop` -> `cmd_vel` (added 2026-08-19, walkthrough entry above).
When the dashboard then starts `hbot_bringup.launch.py`'s Nav2 stack on
demand, `nav2_bringup`'s `navigation_launch.py` brings up *another* node also
named `velocity_smoother`. Two lifecycle nodes with the same fully-qualified
name collide on their `/velocity_smoother/change_state` service name; the new
`lifecycle_manager_navigation`'s `configure` request was landing on the
already-`active` teleop instance, which can't take that transition and fails
instantly with no exception text:
```
[lifecycle_manager_navigation] [ERROR] Failed to change state for node: velocity_smoother
[lifecycle_manager_navigation] [ERROR] Failed to bring up all requested nodes. Aborting bringup.
```
`velocity_smoother` is last in Nav2's managed-node list, so `controller_server`,
`planner_server`, and `bt_navigator` all *configure* successfully but the whole
chain aborts before the *activate* phase ever runs for anyone — `bt_navigator`'s
`goal_pose` subscription exists but nothing behind it is active, so goals
vanish silently. Confirmed by building `nav2_velocity_smoother` locally and
reproducing the identical failure signature with two same-named instances.

**Fix** — [base_bringup.launch.py](../src/hbot_bringup/launch/base_bringup.launch.py):
- Renamed the always-on teleop smoother node `velocity_smoother` ->
  `teleop_velocity_smoother`, and its `lifecycle_manager_smoother`'s
  `node_names` to match, so it can never collide with Nav2's own
  `velocity_smoother`.
- Since ROS 2 params files match a node's block by its node name, the plain
  `nav2_params.yaml` (still shared with Nav2's tuning as the single source of
  truth) would no longer match a node named `teleop_velocity_smoother`. Wrapped
  it in `nav2_common.launch.RewrittenYaml` with
  `key_rewrites={'velocity_smoother': 'teleop_velocity_smoother'}` so the
  renamed node still resolves the same tuned block at launch time.
- Verified locally: built `nav2_velocity_smoother` for this dev machine,
  launched it as `teleop_velocity_smoother` against the rewritten params, and
  confirmed both that it configures cleanly (no collision) and that
  `ros2 param get` reports the tuned values (`max_velocity: [0.26, 0.0, 1.0]`,
  `max_accel: [1.0, 0.0, 2.2]`), not the library defaults — i.e. the rename
  didn't silently drop its tuning.

---

## 2026-08-20: `cmd_vel` arbitration between teleop and Nav2 via twist_mux

**Symptom**: follow-up to the name-collision fix above. Renaming the teleop
smoother fixed Nav2 goal reception, but surfaced a second, pre-existing issue:
both `teleop_velocity_smoother` (always-on, in
[base_bringup.launch.py](../src/hbot_bringup/launch/base_bringup.launch.py))
and Nav2's own `velocity_smoother` (only alive while navigation/SLAM mode is
running, from the vendored `navigation2` submodule's `navigation_launch.py`)
were both remapping their smoothed output straight onto the same final
`cmd_vel` topic — the one topic
[hbot_driver_yahboom_node.cpp](../src/hbot_driver/src/hbot_driver_yahboom_node.cpp)
actually subscribes to (unremapped, with its own 0.5s `cmd_vel_timeout`
watchdog). No arbitration existed between the two publishers.

**Root cause / risk**: read `nav2_velocity_smoother`'s `smootherTimer()`
source — its wall timer only stays silent if it has *never* received a
command that session (`if (!command_) return;`); once the teleop smoother has
seen any joystick input, it keeps firing (and publishing) at
`smoothing_frequency` indefinitely. So a teleop smoother that had been touched
earlier in the session could keep intermittently overriding/zeroing Nav2's
autonomous driving output any time both were alive together, with outcome
depending on DDS publish ordering — not itself blocking Nav2 like the name
collision did, but a real correctness/safety gap once both are running side
by side.

**Fix**:
- [base_bringup.launch.py](../src/hbot_bringup/launch/base_bringup.launch.py):
  `teleop_velocity_smoother`'s output remap changed from
  `('cmd_vel_smoothed', 'cmd_vel')` to
  `('cmd_vel_smoothed', 'cmd_vel_teleop_smoothed')`. Added a `twist_mux` node
  (new `<exec_depend>twist_mux</exec_depend>` in
  [package.xml](../src/hbot_bringup/package.xml), resolved on the Pi via the
  existing `rosdep install` step in `docker/pi/Dockerfile` — no Dockerfile
  change needed) remapped `cmd_vel_out` -> `cmd_vel`, so it's now the sole
  publisher of the final `cmd_vel`.
- [hbot_bringup.launch.py](../src/hbot_bringup/launch/hbot_bringup.launch.py):
  rather than hand-editing the vendored `navigation2` submodule's
  `navigation_launch.py`, wrapped its `IncludeLaunchDescription` in
  `bringup_cmd_group` with a `launch_ros.actions.SetRemap('cmd_vel_smoothed',
  'cmd_vel_nav_smoothed')` — this overrides the included file's
  `velocity_smoother` node's own hardcoded `('cmd_vel_smoothed', 'cmd_vel')`
  remap from outside, without touching the submodule.
- New [config/twist_mux.yaml](../src/hbot_bringup/config/twist_mux.yaml):
  `teleop` topic `cmd_vel_teleop_smoothed` at priority 100, `navigation` topic
  `cmd_vel_nav_smoothed` at priority 10 — touching the joystick always
  overrides autonomous driving. Both use a 0.5s timeout (matching
  `hbot_driver`'s own `cmd_vel_timeout` watchdog default) so an idle source
  stops blocking the other; the driver's watchdog remains the final backstop
  if both go silent.
- Updated [workspace_overview.md](workspace_overview.md) to describe the new
  `cmd_vel_teleop_smoothed` / `cmd_vel_nav_smoothed` / `twist_mux` flow.

**Verified**:
- Confirmed the `SetRemap`-through-`IncludeLaunchDescription` mechanism
  empirically before relying on it: a minimal `GroupAction([SetRemap(...),
  IncludeLaunchDescription(...)])` around a `demo_nodes_cpp` talker with its
  own hardcoded remap of the same topic showed the outer `SetRemap` wins —
  `ros2 topic info` showed the talker publishing only on the renamed topic.
- Ran `generate_launch_description()` directly for both
  `base_bringup.launch.py` (11 actions, including a `twist_mux` node) and
  `hbot_bringup.launch.py` (19 actions; confirmed `bringup_cmd_group`
  contains `SetRemap` immediately before the `navigation_launch.py`
  `IncludeLaunchDescription`) — both build without error.
- Not yet run on real hardware — should be exercised with navigation active
  and the joystick touched mid-autonomous-drive to confirm the priority
  override behaves as expected before considered final.


---

## 2026-08-21: Launch mapping/navigation from scripts + build/bringup robustness fixes

- [scripts/web_bringup.sh](../scripts/web_bringup.sh): launches `base_bringup.launch.py`
  with `use_ekf:=False` — EKF was found not to help (see 2026-08-18 testing
  notes above) so it's disabled in the production Pi bringup for now.
- [hbot_web/web_node.py](../src/hbot_web/hbot_web/web_node.py)'s `ROSLaunchManager`
  no longer builds `ros2 launch hbot_bringup hbot_bringup.launch.py ...` command
  strings inline. `start_mapping_mode()` / `start_navigation_mode()` now shell out
  to new [start_mapping.sh](../src/hbot_web/hbot_web/scripts/start_mapping.sh) /
  [start_navigation.sh](../src/hbot_web/hbot_web/scripts/start_navigation.sh),
  installed via `hbot_web/setup.py`'s `package_data`. Each script logs its own
  run to a timestamped file under `~/hbot_ws/log/` (`mapping_<datetime>.log` /
  `navigation_<datetime>.log`), separate from `web_bringup.log`, making it
  easier to pull logs for a specific mapping/navigation session instead of
  grepping the always-on dashboard log.
- [build_packages.sh](../build_packages.sh) / [build_packages_pi.sh](../build_packages_pi.sh):
  self-source `/opt/ros/humble/setup.bash` if `AMENT_PREFIX_PATH` isn't already
  set in the shell, instead of failing deep inside CMake with an opaque error.
  This was silently breaking when building via `docker exec` into a running
  container, which bypasses the image's `ENTRYPOINT` (where ROS 2 is normally
  sourced) — `docker compose up`/`run` were unaffected since those do go
  through the entrypoint.

---

## 2026-08-21: Web dashboard — Nav2 "Set Goal" tool + global path overlay

- [hbot_web/web_node.py](../src/hbot_web/hbot_web/web_node.py): adds a
  `goal_pose` publisher (`geometry_msgs/PoseStamped`) and a `plan` subscriber
  (`nav_msgs/Path`, Nav2's global plan). The new `goal_pose_cmd` Socket.IO
  handler takes `{x, y, yaw}` from the browser, converts `yaw` to a quaternion,
  and publishes it on `goal_pose` for `bt_navigator` to pick up. `plan_callback`
  re-emits each plan update to the browser as `plan_status` (a simple list of
  `{x, y}` points) for the map overlay below. Switching workflow mode now also
  emits an empty `plan_status` to clear any stale path from a previous
  navigation session.
- [templates/index.html](../src/hbot_web/hbot_web/templates/index.html) /
  [static/js/main.js](../src/hbot_web/hbot_web/static/js/main.js): new
  "Set Goal" map tool button, reusing the existing click-and-drag
  orientation-arrow interaction from "2D Pose Estimate" (`dragStart`/`dragEnd`)
  but rendered in orange and publishing to `goal_pose_cmd` instead of
  `initialpose_cmd`. The two tools are mutually exclusive (activating one
  deactivates the other) and "Set Goal" is guarded to only work in Navigation
  mode. `drawMap()` now also strokes the live `plan_status` points as an
  orange path overlay on the map canvas, and the overlay/tool state is reset
  whenever the workflow mode leaves `navigation`.

---

## 2026-08-24: YDLidar X3 Pro added alongside LDS-01, selectable via LIDAR_MODEL

- User added `src/lidars/ydlidar_ros2_driver-master` (ROS 2 driver for the
  YDLidar family) and `src/YDLidar-SDK-master` (the underlying C++ SDK it
  `find_package()`s) as plain directories, not submodules - they aren't in
  `.gitmodules`.
- [hbot_bringup.launch.py](../src/hbot_bringup/launch/hbot_bringup.launch.py):
  the previously-hardcoded lidar `IncludeLaunchDescription` (the LDS-01 via
  `hls_lfcd_lds_driver`, with a commented-out LDS-006 alternative) is now
  chosen by a new `LIDAR_MODEL` env var, following the same
  `os.environ.get(...)` pattern as the existing `CONTROLLER` var.
  `LIDAR_MODEL=lds01` (default, unset behaves the same as before) keeps the
  LDS-01; `LIDAR_MODEL=ydlidar_x3` includes `ydlidar_ros2_driver`'s
  `x3_ydlidar_launch.py` instead. [scripts/bringup.sh](../scripts/bringup.sh)
  exports `LIDAR_MODEL` with the same default-if-unset pattern used for
  `CONTROLLER`.
- [x3_ydlidar_launch.py](../src/lidars/ydlidar_ros2_driver-master/launch/x3_ydlidar_launch.py):
  fixed to build/run on Humble - it used a `LifecycleNode` with pre-Foxy
  launch_ros kwargs (`node_executable`/`node_name`/`node_namespace`, renamed
  to `executable`/`name`/`namespace` since Foxy) that no longer exist on
  Humble's launch_ros API. Rewritten as a plain `Node`, which also matches
  what `ydlidar_ros2_driver_node.cpp` actually is - a plain `rclcpp::Node`
  that starts scanning as soon as it comes up, not a real lifecycle-managed
  node. Left out the file's commented `static_transform_publisher` for the
  `laser` frame, for the same reason the LDS-01 include doesn't add one:
  `hbot_description`'s URDF already defines `base_link -> laser`, published
  by `robot_state_publisher`.
- `src/YDLidar-SDK-master` is a bare CMake project (no `package.xml`);
  `colcon list` still picks it up as a `(cmake)`-type package named
  `ydlidar_sdk` purely from its `CMakeLists.txt`. Tried building
  `ydlidar_sdk`+`ydlidar_ros2_driver` together via `build_packages.sh` -
  colcon has no declared dependency between them (the SDK carries no
  `package.xml` to express one) so it builds both in parallel and
  `ydlidar_ros2_driver`'s `find_package(ydlidar_sdk)` fails the race.
  Per user direction, the SDK is meant to be built as a standalone C++
  library instead (`cmake && make && sudo make install` from
  `src/YDLidar-SDK-master`, installing `ydlidar_sdkConfig.cmake` system-wide
  the way its own build instructions intend), not through colcon - added
  `src/YDLidar-SDK-master/COLCON_IGNORE` so colcon skips it entirely and the
  race can't happen. This system-wide SDK install step hasn't been run yet
  (needs interactive `sudo`); `ydlidar_ros2_driver` won't colcon-build until
  it has been.

- Follow-up: `ydlidar_ros2_driver` now builds clean. Two things changed since
  the previous entry:
  - You reorganized the lidar drop from `src/lidars/ydlidar_ros2_driver-master`
    + `src/YDLidar-SDK-master` into a single nested repo
    `src/ydlidar_x3/` (with `ydlidar_ros2_driver/` and `YDLidar-SDK-master/`
    inside, one commit `c7ff9a9`) and installed the SDK system-wide
    (`/usr/local/lib/cmake/ydlidar_sdk/...`) - `ydlidar_ros2_driver.launch.py`
    edits from the previous entry carried over intact, and
    `YDLidar-SDK-master/COLCON_IGNORE` came along too so colcon still only
    sees `ydlidar_ros2_driver` (confirmed via `colcon list`).
  - [ydlidar_ros2_driver_node.cpp](../src/ydlidar_x3/ydlidar_ros2_driver/src/ydlidar_ros2_driver_node.cpp):
    fixed 21 call sites of the pattern
    `node->declare_parameter("x"); node->get_parameter("x", var);` - the
    argument-less `declare_parameter(name)` overload existed pre-Foxy but was
    removed from Humble's `rclcpp::Node` API (only overloads that take a
    default value or explicit `ParameterType` remain), so every one of these
    failed to compile with "no matching function for call". Each is now
    `declare_parameter(name, var)`, using the same local variable the very
    next line already read the resolved value into as the default - the file
    already initialized that variable to the same default the old code
    implied, so behavior (including picking up overrides from
    `ydlidar_x3.yaml`) is unchanged. Preserved the file's original CRLF line
    endings + UTF-8 BOM (rewrote via a byte-safe script) so the diff is just
    the 21 changed lines, not a whole-file rewrite.
  - `./build_packages.sh ydlidar_ros2_driver` now finishes clean (only
    pre-existing unused-lambda-parameter warnings, no errors); confirmed
    `ros2 launch ydlidar_ros2_driver x3_ydlidar_launch.py --show-args`
    resolves its default params file correctly post-install.

---

## 2026-08-25: Fixed YDLidar X3 Pro port override being silently dropped

- Bug: editing `ydlidar_x3.yaml`'s `port` had no effect - the driver kept
  binding `/dev/ydlidar` (its hardcoded C++ default) regardless.
- Root cause: `x3_ydlidar_launch.py` declares its own `params_file` launch
  argument (default: its own `ydlidar_x3.yaml`), but
  [hbot_bringup.launch.py](../src/hbot_bringup/launch/hbot_bringup.launch.py)
  *also* declares a top-level `params_file` argument for Nav2 (default:
  `nav2_params.yaml`), earlier in the same function. `LaunchConfiguration`
  names aren't scoped per-include - they're shared across the whole launch
  tree unless reset by a scoped `GroupAction` - and `DeclareLaunchArgument`
  never overwrites an already-set value. So by the time the `ydlidar_x3`
  branch's `IncludeLaunchDescription` reached `x3_ydlidar_launch.py`'s own
  declare, `params_file` was already pinned to `nav2_params.yaml` (from
  earlier in `generate_launch_description()`). The node got
  `nav2_params.yaml` as its params file - which has no
  `ydlidar_ros2_driver_node:` block - so every `declare_parameter(name,
  default)` fell through to the hardcoded default baked into
  `ydlidar_ros2_driver_node.cpp`, silently ignoring `ydlidar_x3.yaml`
  entirely (any of its overrides, not just `port`).
- Fix: the `ydlidar_x3` branch's `IncludeLaunchDescription` now passes
  `launch_arguments={'params_file': .../ydlidar_ros2_driver/params/ydlidar_x3.yaml}`
  explicitly, forcing the correct value before `x3_ydlidar_launch.py`'s own
  declare runs. This is safe from leaking into the Nav2 groups that need
  their own `params_file` (`nav2_params.yaml`) because `hardware_nodes` -
  the `GroupAction` the lidar include lives in - defaults to `scoped=True`,
  so the override doesn't escape the group.
- Verified live on the real robot (`ssh hbot`, `hbot.local`): before the
  fix, `./scripts/bringup.sh ...` logged
  `[CYdLidar] Error, cannot bind to the specified serial port[/dev/ydlidar]`;
  after hot-patching the fixed launch file onto the Pi's `install/` for
  verification, the same command logged
  `[YDLIDAR] Connection established in [/dev/usbttl][115200]` and started
  scanning (firmware/model/serial printed). Along the way, briefly
  suspected a udev mismatch (the Pi has two USB-serial adapters -
  `/dev/ttyUSB0` is CH340 1a86:7523, unrelated to the lidar; the X3 Pro is
  CP2102 10c4:ea60 on `/dev/ttyUSB1`, matched by the pre-existing
  `/etc/udev/rules.d/usbttl.rules` -> `/dev/usbttl`) - that turned out to
  be a timing artifact (X3 Pro wasn't enumerated yet when first checked),
  not a real bug; `/etc/udev/rules.d/usbttl.rules` was untouched.
- **Not yet deployed properly**: the fix was hot-patched directly onto the
  Pi's `install/hbot_bringup/...` via `scp` for live verification only,
  bypassing the normal `docker/pi` build + `sync_to_pi.sh` flow. Source is
  fixed in this repo/submodule; still needs `docker compose build && docker
  compose up` in `docker/pi` (now that the SDK builds into that image, see
  the 2026-08-24 entry) followed by `./sync_to_pi.sh` for a real deploy -
  the hot patch will just get overwritten by the same content then.

---

## 2026-08-25: Consolidated bringup.sh / web_bringup.sh env setup into scripts/ros_env.sh

- [scripts/bringup.sh](../scripts/bringup.sh) and
  [scripts/web_bringup.sh](../scripts/web_bringup.sh) each hand-rolled their
  own ~15-line block setting `ROS_DOMAIN_ID`/`CONTROLLER`/`LIDAR_MODEL`,
  `PATH`/`AMENT_PREFIX_PATH`/`CMAKE_PREFIX_PATH`, `PYTHONPATH`, and sourcing
  ROS + the workspace `install/setup.bash`. They'd already drifted out of
  sync in two ways: `LIDAR_MODEL` only existed in `bringup.sh` (`web_bringup.sh`
  never exported it), and only `web_bringup.sh` actually `source`d
  `/opt/ros/humble/setup.bash` (picking up `ROS_DISTRO`, `LD_LIBRARY_PATH`,
  etc.) plus the `local/lib/.../dist-packages` `PYTHONPATH` entry -
  `bringup.sh` only hand-mimicked part of that via `PATH`/`AMENT_PREFIX_PATH`.
- The `LIDAR_MODEL` gap was a live bug, not just a hygiene issue:
  `hbot_web.service` runs `web_bringup.sh`, and the web dashboard's "Start
  Mapping"/"Start Navigation" buttons
  ([web_node.py](../src/hbot_web/hbot_web/web_node.py)'s
  `ROSLaunchManager.start_mapping_mode()`/`start_navigation_mode()`) shell
  out to `start_mapping.sh`/`start_navigation.sh`
  (`src/hbot_web/hbot_web/scripts/`) via a plain `subprocess.Popen(...,
  shell=True)` with no `env=` override - so they inherit whatever
  `hbot_web_node`'s environment was. With `LIDAR_MODEL` unset there,
  `hbot_bringup.launch.py`'s `os.environ.get('LIDAR_MODEL', 'lds01')`
  defaulted to `lds01` - meaning mapping/navigation launched from the web
  UI were silently using the wrong lidar driver, even after
  [scripts/bringup.sh](../scripts/bringup.sh) was fixed to default to
  `ydlidar_x3`.
- New [scripts/ros_env.sh](../scripts/ros_env.sh) is now the single source
  of truth for that block - `bringup.sh` and `web_bringup.sh` both just
  `source` it (merged to the more-correct `web_bringup.sh` behavior:
  explicit `source $ros_prefix/setup.bash` + the local dist-packages
  `PYTHONPATH` entry), then do their own thing (`ros2 launch
  hbot_bringup hbot_bringup.launch.py "$@"` vs. `base_bringup.launch.py`
  redirected to `log/web_bringup.log`).
- `start_mapping.sh`/`start_navigation.sh` were deliberately left as-is,
  not changed to also source `ros_env.sh` themselves: they're installed
  deep inside `hbot_web`'s Python package share dir (`SCRIPTS_DIR =
  os.path.dirname(os.path.abspath(__file__)) + '/scripts'` in
  `web_node.py`), with no stable relative path back to the main workspace's
  `scripts/` dir on either the dev-machine symlink-install or the Pi's
  non-symlink `install/` - and they don't need one, since they only ever
  run as subprocesses of `hbot_web_node`, which already inherits the fully
  -sourced environment from whichever of the two scripts above started it.
  Documented this reasoning directly in `ros_env.sh`'s header comment so it
  doesn't need rediscovering later.
- Verified with `bash -n` on all three scripts and a dry-run source of
  `ros_env.sh` confirming `LIDAR_MODEL=ydlidar_x3`, `ROS_DISTRO=humble`,
  and `ros2` resolving on `PATH`. **Not yet deployed to the Pi or the live
  `hbot_web.service`** - needs `docker/pi` rebuild (though these are plain
  scripts, not colcon packages - `sync_to_pi.sh` ships `scripts/` directly,
  no colcon build needed for this change) + `sync_to_pi.sh`, then
  `systemctl restart hbot_web` on the Pi to pick up the fix in the already
  -running service.

---

## 2026-08-25 (follow-up): made start_mapping.sh/start_navigation.sh self-sufficient

- Follow-up to the `ros_env.sh` consolidation above, after feedback that
  relying on implicit process-tree inheritance for
  `start_mapping.sh`/`start_navigation.sh` (`src/hbot_web/hbot_web/scripts/`)
  wasn't good enough - it worked (verified), but silently, which is exactly
  what caused the original `LIDAR_MODEL` bug in the first place.
- [scripts/ros_env.sh](../scripts/ros_env.sh) now requires `$HBOT_WS`
  (absolute workspace root) as its one input, exported by the caller before
  sourcing - replacing the old non-exported `$workspace_dir` convention.
  [scripts/bringup.sh](../scripts/bringup.sh) /
  [scripts/web_bringup.sh](../scripts/web_bringup.sh) now `export HBOT_WS=...`
  before sourcing it, so it survives into every descendant process,
  including `hbot_web_node` and whatever it shells out to.
- `start_mapping.sh`/`start_navigation.sh` now check `if [ -z "$LIDAR_MODEL"
  ]` (a reliable marker that they *didn't* inherit an already-set-up
  environment) and, only then, fall back to `source "$HBOT_WS/scripts/ros_env.sh"`
  explicitly - erroring loudly (`${HBOT_WS:?...}`) if `$HBOT_WS` isn't
  available either, instead of ever silently launching with a wrong
  default again. In the normal case (run as a subprocess of `hbot_web_node`)
  this is a no-op skip, so nothing gets re-sourced/re-appended to
  PATH/PYTHONPATH on every mapping/navigation click.
- Verified all four paths by hand: (1) neither `LIDAR_MODEL` nor `HBOT_WS`
  set -> fails immediately with the explicit error, no wrong-lidar launch;
  (2) `HBOT_WS` set, `LIDAR_MODEL` unset -> sources `ros_env.sh` and reaches
  a correctly-configured `ros2 launch` (confirmed via
  `~/hbot_ws/log/mapping_*.log`, hit only the same pre-existing
  `nav2_bringup`-not-built-locally gap on this dev machine, unrelated); (3)
  `LIDAR_MODEL` already set -> skips the fallback entirely; (4) full
  `bringup.sh` run -> `HBOT_WS` exported and resolved correctly.
- Deployed for real this time: synced `scripts/` to the Pi, hot-patched the
  two installed `hbot_web` scripts (`install/hbot_web/lib/python3.10/site-packages/hbot_web/scripts/`,
  confirmed byte-identical to source after), restarted `hbot_web.service`,
  and ran `start_mapping.sh` reconstructing the **actual live**
  `hbot_web_node` process's environment (via its `/proc/<pid>/environ`) to
  get a true end-to-end test rather than a fresh, disconnected SSH shell -
  confirmed `LiDAR successfully connected` (YDLidar X3 Pro) and
  `cartographer_node` starting, in the real mapping log. This is now fully
  deployed and live, not just source-fixed.

---

## 2026-08-25 (follow-up): src/ydlidar_x3 converted to a proper submodule + docs

- `src/ydlidar_x3` had been living as a plain (non-submodule) nested git
  repo with no remote configured. Per user request, pushed its history to a
  new dedicated repo,
  [`git@github.com:HbotVN/ydlidar-ros2-driver.git`](https://github.com/HbotVN/ydlidar-ros2-driver),
  then converted it into a real submodule registered in `.gitmodules`,
  matching every other `src/` package's convention.
- Before pushing, committed the nested repo's outstanding working-tree
  state (previously uncommitted): added a `.gitignore`
  (`*/build/**`) and removed `YDLidar-SDK-master/build/` — the SDK's CMake
  build tree — from version control (it had been accidentally committed
  earlier); plus the pending `declare_parameter` default-value fixes and
  the `ydlidar_x3.yaml` port change (`/dev/ydlidar` -> `/dev/usbttl`,
  matching the workspace's existing `usbttl` udev convention) already
  described in the two entries above.
- Converting to a submodule required clearing `src/ydlidar_x3` first
  (`git submodule add` refuses a non-empty, non-matching-repo path).
  `rm -rf` failed on `YDLidar-SDK-master/build/*` with `Permission denied`
  — those files were left root-owned by an earlier `sudo make install` /
  `cmake` run inside the bind-mounted directory. Worked around it by
  `mv`-ing the whole `src/ydlidar_x3` directory out of `src/` instead (a
  rename only needs write permission on the *parent* directory, not on
  every file inside), then `git submodule add
  git@github.com:HbotVN/ydlidar-ros2-driver.git src/ydlidar_x3` re-cloned a
  clean copy (no `build/` this time, since it's now `.gitignore`d at the
  source). The orphaned root-owned copy was left at
  `~/Documents/03.MyProjects/hbot_ws_ydlidar_x3_orphan` — **needs `sudo
  rm -rf` to actually reclaim the disk space**, not yet done.
- `.gitmodules` change is staged but not committed at the top level (per
  standing instruction to leave top-level commits to the user).
- Added [`docs/ydlidar_x3_lidar.md`](../docs/ydlidar_x3_lidar.md): a
  consolidated setup/troubleshooting guide for this integration (SDK
  system-wide install steps, config, launch wiring, hardware verification),
  pulling together what had previously only existed spread across this
  file's entries. Updated
  [`workspace_overview.md`](workspace_overview.md#5-lidar-drivers--selectable-via-lidar_model-env-var)'s
  lidar section to match the new `src/ydlidar_x3` submodule path/port
  (`/dev/usbttl`) and link to the new guide — it still described the old
  `src/lidars/ydlidar_ros2_driver-master` + `src/YDLidar-SDK-master`
  plain-directory layout and the stale `/dev/ydlidar` default.

---

## 2026-08-27: Simulation parity — model matches the real URDF, mapping + Nav2 run headless

Goal: make `simulation_mode:=True` run Cartographer mapping and Nav2 the same
way the real robot does, and bring the simulated robot model in line with the
URDF `robot_state_publisher` actually loads on the Pi
([`src/hbot_bringup/config/hbot.urdf`](../src/hbot_bringup/config/hbot.urdf)).
Done on branch `sim/mapping-nav-parity` (worktree beside the repo).

### [`hbot_description/urdf/hbot.urdf.xacro`](../src/hbot_description/urdf/hbot.urdf.xacro)

- **Frame tree now matches the real robot.** `base_footprint -> base_link` is
  identity (was a `0.0825 m` Z offset); `base_link -> laser` is
  `xyz="0.08 0 0.14" rpy="0 0 0"` (was `xyz="0 0 0.075"`, yaw `π`); added
  `imu_link` at the base origin. These are exactly the joints in
  `config/hbot.urdf`, so `/tf` is identical in sim and on hardware.
- **`wheel_separation` 0.17 -> 0.20** to match the driver's `wheel_track`
  ([`yahboom_driver_params.yaml`](../src/hbot_bringup/config/yahboom_driver_params.yaml));
  `wheel_diameter` stays `0.065`. Wheel joints re-derived from
  `wheel_separation` / `wheel_radius` instead of the old
  `base_width + wheel_ygap` / `wheel_zoff` scheme, with the base_link frame
  kept at ground level (matching real) and only the visual/collision box
  lifted.
- **Body box height 0.12 -> 0.11 and lifted to z ∈ [0.02, 0.13].**
  With the lidar at the real `0.14 m` height, a full-height box top poked
  *through* the horizontal scan plane, so the simulated lidar returned
  ~0.16 m hits off the robot's own collision box on every rear/side ray —
  Nav2 saw a phantom obstacle ring and refused to move. Box top now clears
  the scan plane. (On the real robot the lidar puck sits proud of the shell
  and never sees it.)
- Lidar sensor block aligned to the YDLidar X3 (`0.12–12 m`, `10 Hz`,
  full 360°); added a Gazebo IMU sensor on `imu_link` publishing `/imu`
  (only consumed if someone wires the EKF into sim; Gazebo still publishes
  `odom->base_footprint` directly by default).
- `CMakeLists.txt`'s `gz sdf -p` step now produces a non-empty
  [`hbot.sdf`](../src/hbot_description/urdf/hbot.sdf) (the committed one was
  a 0-byte file — a previous generator run had failed silently).

### [`hbot_simulation/launch/hbot_house.launch.py`](../src/hbot_simulation/launch/hbot_house.launch.py)

- **Spawn from the `/robot_description` topic**, not the (empty) `hbot.sdf`
  file — single source of truth, and the sim body can't drift from the TF
  tree. `spawn_entity.py` waits for the latched topic from
  `robot_state_publisher`.
- Declared `use_sim_time` / `x_pose` / `y_pose` / `headless` as real launch
  args; set `GAZEBO_MODEL_PATH` to the package `models/` dir.

### [`hbot_bringup/launch/hbot_bringup.launch.py`](../src/hbot_bringup/launch/hbot_bringup.launch.py)

- **New `headless` arg** (default `False`), forwarded to
  `hbot_house.launch.py`, so mapping/navigation can run without the Gazebo
  GUI (CI / remote / this validation).
- **The physical lidar driver include is wrapped in `try/except
  PackageNotFoundError`.** It only ever runs inside `hardware_nodes`
  (`UnlessCondition(simulation_mode)`), but `get_package_share_directory()`
  was evaluated while the launch description was *built*, so a sim-only host
  without `hls_lfcd_lds_driver` / `ydlidar_ros2_driver` installed couldn't
  start the sim at all. Now it degrades to "no lidar node" (Gazebo
  publishes `/scan` itself in sim).
- **`cmd_vel` routing for Nav2 now works in sim.** The
  `SetRemap(cmd_vel_smoothed -> cmd_vel_nav_smoothed)` around the vendored
  `navigation_launch.py` only makes sense on hardware, where
  `base_bringup.launch.py`'s `twist_mux` routes `cmd_vel_nav_smoothed` back
  to `cmd_vel`. There is no `twist_mux` in sim (and it isn't even
  guaranteed installed), so Nav2's smoothed output went nowhere and the
  robot never moved under autonomous control. Split `bringup_cmd_group` into
  a `_real` branch (with the SetRemap, gated
  `enable_navigation and not simulation_mode`) and a `_sim` branch (no
  SetRemap → Nav2's `velocity_smoother` publishes `cmd_vel` directly, which
  the Gazebo diff-drive plugin subscribes to).
- **`slam:=False` localization mode now has a working default map.** The
  `map` arg used to default to a non-existent `hbot_bringup/maps/map.yaml`,
  so localization mode couldn't start without an explicit `map:=`. Added
  [`maps/hbot_house_sim.{pgm,yaml}`](../src/hbot_bringup/maps/) (built from
  `hbot_house.world` with `scripts/dev_sim_build_map.sh`), installed via a
  `maps/*` glob in [`setup.py`](../src/hbot_bringup/setup.py), and pointed
  the `map` default at it. Real-hardware users still pass `map:=/abs/path`.

### Sample map + helper scripts

- [`scripts/dev_sim_build_map.sh`](../scripts/dev_sim_build_map.sh) - brings
  up sim+Cartographer headless, drives a patrol pattern, saves the map with
  `nav2_map_server map_saver_cli`.
- [`scripts/dev_sim_localization_smoke.sh`](../scripts/dev_sim_localization_smoke.sh)
  - sim + AMCL + Nav2 against the saved map; sets `/initialpose`, checks
  AMCL convergence, drives a goal.

### Validation (headless, on the dev laptop)

Full `navigation2` fork + `slam_toolbox` built from source (`robot_localization`
skipped locally — needs `geographic_msgs`, not on this host; EKF is
hardware-only). Helper scripts: `scripts/dev_sim_smoke.sh`,
`scripts/dev_sim_mapping_smoke.sh`, `scripts/dev_sim_nav_smoke.sh`.

- **Gazebo bring-up**: robot spawns from `/robot_description`; `/scan`
  (10 Hz, 360°, no self-hits), `/odom` (~30 Hz), `/imu` (200 Hz) all
  publishing; TF chain `odom → base_footprint → base_link →
  laser(0.08,0,0.14) → imu_link` exactly as on hardware; `/cmd_vel` moves
  the robot.
- **Mapping** (`slam:=True enable_navigation:=False`): `cartographer_node` +
  occupancy grid come up, `/map` published, `map → odom` transform
  broadcast, submaps accumulate while driving.
- **Navigation** (`slam:=True enable_navigation:=True`): all Nav2 lifecycle
  nodes reach `active`; a `NavigateToPose` goal to `(1.2, 0.0)` returns
  **`SUCCEEDED`** with the robot ending at `(0.96, 0.0)` (inside
  `xy_goal_tolerance`).
- **Localization** (`slam:=False enable_navigation:=True`, default map):
  `map_server` + `amcl` + Nav2 come up; after an `/initialpose` at
  `(0,0,0)` AMCL converges (`/amcl_pose` ≈ origin, `map -> odom` broadcast);
  a `NavigateToPose` goal returns **`SUCCEEDED`**.

**Not done**: `robot_localization`/EKF not exercised in sim (Gazebo publishes
`odom` directly).

---

## 2026-08-29: Simulation re-verification + course/guide docs

Picked the `sim/mapping-nav-parity` worktree back up. Rebuilt
`hbot_description` / `hbot_simulation` / `hbot_bringup` and re-ran all four
headless smoke scripts on the dev laptop to confirm the 2026-08-27 work still
holds after the xacro regeneration:

- `scripts/dev_sim_smoke.sh` — spawn from `/robot_description`; `/scan`
  9.98 Hz (`angle_min ≈ -π`, `range_min 0.12`, `range_max 12.0`), `/odom`
  ~29 Hz, `/imu` ~199 Hz; TF `odom→base_footprint→base_link→laser
  [0.08,0,0.14]` / `→imu_link [0,0,0]` all identity/exact; `cmd_vel` moves
  the robot.
- `scripts/dev_sim_mapping_smoke.sh` — `cartographer_node` up, `/map` +
  `map→odom` broadcast, submaps + loop-closure constraints accumulating, no
  errors/warnings in the launch log.
- `scripts/dev_sim_nav_smoke.sh 40 1.2 0.0` — all Nav2 lifecycle nodes
  `active`; `NavigateToPose (1.2, 0)` → **`SUCCEEDED`**, robot ended at
  `map→base_link (0.96, 0.0)`.
- `scripts/dev_sim_localization_smoke.sh "" 60 0.8 0.0` — AMCL converges
  after `/initialpose (0,0,0)` (`/amcl_pose ≈ origin`, `map→odom`
  broadcast); `NavigateToPose (0.8, 0)` → **`SUCCEEDED`**.
  - **Observed once** with a 40 s warmup on a loaded laptop:
    `lifecycle_manager_navigation` aborted Nav2 bring-up
    (`controller_server ... get_state ... async_send_request failed`) — a
    startup race, not a regression. 60 s warmup (or `headless:=True` + no
    RViz, or staging Nav2 after Gazebo settles) clears it. Documented in
    both guides' troubleshooting tables.

### Docs

- [`docs/simulation_guide.md`](../docs/simulation_guide.md) — the reference
  guide from 2026-08-27. Added a "test status" note, the
  `lifecycle_manager ... Aborting bringup` troubleshooting row, and clearer
  wording on the default-map initial pose.
- [`docs/sim_mapping_localization_guide.md`](../docs/sim_mapping_localization_guide.md)
  — **course document** (step-by-step lessons: Bài 1 mapping, Bài 2
  localization+nav, Bài 3 headless smoke scripts). Rewritten from the older
  draft that still carried the stale "goal accepted but robot doesn't move"
  limitation + `topic_tools relay` workaround — both gone now that the sim
  `cmd_vel` routing is fixed. Adds the bundled `hbot_house_sim` default map,
  `headless`, and a sim↔real parity/differences table. Cross-links the
  reference guide. (An untracked older copy of this filename still sits in
  the primary `hbot_ws` checkout on `main` — superseded by this one.)
- [`CLAUDE.md`](../CLAUDE.md) — "Robot kinematics" paragraph refreshed:
  track width 0.17→0.20 m, `base_footprint ≡ base_link`, laser at
  `(0.08, 0, 0.14)` no yaw, `imu_link`, sim collision box 0.11 m.

## 2026-09-23: hbot_description built from CAD meshes (branch `feat/cad-model`)

Submodule `src/hbot_description`, new branch `feat/cad-model` off `main` @ `c6ccb37`
(not committed yet). Step-by-step guide:
[`src/hbot_description/docs/cad_model.md`](../src/hbot_description/docs/cad_model.md).

- Raw CAD exports [`models/base_link.stl`, `models/wheel.stl`](../src/hbot_description/models)
  are in mm, yawed 37.4° and off-origin, with the caster ball and a YDLidar X2/X3
  housing baked into the chassis.
- New [`scripts/prepare_meshes.py`](../src/hbot_description/scripts/prepare_meshes.py)
  (numpy only) detects the yaw from the wheel axle, re-expresses everything in the
  body frame (origin on the ground under the axle mid-point, x toward the caster),
  splits the lidar out, and writes `meshes/{base_link,wheel,lidar}.stl` (link
  frames, metres) plus generated `urdf/cad_params.xacro` (measured dimensions).
- [`urdf/hbot.urdf.xacro`](../src/hbot_description/urdf/hbot.urdf.xacro) rewritten
  with mesh visuals + primitive collisions; `wheel_separation` 0.195 (user spec
  190–200 mm; CAD 0.183). Gazebo blocks moved to
  [`urdf/hbot.gazebo.xacro`](../src/hbot_description/urdf/hbot.gazebo.xacro); lidar
  sim now YDLidar X3: 8 Hz, 375 samples, 0.12–8 m.
- `CMakeLists.txt` installs `meshes/`; `package.xml` exports `gazebo_model_path`;
  `launch/hbot_description.launch.py` runs `joint_state_publisher` (arg).
- New geometry: `laser` (0.0425, 0, 0.1368), caster r 0.0116 at (0.105, 0.010),
  wheel Ø 0.0674, chassis box x −0.050…0.132, y ±0.090, top 0.117 < scan plane.
- Verified: `check_urdf` + `gz sdf -p` OK; headless Gazebo (domain 42) `/scan`
  8 Hz / 375 samples / no self-hits, TF as above, drives + spins. The idle ~1 mm/s
  Gazebo creep also exists with the old model (pre-existing).
- Not yet synced (in `hbot_bringup`): Pi `config/hbot.urdf` laser pose (0.08, 0.14),
  driver `wheel_track` 0.20 / `wheel_diameter` 0.065, Nav2 footprint (centred
  ±0.09 × ±0.12, but the robot now extends −0.05…+0.132 in x).
- `build/hbot_simulation` is root-owned (Docker leftover) → the host build fails with
  Permission denied; verification used a throwaway overlay under `log/cadcheck/`.

### 2026-09-23 (follow-up): `hbot.urdf` (real, frames only) + `hbot_sim.urdf` (Gazebo) from one xacro

Guide: Step 7 of [`src/hbot_description/docs/cad_model.md`](../src/hbot_description/docs/cad_model.md).
Branches `feat/cad-model` in `hbot_description`, `hbot_simulation`, `hbot_bringup` (uncommitted).

- [`urdf/hbot.urdf.xacro`](../src/hbot_description/urdf/hbot.urdf.xacro) takes `sim`
  (default `false`). The shared frames (`base_footprint`, `base_link`, `laser`,
  `imu_link`) are declared once. `sim:=true` fills `base_link`/`laser` with
  visuals/collisions/inertias and adds the wheels, caster and Gazebo plugins from the new
  [`urdf/hbot_body.xacro`](../src/hbot_description/urdf/hbot_body.xacro) +
  `hbot.gazebo.xacro`. The real robot gets no wheel joints (the driver publishes no
  `/joint_states`).
- New [`cmake/generate_urdf.cmake`](../src/hbot_description/cmake/generate_urdf.cmake)
  (install-time) writes `urdf/hbot.urdf` + `urdf/hbot_sim.urdf`, fails the build on a
  xacro error, and writes `hbot_sim.sdf` only if `gz` exists (Pi image has none).
  `urdf/hbot.sdf` removed.
- `launch/hbot_description.launch.py`: `sim` arg; `robot_description` wrapped in
  `ParameterValue(value_type=str)` (Humble YAML-parses the xacro output otherwise).
  The `joint_state_publisher` node added earlier was removed by the user; kept out.
- [`hbot_simulation/launch/hbot_house.launch.py`](../src/hbot_simulation/launch/hbot_house.launch.py)
  → `hbot_sim.urdf`.
- [`hbot_bringup/launch/hbot_bringup.launch.py`](../src/hbot_bringup/launch/hbot_bringup.launch.py)
  → `hbot_description/urdf/hbot.urdf`; `config/hbot.urdf` deleted (+ `setup.py`),
  `package.xml` exec_depends `hbot_description`. **The real laser pose changes**
  from (0.08, 0, 0.14) to the CAD's (0.0425, 0, 0.1368); re-check SLAM on hardware.
- Verified: `check_urdf` for both; `robot_state_publisher` `sim:=false|true` →
  `base_footprint→laser (0.043, 0, 0.137)`; headless Gazebo from `hbot_sim.urdf`
  (overlay `log/cadcheck/`, domain 42): `/scan` 8 Hz, wheel TF, drives.
- On merge: update [`CLAUDE.md`](../CLAUDE.md) (kinematics paragraph still cites
  `hbot_bringup/config/hbot.urdf`, laser 0.08/0.14, `hbot.sdf`) and
  `docs/simulation_guide.md` / `docs/sim_mapping_localization_guide.md`, which
  reference `config/hbot.urdf`.

### 2026-09-24: Simulation sources guide

New [`src/hbot_simulation/docs/simulation_sources.md`](../src/hbot_simulation/docs/simulation_sources.md)
(branch `feat/cad-model`): the three sim sources and how each is generated:
robot (`hbot_description` xacro → `hbot_sim.urdf` via `prepare_meshes.py` + colcon),
world (`worlds/hbot_house.world`, Gazebo GUI; the `hbot_house` model is copied
**inline**, geometry identical to `models/hbot_house/model.sdf`, so editing the model alone
has no effect; `<include>` suggested), and the sim map (`dev_sim_build_map.sh` →
`hbot_bringup/maps/hbot_house_sim.*`). Notes the stale
`hbot_simulation/launch/hbot_description.launch.py` and the missing `gazebo_ros`/`hbot_description`
deps in `hbot_simulation/package.xml`.

### 2026-09-25/26: Standard robot description (one xacro + geometry YAML)

Branches `feat/standard-description` in `hbot_description`, `hbot_bringup` and
this repo; `feat/cad-model` in `hbot_simulation`. Full guide:
[`hbot_description/docs/robot_description.md`](../src/hbot_description/docs/robot_description.md).

- [`hbot_description/config/hbot_geometry.yaml`](../src/hbot_description/config/hbot_geometry.yaml):
  every dimension (`cad` = take `cad_params.xacro`); track 0.190 m, measured wheel
  radius 0.03375 / width 0.0265, lidar sensor spec.
- [`urdf/hbot.urdf.xacro`](../src/hbot_description/urdf/hbot.urdf.xacro): single entry,
  args `use_sim` (adds `hbot.gazebo.xacro`) and `driver_joint_states`; model in
  `hbot_base.xacro` + `hbot_sensors.xacro` (`hbot_body.xacro` removed). The real
  robot now gets the full model; wheels are `fixed` until the driver publishes
  `/joint_states`. `base_link` is blue (Gazebo/Blue + RViz `blue`).
- `CMakeLists.txt`: `hbot.urdf` / `hbot_sim.urdf` / `hbot_sim.sdf` generated into
  `build/` and installed; nothing written to `src/`, no longer tracked
  (`cmake/generate_urdf.cmake` removed).
- New `launch/description.launch.py` (robot_state_publisher, xacro at launch) and
  `launch/view.launch.py`; `hbot_description.launch.py` kept as a wrapper.
- `test/test_description.py` (colcon test): real/sim frame parity, wheels vs.
  diff-drive and driver params, lidar spec, scan-plane clearance, meshes.
- [`hbot_bringup/launch/hbot_bringup.launch.py`](../src/hbot_bringup/launch/hbot_bringup.launch.py):
  real mode includes `description.launch.py`; [`yahboom_driver_params.yaml`](../src/hbot_bringup/config/yahboom_driver_params.yaml)
  `wheel_track` 0.2 → 0.19, `wheel_diameter` 0.065 → 0.0675.
- Verified: 9/9 tests; real-mode launch on domain 42 (nav2_bringup stubbed on the
  laptop): `laser (0.043, 0, 0.137)`, wheels y ±0.095. Not yet run: Gazebo, Pi.
- Pi needs `ros-humble-xacro` at run time (rosdep). Still stale: `CLAUDE.md`
  kinematics paragraph (track 0.20, laser 0.08/0.14, `config/hbot.urdf`) and
  `hbot_simulation/docs/simulation_sources.md` Part 1 (old `sim:=` flow).
