#!/bin/bash
# Launches SLAM Toolbox mapping mode via hbot_bringup and logs all output to
# ~/hbot_ws/log/mapping_<datetime>.log
#
# Usage: start_mapping.sh <use_sim_time: True|False>
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

LOG_DIR="$HOME/hbot_ws/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mapping_$(date +%Y%m%d_%H%M%S).log"

exec ros2 launch hbot_bringup hbot_bringup.launch.py \
    slam:=True enable_navigation:=False use_sim_time:="$USE_SIM_TIME" \
    > "$LOG_FILE" 2>&1
