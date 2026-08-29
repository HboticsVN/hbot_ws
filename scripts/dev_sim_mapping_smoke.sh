#!/bin/bash
# Dev-only smoke test: full sim + Cartographer mapping bring-up (headless),
# drive the robot a bit, confirm a map and the map->odom transform appear.
#
#   ./scripts/dev_sim_mapping_smoke.sh [warmup_secs]
HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
WARMUP="${1:-25}"
LOG=/tmp/hbot_sim_mapping_smoke.log

source /opt/ros/humble/setup.bash
source "$HBOT_WS/install/setup.bash"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-9}"

echo "== launching hbot_bringup.launch.py (sim + slam, headless) =="
source "$HBOT_WS/scripts/ros_env.sh" 2>/dev/null; ros2 launch hbot_bringup hbot_bringup.launch.py \
    simulation_mode:=True use_sim_time:=True slam:=True \
    enable_navigation:=False run_rviz:=False headless:=True \
    > "$LOG" 2>&1 &
LAUNCH_PID=$!
trap 'kill $LAUNCH_PID 2>/dev/null; pkill -f gzserver; pkill -f cartographer; pkill -f robot_state_publisher; pkill -f spawn_entity' EXIT

sleep "$WARMUP"

echo
echo "== nodes ==";      ros2 node list
echo
echo "== cartographer submap/topics ==";  ros2 topic list | grep -E 'map|submap|scan_matched|trajectory'
echo
echo "== drive a small L-shape to give the scan matcher some motion =="
drive() { timeout "$2" ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "$1" >/dev/null 2>&1; }
drive '{linear: {x: 0.15}}' 6
drive '{angular: {z: 0.5}}' 4
drive '{linear: {x: 0.15}}' 6
drive '{angular: {z: -0.5}}' 4
drive '{linear: {x: 0.0}}' 1
sleep 3

echo
echo "== /map metadata =="
timeout 8 ros2 topic echo /map --once --field info 2>&1 | head -12
echo
echo "== map -> odom transform (Cartographer output) =="
timeout 6 ros2 run tf2_ros tf2_echo map odom 2>&1 | grep -A3 -m1 "Translation" || echo "  (no map->odom!)"
echo
echo "== full TF frames =="
timeout 6 ros2 run tf2_tools view_frames -o /tmp/hbot_frames >/dev/null 2>&1
timeout 5 ros2 topic echo /tf_static --once 2>&1 | grep -E 'child_frame_id|frame_id:' | sort -u
echo
echo "== errors/warnings in log =="
grep -iE 'error|fail|exception|traceback|could not|no transform' "$LOG" | grep -viE 'failure_tolerance|/failed' | head -30
echo
echo "== log tail =="
tail -20 "$LOG"
