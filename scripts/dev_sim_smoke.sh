#!/bin/bash
# Dev-only smoke test for the Gazebo simulation bring-up (headless).
# Not wired into CI - a quick "does the sim still stand up" check while
# iterating on the robot model / launch files.
#
#   ./scripts/dev_sim_smoke.sh [seconds]
HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
RUN_SECS="${1:-40}"
LOG=/tmp/hbot_sim_smoke.log

source /opt/ros/humble/setup.bash
source "$HBOT_WS/install/setup.bash"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-9}"

echo "== launching hbot_house.launch.py (headless) =="
ros2 launch hbot_simulation hbot_house.launch.py headless:=true use_sim_time:=true \
    > "$LOG" 2>&1 &
LAUNCH_PID=$!
trap 'kill $LAUNCH_PID 2>/dev/null; pkill -f gzserver 2>/dev/null; pkill -f "spawn_entity" 2>/dev/null; pkill -f robot_state_publisher 2>/dev/null' EXIT

sleep "$RUN_SECS"

echo
echo "== ros2 node list =="
ros2 node list
echo
echo "== ros2 topic list =="
ros2 topic list
echo
echo "== /clock rate (sim time alive?) =="
timeout 6 ros2 topic hz /clock 2>&1 | head -3
echo
echo "== /scan rate + one sample =="
timeout 8 ros2 topic hz /scan 2>&1 | head -3
timeout 6 ros2 topic echo /scan --once --field angle_min 2>&1 | head -1
timeout 6 ros2 topic echo /scan --once --field range_min 2>&1 | head -1
timeout 6 ros2 topic echo /scan --once --field range_max 2>&1 | head -1
echo
echo "== /odom rate =="
timeout 8 ros2 topic hz /odom 2>&1 | head -3
echo
echo "== /imu rate =="
timeout 8 ros2 topic hz /imu 2>&1 | head -3
echo
echo "== TF chain =="
for pair in "odom base_footprint" "base_footprint base_link" "base_link laser" "base_link imu_link"; do
  set -- $pair
  echo "--- $1 -> $2"
  timeout 5 ros2 run tf2_ros tf2_echo "$1" "$2" 2>&1 | grep -A6 -m1 "Translation" || echo "  (no transform)"
done
echo
echo "== drive test: publish cmd_vel 0.15 m/s for 3s, watch odom.x =="
timeout 6 ros2 topic echo /odom --once --field pose.pose.position.x 2>&1 | head -1
timeout 4 ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist '{linear: {x: 0.15}}' >/dev/null 2>&1
sleep 1
timeout 6 ros2 topic echo /odom --once --field pose.pose.position.x 2>&1 | head -1

echo
echo "== launch log tail =="
tail -30 "$LOG"
