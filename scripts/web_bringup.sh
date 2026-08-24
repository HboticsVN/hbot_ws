#!/bin/bash

set -e

export HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

source "$HBOT_WS/scripts/ros_env.sh"

# Ensure the log directory exists
mkdir -p "$HBOT_WS/log"

echo "Starting hbot_driver and hbot_web..."
ros2 launch hbot_bringup base_bringup.launch.py use_ekf:=False > "$HBOT_WS/log/web_bringup.log" 2>&1
