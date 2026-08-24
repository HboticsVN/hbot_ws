
### [25/8/2026] YDLidar X3 Pro integration + bringup env consolidation

[x] Added YDLidar X3 Pro support in hbot_bringup.launch.py, selectable via LIDAR_MODEL env var alongside existing LDS-01 (default is now ydlidar_x3)
[x] Fixed x3_ydlidar_launch.py + ydlidar_ros2_driver_node.cpp for ROS 2 Humble - pre-Foxy LifecycleNode kwargs and 21 argument-less declare_parameter() call sites don't exist on Humble's rclcpp API anymore
[x] Found + fixed a real bug: hbot_bringup.launch.py's own top-level params_file arg (for Nav2) silently shadowed x3_ydlidar_launch.py's params_file, so the lidar node ignored ydlidar_x3.yaml entirely and fell back to the hardcoded /dev/ydlidar default - fixed by passing params_file explicitly on that include
[x] docker/pi: build+install the YDLidar SDK for arm64 at image-build time (bare CMake project, COLCON_IGNORE'd, statically linked - no runtime dep on the Pi); added root .dockerignore (build context was 1.4GB -> 9.5MB, no .dockerignore existed before)
[x] Consolidated scripts/bringup.sh + scripts/web_bringup.sh's duplicated ROS env setup into new scripts/ros_env.sh - caught that LIDAR_MODEL was missing from web_bringup.sh, meaning web-dashboard-triggered mapping/navigation was silently using the wrong lidar driver
[x] Made hbot_web's start_mapping.sh/start_navigation.sh self-sufficient (source ros_env.sh via $HBOT_WS if not already inherited) instead of silently depending on process-tree inheritance
[x] Verified everything live on the real robot via ssh (hbot.local) - lidar connects on /dev/usbttl, cartographer starts, deployed + restarted hbot_web.service
[x] src/ydlidar_x3 registered as a proper git submodule (HbotVN/ydlidar-ros2-driver); new docs/ydlidar_x3_lidar.md guide

TODO:
[] Tune AMCL localization config - current params likely not optimal yet

### [21/8/2026] Commit and split twist_mux/driver fixes + web Nav Goal feature

[x] Committed hbot_bringup submodule: twist_mux arbitration between teleop and Nav2 cmd_vel, RPP controller + narrow-corridor costmap tuning, rviz/cartographer tweaks
[x] Committed hbot_driver submodule: software-side motor/encoder polarity, fixed wheel_track vs wheel_base kinematics bug, cmd_vel watchdog, calibrate_polarities.py tooling
[x] Split and committed hbot_ws main repo into 4 commits: submodule pointer bump, mapping/nav launch-script refactor + build/bringup hardening (use_ekf:=False, ROS self-sourcing), web Nav Goal + path overlay feature, repo meta (CLAUDE.md, skills, docs, test.py)
[x] Web interface: Add goal input from map + Show global path - done via new "Set Goal" map tool + live plan overlay
[x] Verified twist_mux priority + Nav Goal feature on real hardware

TODO:
[] Calib navigation params.
[] Replace new LiDAR
[] Push all commits to remotes - hbot_bringup, hbot_driver submodules and hbot_ws main are all ahead of origin, not yet pushed

### [18/8/2026] Fix bug move robot

[x] Sync to pi, correct polarity
[x] Add polarity calib scripts into hbot_driver
[x] Run test on robot:
    - Disable ekf (in scripts/web_bringup.sh)
    - mapping not work, need to check
    - Navigation worked, but has some issues:
        - PID of two motors not same
        - lidar mis-align when rotate.
        - The robot can't go through the gap less than 0.3m

TODO:
[x] Fix move robot
[] Calib navigation params.
[] Replace new LiDAR

### [18/8/2026] PID calib script fix, cmd_vel safety, teleop smoothing, Pi build fixes

[x] Fix calibrate_pid.py crash - duplicate plot_matplotlib() def referenced m3/m4 RPM keys that don't exist (2-motor robot); also fixed export_csv() field mismatch
[x] Analyze PID step response plots (20/40/80 rpm) - 20rpm shows a persistent oscillation/limit cycle that never settles, even with wheels off the ground (not a load issue - likely encoder quantization at low speed, needs a retune)
[x] Investigate "robot turns a bit going straight" - ruled out a cmd_vel decomposition bug (driver always sends equal L/R rpm when angular.z=0); unloaded test shows M1/M2 well matched, so it's probably mechanical (wheel diameter/tire wear/traction/caster), not motor/PID asymmetry - not yet confirmed on the physical robot
[x] Route hbot_web teleop cmd_vel through nav2_velocity_smoother in base_bringup.launch.py (previously only Nav2-driven cmd_vel was smoothed, teleop bypassed it entirely and hit the driver raw) -> the "turn a bit when go straight" is eliminated.
[x] Add cmd_vel watchdog to hbot_driver_yahboom_node.cpp - robot now auto-stops (cmd_vel_timeout param, default 0.5s) if cmd_vel stops publishing instead of coasting on the last command forever
[x] Create deploy-to-pi and commit-and-deploy skills (.claude/skills/)
[x] Deploy to pi - build, sync, restart hbot_web.service, verified logs clean (driver connected, velocity_smoother activated, web dashboard serving)
[x] Fix docker/pi build robustness - uncommented the build command in docker-compose.yaml; build_packages.sh/build_packages_pi.sh now self-source ROS 2 if not already sourced (was silently breaking under `docker exec`)

TODO:
[] Calib navigation params.
[] Replace new LiDAR
[] Web interface:
  - Add goal input from map
  - Show global path
