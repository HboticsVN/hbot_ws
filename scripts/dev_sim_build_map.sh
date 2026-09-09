#!/bin/bash
# Dev helper: bring up sim + Cartographer headless, drive a patrol pattern to
# build a map of hbot_house.world, then save it with nav2 map_saver_cli.
#
#   ./scripts/dev_sim_build_map.sh [output_basename]
#
# Default output: src/hbot_bringup/maps/hbot_house_sim.{pgm,yaml}
HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
OUT="${1:-$HBOT_WS/src/hbot_bringup/maps/hbot_house_sim}"
LOG=/tmp/hbot_build_map.log

source /opt/ros/humble/setup.bash
source "$HBOT_WS/install/setup.bash"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-9}"
export LIDAR_MODEL="${LIDAR_MODEL:-ydlidar_x3}"

mkdir -p "$(dirname "$OUT")"

echo "== bring up sim + slam (headless) =="
ros2 launch hbot_bringup hbot_bringup.launch.py \
    simulation_mode:=True use_sim_time:=True slam:=True \
    enable_navigation:=False run_rviz:=False headless:=True \
    > "$LOG" 2>&1 &
LP=$!
trap 'kill $LP 2>/dev/null; pkill -f gzserver; pkill -f cartographer; pkill -f robot_state_publisher; pkill -f spawn_entity' EXIT
sleep 25

pub() { timeout "$2" ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "$1" >/dev/null 2>&1; }
spin360() { pub '{angular: {z: 0.6}}' 11; pub '{linear: {x: 0.0}}' 1; }
fwd()    { pub "{linear: {x: 0.18}}" "$1"; pub '{linear: {x: 0.0}}' 1; }
turnL()  { pub '{angular: {z: 0.6}}' 3;  pub '{linear: {x: 0.0}}' 1; }
turnR()  { pub '{angular: {z: -0.6}}' 3; pub '{linear: {x: 0.0}}' 1; }

echo "== patrol =="
spin360
fwd 12; turnR; fwd 8; turnR; fwd 12; turnR; fwd 8; turnR   # rough loop
spin360
fwd 8;  turnL; fwd 6;  spin360
fwd 6;  turnL; fwd 8
spin360
sleep 3

echo "== save map -> $OUT =="
ros2 run nav2_map_server map_saver_cli -f "$OUT" --ros-args -p use_sim_time:=true
echo
echo "== result =="
ls -la "${OUT}".* 2>&1
cat "${OUT}.yaml" 2>/dev/null
