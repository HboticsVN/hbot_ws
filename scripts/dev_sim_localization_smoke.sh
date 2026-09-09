#!/bin/bash
# Dev-only smoke test: full sim + AMCL localization + Nav2 (headless), against
# a pre-built map. Sets an initial pose, checks AMCL converges (map->odom TF +
# /amcl_pose), then drives a NavigateToPose goal.
#
#   ./scripts/dev_sim_localization_smoke.sh [map_yaml] [warmup] [gx] [gy]
HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
MAP="${1:-$HBOT_WS/src/hbot_bringup/maps/hbot_house_sim.yaml}"
WARMUP="${2:-35}"
GX="${3:-0.8}"
GY="${4:-0.0}"
LOG=/tmp/hbot_sim_loc_smoke.log

source /opt/ros/humble/setup.bash
source "$HBOT_WS/install/setup.bash"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-9}"
export LIDAR_MODEL="${LIDAR_MODEL:-ydlidar_x3}"

echo "== launching sim + localization + nav (headless), map=$MAP =="
ros2 launch hbot_bringup hbot_bringup.launch.py \
    simulation_mode:=True use_sim_time:=True slam:=False \
    map:="$MAP" enable_navigation:=True run_rviz:=False headless:=True \
    > "$LOG" 2>&1 &
LP=$!
trap 'kill $LP 2>/dev/null; pkill -f gzserver; pkill -f "amcl|map_server|controller_server|planner_server|bt_navigator|behavior_server|velocity_smoother|lifecycle_manager"; pkill -f robot_state_publisher; pkill -f spawn_entity' EXIT
sleep "$WARMUP"

echo; echo "== nodes =="; ros2 node list | sort
echo; echo "== set initial pose (0,0,0) in map =="
timeout 6 ros2 topic pub -1 /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
  '{header: {frame_id: map}, pose: {pose: {position: {x: 0.0, y: 0.0, z: 0.0}, orientation: {w: 1.0}},
    covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}'
sleep 6
echo; echo "== amcl converged? =="
timeout 6 ros2 run tf2_ros tf2_echo map odom 2>&1 | grep -A2 -m1 Translation || echo "  NO map->odom"
timeout 6 ros2 topic echo /amcl_pose --once --field pose.pose.position 2>&1 | head -4
echo; echo "== NavigateToPose ($GX,$GY) =="
timeout 90 ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
  "{pose: {header: {frame_id: map}, pose: {position: {x: $GX, y: $GY}, orientation: {w: 1.0}}}}" 2>&1 | tail -6
echo; echo "== end pose (map->base_link) =="
timeout 6 ros2 run tf2_ros tf2_echo map base_link 2>&1 | grep -A1 -m1 Translation
echo; echo "== errors =="
grep -iE 'error|exception|abort|could not transform|activation failed' "$LOG" | grep -v 'Timed out waiting for transform' | head -20
