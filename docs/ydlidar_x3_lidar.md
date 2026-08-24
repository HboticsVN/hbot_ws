# YDLidar X3 Pro Integration Guide

This guide covers the YDLidar X3 Pro LiDAR support added alongside the
default LDS-01, and the manual steps its underlying SDK needs before it
will build in this workspace.

---

## Overview

- **Package**: `ydlidar_ros2_driver` (ROS 2 node) + `YDLidar-SDK-master`
  (its C++ SDK dependency), both nested inside one git repo/submodule at
  [`src/ydlidar_x3`](../src/ydlidar_x3).
- **Repo**: [`git@github.com:HbotVN/ydlidar-ros2-driver.git`](https://github.com/HbotVN/ydlidar-ros2-driver),
  registered in [`.gitmodules`](../.gitmodules) like every other `src/`
  package.
- **Selection**: chosen at bringup time via the `LIDAR_MODEL` env var,
  alongside the existing default `lds01` (Turtlebot3-compatible LDS-01 via
  the apt-installed `hls_lfcd_lds_driver`). See
  [`hbot_bringup.launch.py`](../src/hbot_bringup/launch/hbot_bringup.launch.py).

```bash
LIDAR_MODEL=ydlidar_x3 ./bringup.sh simulation_mode:=False use_sim_time:=False ...
```

`scripts/ros_env.sh` is the single place that exports `LIDAR_MODEL`
(default `ydlidar_x3` on this workspace) for both `bringup.sh` and
`web_bringup.sh`/the web dashboard's mapping/navigation launches — see
[`scripts/ros_env.sh`](../scripts/ros_env.sh).

---

## One-time setup: build & install the YDLidar SDK system-wide

`ydlidar_ros2_driver`'s `CMakeLists.txt` does `find_package(ydlidar_sdk
REQUIRED)`. The SDK (`src/ydlidar_x3/YDLidar-SDK-master`) is a bare CMake
project with no `package.xml`, so colcon can't express a build-order
dependency between it and the driver — building both together races and
`find_package(ydlidar_sdk)` fails intermittently. Because of that, the SDK
is **not** built by colcon at all:

- `src/ydlidar_x3/YDLidar-SDK-master/COLCON_IGNORE` tells colcon to skip it
  entirely (confirm with `colcon list` — only `ydlidar_ros2_driver` should
  show up).
- Instead, build and install it once, system-wide, the way its own
  upstream instructions intend:

  ```bash
  cd src/ydlidar_x3/YDLidar-SDK-master
  mkdir -p build && cd build
  cmake ..
  make
  sudo make install     # installs ydlidar_sdkConfig.cmake under
                         # /usr/local/lib/cmake/ydlidar_sdk/, headers/libs
                         # under /usr/local/{include,lib}
  ```

Until this has been run on a given machine (dev laptop, the `docker/pi`
build container, etc.), `ydlidar_ros2_driver` will fail to colcon-build
with a `find_package(ydlidar_sdk)` error. Once installed, a normal:

```bash
./build_packages.sh ydlidar_ros2_driver
```

builds clean.

> [!NOTE]
> `sudo make install` writes root-owned files under `build/` (and
> `/usr/local/...`). If you ever need to blow away and re-clone
> `src/ydlidar_x3` from scratch, `rm -rf` on `YDLidar-SDK-master/build` may
> fail with `Permission denied` on those files — use `sudo rm -rf` (or move
> the whole `src/ydlidar_x3` directory aside with `mv`, which only needs
> write permission on its *parent*, not on every file inside).

---

## Configuration

Params live at
[`src/ydlidar_x3/ydlidar_ros2_driver/params/ydlidar_x3.yaml`](../src/ydlidar_x3/ydlidar_ros2_driver/params/ydlidar_x3.yaml):

```yaml
ydlidar_ros2_driver_node:
  ros__parameters:
    port: /dev/usbttl
    frame_id: laser
    baudrate: 115200
    lidar_type: 1        # TYPE_TRIANGLE
    device_type: 0        # YDLIDAR_TYPE_SERIAL
    sample_rate: 3
    reversion: false
    inverted: true
    auto_reconnect: true
    isSingleChannel: true
    support_motor_dtr: true
    ...
```

- **`port: /dev/usbttl`** — matches the udev symlink this workspace
  already standardizes on for whichever LiDAR is plugged in (see
  `usbttl.rules` under `src/lds_006_driver/scripts/initenv.sh`), rather
  than the vendor SDK's own `ydlidar` symlink
  (`src/ydlidar_x3/ydlidar_ros2_driver/startup/initenv.sh`). Keep this in
  sync with whatever udev rule is actually installed on the target
  machine.
- Full parameter reference:
  [`ydlidar_ros2_driver/README.md`](../src/ydlidar_x3/ydlidar_ros2_driver/README.md)
  and [`details.md`](../src/ydlidar_x3/ydlidar_ros2_driver/details.md)
  (per-model baudrate/sample-rate/reversion/intensity tables).

### `declare_parameter` fix

`ydlidar_ros2_driver_node.cpp` originally called the argument-less
`declare_parameter(name)` overload, which existed pre-Foxy but was removed
from Humble's `rclcpp::Node` API (only overloads that take a default value
or explicit `ParameterType` remain) — every call site failed to compile
with "no matching function for call". Every one of the 21 call sites is
now `declare_parameter(name, var)`, passing the same local variable the
next line already reads the resolved value into as the default, so
behavior (including picking up `ydlidar_x3.yaml` overrides) is unchanged.

---

## Launch wiring

`hbot_bringup.launch.py`'s `ydlidar_x3` branch includes
`ydlidar_ros2_driver`'s `x3_ydlidar_launch.py` and explicitly passes
`params_file` pointing at `ydlidar_x3.yaml`:

```python
lidar_node = IncludeLaunchDescription(
  PythonLaunchDescriptionSource(os.path.join(
    get_package_share_directory('ydlidar_ros2_driver'),
    'launch', 'x3_ydlidar_launch.py'
  )),
  launch_arguments={
    'params_file': os.path.join(
      get_package_share_directory('ydlidar_ros2_driver'),
      'params', 'ydlidar_x3.yaml')
  }.items(),
)
```

This explicit `launch_arguments` pass-through is required, not
cosmetic: `hbot_bringup.launch.py` already declares its own top-level
`params_file` argument for Nav2 (default `nav2_params.yaml`) earlier in
the same function. `LaunchConfiguration` names aren't scoped per-include —
they're shared across the whole launch tree unless reset by a scoped
`GroupAction` — and `DeclareLaunchArgument` never overwrites an
already-set value. Without the explicit override, `x3_ydlidar_launch.py`'s
own `params_file` declare would silently no-op, the node would receive
`nav2_params.yaml` (which has no `ydlidar_ros2_driver_node:` block), and
every parameter — including `port` — would fall through to the hardcoded
C++ defaults (`/dev/ydlidar`), regardless of what `ydlidar_x3.yaml` says.
(This is safe from leaking into the Nav2 `GroupAction`s, which use their
own `params_file`, because the lidar include lives inside
`hardware_nodes`, a scoped `GroupAction`.)

`x3_ydlidar_launch.py` itself was rewritten from a `LifecycleNode` (using
pre-Foxy `launch_ros` kwargs — `node_executable`/`node_name`/
`node_namespace`, renamed to `executable`/`name`/`namespace` since Foxy) to
a plain `Node`, matching what `ydlidar_ros2_driver_node.cpp` actually is: a
plain `rclcpp::Node` that starts scanning as soon as it comes up, not a
real lifecycle-managed node. No `static_transform_publisher` for the
`laser` frame is added here, for the same reason the LDS-01 include
doesn't add one — `hbot_description`'s URDF already defines
`base_link -> laser`, published by `robot_state_publisher`.

---

## Verifying on hardware

```bash
LIDAR_MODEL=ydlidar_x3 ./scripts/bringup.sh simulation_mode:=False use_sim_time:=False slam:=True enable_navigation:=True
```

A successful connection logs something like:

```
[YDLIDAR] Connection established in [/dev/usbttl][115200]
```

If instead you see:

```
[CYdLidar] Error, cannot bind to the specified serial port[/dev/ydlidar]
```

the driver fell back to its hardcoded default port — check that
`hbot_bringup.launch.py`'s `ydlidar_x3` branch is still passing
`params_file` explicitly (see above), and that `/dev/usbttl` actually
exists (`ls -l /dev/usbttl`; replug the LiDAR if the udev symlink hasn't
appeared yet).

Then confirm scan data is flowing:

```bash
ros2 topic echo /scan --once
```

---

## Related files

- [`src/ydlidar_x3`](../src/ydlidar_x3) — the submodule itself.
- [`src/hbot_bringup/launch/hbot_bringup.launch.py`](../src/hbot_bringup/launch/hbot_bringup.launch.py) — `LIDAR_MODEL` selection.
- [`scripts/ros_env.sh`](../scripts/ros_env.sh) — exports `LIDAR_MODEL` for every entry point.
- [`agent/walkthrough.md`](../agent/walkthrough.md) — full change history/debugging log for this integration.
