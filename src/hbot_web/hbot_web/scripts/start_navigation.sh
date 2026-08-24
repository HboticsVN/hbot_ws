#!/bin/bash
# Launches Nav2 navigation mode against a saved map via hbot_bringup and logs
# all output to ~/hbot_ws/log/navigation_<datetime>.log
#
# Usage: start_navigation.sh <use_sim_time: True|False> <map_yaml_path>
set -e

# Normally already inherits a fully-set-up ROS environment (ROS_DOMAIN_ID,
# CONTROLLER, LIDAR_MODEL, sourced install/setup.bash, ...) from
# hbot_web_node, which is itself started via scripts/web_bringup.sh -
# LIDAR_MODEL is a reliable marker of that, since nothing else exports it.
# Falls back to sourcing scripts/ros_env.sh explicitly via $HBOT_WS (also
# exported by ros_env.sh) so this script is self-sufficient rather than
# silently dependent on process-tree inheritance - e.g. if run standalone
# for debugging, or the launch chain above it ever changes - and fails
# loudly instead of quietly launching with the wrong lidar again.
if [ -z "$LIDAR_MODEL" ]; then
    : "${HBOT_WS:?HBOT_WS not set - run this via the web dashboard (hbot_web_node), or source scripts/ros_env.sh yourself first}"
    source "$HBOT_WS/scripts/ros_env.sh"
fi

USE_SIM_TIME="${1:-False}"
MAP_YAML="$2"

if [ -z "$MAP_YAML" ]; then
    echo "Usage: $0 <use_sim_time> <map_yaml_path>" >&2
    exit 1
fi

LOG_DIR="$HOME/hbot_ws/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/navigation_$(date +%Y%m%d_%H%M%S).log"

exec ros2 launch hbot_bringup hbot_bringup.launch.py \
    slam:=False enable_navigation:=True map:="$MAP_YAML" use_sim_time:="$USE_SIM_TIME" \
    > "$LOG_FILE" 2>&1
