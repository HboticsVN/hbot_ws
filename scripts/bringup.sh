#!/bin/bash

set -e

export HBOT_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

source "$HBOT_WS/scripts/ros_env.sh"

ros2 launch hbot_bringup hbot_bringup.launch.py "$@"
