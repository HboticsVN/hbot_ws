#!/bin/bash
# Dev-only smoke test: full sim + Cartographer + Nav2 (headless).
# Bring the stack up, send a NavigateToPose goal, confirm the robot drives
# toward it and the action returns success.
#
#   ./scripts/dev_sim_nav_smoke.sh [warmup_secs] [goal_x] [goal_y]
HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
WARMUP="${1:-35}"
GX="${2:-1.5}"
GY="${3:-0.0}"
LOG=/tmp/hbot_sim_nav_smoke.log

source /opt/ros/humble/setup.bash
source "$HBOT_WS/install/setup.bash"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-9}"

echo "== launching hbot_bringup.launch.py (sim + slam + nav, headless) =="
source "$HBOT_WS/scripts/ros_env.sh" 2>/dev/null; ros2 launch hbot_bringup hbot_bringup.launch.py \
    simulation_mode:=True use_sim_time:=True slam:=True \
    enable_navigation:=True run_rviz:=False headless:=True \
    > "$LOG" 2>&1 &
LAUNCH_PID=$!
trap 'kill $LAUNCH_PID 2>/dev/null; pkill -f gzserver; pkill -f cartographer; pkill -f "component_container|controller_server|planner_server|bt_navigator|behavior_server|velocity_smoother|lifecycle_manager"; pkill -f robot_state_publisher; pkill -f spawn_entity' EXIT

sleep "$WARMUP"

echo; echo "== nodes ==";  ros2 node list | sort
echo; echo "== lifecycle states =="
for n in controller_server planner_server bt_navigator behavior_server velocity_smoother smoother_server; do
  echo -n "  $n: "; timeout 4 ros2 lifecycle get "/$n" 2>&1 | head -1
done
echo; echo "== start pose (odom->base_link) =="
timeout 6 ros2 run tf2_ros tf2_echo odom base_link 2>&1 | grep -A1 -m1 Translation
echo; echo "== sending NavigateToPose goal ($GX, $GY) in map frame =="
timeout 90 ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
  "{pose: {header: {frame_id: map}, pose: {position: {x: $GX, y: $GY, z: 0.0}, orientation: {w: 1.0}}}}" \
  2>&1 | tail -20
echo; echo "== end pose (map->base_link) =="
timeout 6 ros2 run tf2_ros tf2_echo map base_link 2>&1 | grep -A1 -m1 Translation
echo; echo "== errors in log =="
grep -iE 'error|exception|traceback|abort|failed to|could not transform|activation failed' "$LOG" | head -30
echo; echo "== log tail =="
tail -15 "$LOG"
