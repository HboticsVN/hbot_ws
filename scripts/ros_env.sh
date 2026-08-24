#!/bin/bash
# Shared ROS 2 + workspace environment setup - sourced by bringup.sh and
# web_bringup.sh so the two entry points can't drift out of sync on which
# env vars/defaults they export. They used to duplicate this block
# independently, and had already drifted: LIDAR_MODEL only existed in
# bringup.sh, so mapping/navigation launched from the web dashboard (which
# runs as a subprocess of hbot_web_node, itself started by web_bringup.sh)
# silently defaulted to the wrong lidar driver. See agent/walkthrough.md,
# 2026-08-25 entry.
#
# start_mapping.sh / start_navigation.sh (src/hbot_web/hbot_web/scripts/)
# also source this - they only ever run as subprocesses of hbot_web_node,
# which already has this exact environment (inherited from whichever of the
# two scripts below started it), so re-sourcing here is a cheap no-op in
# practice. It's done explicitly anyway, via $HBOT_WS, so those scripts are
# self-sufficient rather than silently dependent on process-tree
# inheritance - they're installed deep inside hbot_web's Python package
# share dir with no stable relative path back to this file, so they can't
# find it without $HBOT_WS (which is why it's the one variable this file
# requires as input, rather than a local, non-exported shell var like
# bringup.sh/web_bringup.sh used to use - anything only those two scripts
# ever `source` this doesn't need to survive a process boundary, but
# start_mapping.sh/start_navigation.sh do).
#
# Usage: `export HBOT_WS=<absolute workspace root>`, then
# `source "$HBOT_WS/scripts/ros_env.sh"`. Does not set -e itself - that's
# the caller's call.

ros_prefix="/opt/ros/humble"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-9}"
export CONTROLLER="${CONTROLLER:-yahboom}"
export LIDAR_MODEL="${LIDAR_MODEL:-ydlidar_x3}"
export PATH="$ros_prefix/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export AMENT_PREFIX_PATH="${AMENT_PREFIX_PATH:+$AMENT_PREFIX_PATH:}$ros_prefix"
export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:+$CMAKE_PREFIX_PATH:}$ros_prefix"

python_version="$(/usr/bin/python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
ros_python_path="$ros_prefix/lib/python${python_version}/site-packages"
ros_python_local_path="$ros_prefix/local/lib/python${python_version}/dist-packages"

if [ -d "$ros_python_path" ]; then
	export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$ros_python_path"
fi

if [ -d "$ros_python_local_path" ]; then
	export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$ros_python_local_path"
fi

if [ -f "$ros_prefix/setup.bash" ]; then
	source "$ros_prefix/setup.bash"
fi

source "$HBOT_WS/install/setup.bash"
