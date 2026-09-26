# Hướng dẫn Mô phỏng HBOT: Mapping & Localization (Gazebo + Nav2)

Tài liệu này hướng dẫn chạy **mapping** (dựng bản đồ bằng SLAM) và
**localization + navigation** (định vị trên bản đồ có sẵn và điều hướng
tự động) trong môi trường mô phỏng Gazebo của robot HBOT.

Mô phỏng được cấu hình để chạy **giống hệt robot thật**: cùng cây TF, cùng
topic, cùng bộ SLAM (Cartographer), cùng Nav2 và cùng file tham số
`nav2_params.yaml`. Nhờ vậy quy trình bạn luyện tập trên sim áp dụng gần như
nguyên vẹn khi lên phần cứng.

> **Trạng thái kiểm thử (2026-08-29, headless, laptop dev):** cả 4 luồng đã
> chạy qua các script ở mục 6 —
> `dev_sim_smoke` (spawn + `/scan` `/odom` `/imu` + cây TF + lái thử),
> `dev_sim_mapping_smoke` (Cartographer phát `/map` + `map→odom`),
> `dev_sim_nav_smoke` (SLAM + Nav2, `NavigateToPose (1.2, 0)` → `SUCCEEDED`),
> `dev_sim_localization_smoke` (AMCL hội tụ + Nav2, `NavigateToPose (0.8, 0)`
> → `SUCCEEDED`). EKF (`robot_localization`) không chạy trong sim.

---

## 1. Kiến trúc mô phỏng

```
                 ┌──────────────────── Gazebo Sim (ign gazebo / gz sim) ───────────────────────┐
                 │  world: hbot_house.world                                                    │
                 │  robot: spawn từ topic /robot_description (ros_gz_sim create)               │
                 │  system DiffDrive + JointStatePublisher ──► odom, tf, joint_states          │
                 │  sensor gpu_lidar                 ──► scan   (frame: laser)                  │
                 │  sensor imu                       ──► imu    (frame: imu_link)               │
                 └───────────────▲───────────────────────────────────┬────────────────────────┘
                                 │ ros_gz_bridge (config/gz_bridge.yaml): gz topic ⇄ ROS topic │
                                 │ /cmd_vel                          │ /scan /odom /tf /clock
                                 │                                   ▼
        ┌────────────────┐   ┌───┴────────────┐         ┌──────────────────────────────┐
        │ teleop / joy   │──►│  (nav) Nav2    │────────►│  SLAM  hoặc  Localization     │
        │ RViz "2D Goal" │   │ controller,    │  /cmd_vel│  • Cartographer (slam:=True) │
        └────────────────┘   │ planner, BT... │◄────────│  • map_server + AMCL          │
                             └────────────────┘  /scan  │    (slam:=False)             │
                                                        │  ──► TF map → odom            │
                                                        └──────────────────────────────┘
```

### Cây TF (giống robot thật)

```
map ──(Cartographer hoặc AMCL)──► odom ──(gz DiffDrive)──► base_footprint
                                                                     │ (robot_state_publisher, tĩnh)
                                                    ┌────────────────┼─────────────────┐
                                                 base_link        (== base_footprint)
                                                    ├── laser      (x=0.08, z=0.14)
                                                    ├── imu_link   (gốc base)
                                                    ├── left_wheel_link / right_wheel_link
                                                    └── front_caster
```

### Topic chính

| Topic | Kiểu | Nguồn |
|---|---|---|
| `/scan` | `sensor_msgs/LaserScan` | gz `gpu_lidar` qua ros_gz_bridge (mô phỏng YDLidar X3: `lidar_sensor` trong `hbot_geometry.yaml`) |
| `/odom` | `nav_msgs/Odometry` | system DiffDrive của gz sim (qua bridge) |
| `/imu` | `sensor_msgs/Imu` | gz IMU sensor (qua bridge) |
| `/cmd_vel` | `geometry_msgs/Twist` | Nav2 (hoặc teleop) → bridge → DiffDrive |
| `/map` | `nav_msgs/OccupancyGrid` | Cartographer (mapping) hoặc `map_server` (localization) |
| `/tf`, `/tf_static` | `tf2_msgs/TFMessage` | Gazebo + `robot_state_publisher` + SLAM/AMCL |

> **Khác biệt so với robot thật:** trên phần cứng, `/odom` do driver Yahboom +
> EKF (`robot_localization`) sinh ra, và `twist_mux` trong `base_bringup.launch.py`
> trọng tài giữa teleop và Nav2. Trong sim, Gazebo phát `/odom` trực tiếp và
> Nav2 ghi thẳng vào `/cmd_vel` (không có `twist_mux`). Mọi thứ còn lại giống nhau.

---

## 2. Chuẩn bị (build workspace)

Yêu cầu: **Ubuntu 22.04 + ROS 2 Humble + Gazebo Sim Fortress** (`ros-humble-ros-gz`,
kéo theo Fortress), đã cài `ros-humble-cartographer-ros`. Gazebo Classic không
còn được dùng (xem `src/hbot_simulation/README.md`).

```bash
sudo apt install ros-humble-ros-gz ros-humble-cartographer-ros
```

```bash
cd ~/Documents/03.MyProjects/hbot_ws-sim-parity     # thư mục workspace

# Lấy toàn bộ submodule (navigation2, slam_toolbox, ...)
git submodule update --init --recursive

# Build. Lần đầu build navigation2 từ nguồn mất ~10–15 phút.
./build_packages.sh
```

> Nếu máy **chưa cài** `geographic_msgs`, gói `robot_localization` sẽ lỗi build.
> Gói này chỉ dùng trên phần cứng (EKF), không cần cho sim — bỏ qua bằng:
> `colcon build --packages-ignore robot_localization` hoặc
> `sudo apt install ros-humble-geographic-msgs`.

> **Cách khác (khuyến nghị cho lớp học):** dùng Docker
> `docker/laptop/` — xem `docker/laptop/README.md`. Ảnh Docker đã có sẵn
> Nav2 nên không phải build lâu.

Mỗi lần mở terminal mới, nạp môi trường:

```bash
cd ~/Documents/03.MyProjects/hbot_ws-sim-parity
export HBOT_WS=$PWD
source scripts/ros_env.sh        # set ROS_DOMAIN_ID=9, LIDAR_MODEL, source install/
```

---

## 3. MAPPING — dựng bản đồ bằng SLAM

### 3.1. Khởi chạy

```bash
./scripts/bringup.sh \
    simulation_mode:=True \
    use_sim_time:=True \
    slam:=True \
    enable_navigation:=True \
    run_rviz:=True
```

Lệnh này bật: Gazebo (world + robot) → `robot_state_publisher` →
**Cartographer** (`carto_mapping.lua`) → **Nav2** (điều khiển/lập kế hoạch) →
RViz.

Thêm `headless:=True` nếu muốn chạy Gazebo không giao diện (CI, máy yếu).

### 3.2. Kiểm tra hệ thống đã lên đúng

Ở terminal thứ hai (`source scripts/ros_env.sh` trước):

```bash
ros2 node list                 # phải thấy: cartographer_node, controller_server, planner_server,
                               #            bt_navigator, gazebo, robot_state_publisher ...
ros2 topic hz /scan            # ~10 Hz
ros2 topic hz /odom            # ~30 Hz
ros2 run tf2_ros tf2_echo map odom          # Cartographer đang phát TF map→odom
ros2 run tf2_ros tf2_echo base_link laser   # phải ra: [0.08, 0.0, 0.14]
```

### 3.3. Lái robot để quét bản đồ

**Cách A — RViz:** dùng nút *2D Goal Pose*, đặt các đích liên tiếp để Nav2 tự
lái robot đi quét.

**Cách B — bàn phím:**

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard \
    --ros-args -p stamped:=false -r cmd_vel:=/cmd_vel
```

**Cách C — script tự lái sẵn** (chạy pattern tuần tra rồi tự lưu map):

```bash
./scripts/dev_sim_build_map.sh          # lưu vào src/hbot_bringup/maps/hbot_house_sim.*
```

Mẹo quét tốt: đi chậm, cho robot **quay tại chỗ 360°** ở vài vị trí để
Cartographer đóng vòng (loop closure); đi hết các phòng/hành lang; quay lại
điểm xuất phát.

### 3.4. Lưu bản đồ

Khi bản đồ trong RViz đã đủ, ở terminal khác:

```bash
ros2 run nav2_map_server map_saver_cli \
    -f ~/Documents/03.MyProjects/hbot_ws-sim-parity/src/hbot_bringup/maps/my_map \
    --ros-args -p use_sim_time:=true
```

Sinh ra `my_map.pgm` (ảnh) + `my_map.yaml` (metadata: resolution, origin,
ngưỡng). Xem thêm `docs/map_saving_guide.md`.

Nếu muốn map này thành **map mặc định** cho chế độ localization, đặt tên
`hbot_house_sim.*`, để trong `src/hbot_bringup/maps/`, rồi build lại
`hbot_bringup` (`setup.py` đã cài sẵn glob `maps/*`).

---

## 4. LOCALIZATION + NAVIGATION — chạy trên bản đồ có sẵn

### 4.1. Khởi chạy

Dùng map mặc định đi kèm (`hbot_house_sim.yaml`):

```bash
./scripts/bringup.sh \
    simulation_mode:=True \
    use_sim_time:=True \
    slam:=False \
    enable_navigation:=True \
    run_rviz:=True
```

Hoặc chỉ định map riêng:

```bash
./scripts/bringup.sh simulation_mode:=True use_sim_time:=True slam:=False \
    enable_navigation:=True run_rviz:=True \
    map:=/đường/dẫn/tuyệt/đối/my_map.yaml
```

Lệnh này bật: Gazebo → `robot_state_publisher` → **`map_server` + AMCL**
(`localization_launch.py`) → **Nav2** → RViz.

### 4.2. Đặt vị trí khởi tạo (bắt buộc)

AMCL **không** phát TF `map→odom` cho tới khi biết robot đang ở đâu.

**Trong RViz:** bấm *2D Pose Estimate*, click + kéo tại đúng vị trí/hướng
robot trên bản đồ. Đám mây particle sẽ hội tụ về quanh robot.

**Bằng dòng lệnh** — với map mặc định `hbot_house_sim`, robot xuất hiện gần
gốc bản đồ nên đặt pose khởi tạo tại `(0, 0, 0)` là đủ để AMCL hội tụ:

```bash
ros2 topic pub -1 /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
  '{header: {frame_id: map},
    pose: {pose: {position: {x: 0.0, y: 0.0, z: 0.0}, orientation: {w: 1.0}},
           covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0, 0,0,0,0,0,0,
                        0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}'
```

### 4.3. Kiểm tra AMCL đã hội tụ

```bash
ros2 topic echo /amcl_pose --once            # pose gần đúng vị trí thật
ros2 run tf2_ros tf2_echo map odom           # đã có TF map→odom
```

### 4.4. Gửi đích điều hướng

**RViz:** nút *2D Goal Pose*.

**Dòng lệnh:**

```bash
ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
  "{pose: {header: {frame_id: map},
           pose: {position: {x: 0.8, y: 0.0, z: 0.0}, orientation: {w: 1.0}}}}"
```

Kết quả mong đợi: `Goal finished with status: SUCCEEDED`, robot dừng trong
bán kính `xy_goal_tolerance` (0.25 m, xem `nav2_params.yaml`).

Điều hướng qua nhiều điểm:

```bash
ros2 action send_goal /navigate_through_poses nav2_msgs/action/NavigateThroughPoses \
  "{poses: [ {header: {frame_id: map}, pose: {position: {x: 0.5, y: 0.0}, orientation: {w: 1.0}}},
             {header: {frame_id: map}, pose: {position: {x: 0.5, y: 0.5}, orientation: {w: 1.0}}} ]}"
```

---

## 5. Tham số của `bringup.sh` (`hbot_bringup.launch.py`)

| Tham số | Mặc định | Ý nghĩa |
|---|---|---|
| `simulation_mode` | `False` | `True` = Gazebo; `False` = phần cứng Yahboom + lidar thật |
| `use_sim_time` | `False` | Đặt `True` khi `simulation_mode:=True` (dùng `/clock` của Gazebo) |
| `slam` | `True` | `True` = Cartographer dựng map; `False` = `map_server`+AMCL trên map có sẵn |
| `enable_navigation` | `False` | `True` = bật ngăn xếp Nav2 (controller/planner/BT/...) |
| `map` | `…/maps/hbot_house_sim.yaml` | File map YAML cho `slam:=False` |
| `run_rviz` | `False` | Mở RViz với cấu hình `config/hbot.rviz` |
| `headless` | `False` | `True` = chỉ chạy server gz sim (`-s --headless-rendering`), không mở GUI |
| `params_file` | `config/nav2_params.yaml` | Tham số Nav2 |
| `slam_params_file` | `config/slam_params.yaml` | (chỉ dùng nếu bật lại nhánh slam_toolbox) |

**4 chế độ chính:**

| Mục tiêu | Lệnh |
|---|---|
| Mapping (sim) | `simulation_mode:=True use_sim_time:=True slam:=True enable_navigation:=True run_rviz:=True` |
| Localization + Nav (sim) | `simulation_mode:=True use_sim_time:=True slam:=False enable_navigation:=True run_rviz:=True` |
| Mapping (robot thật) | `simulation_mode:=False use_sim_time:=False slam:=True enable_navigation:=True run_rviz:=True` |
| Localization + Nav (robot thật) | `simulation_mode:=False use_sim_time:=False slam:=False enable_navigation:=True map:=/abs/map.yaml` |

---

## 6. Script hỗ trợ kiểm thử (headless, không cần GUI)

| Script | Tác dụng |
|---|---|
| `scripts/dev_sim_smoke.sh` | Chỉ Gazebo: kiểm tra spawn, `/scan` `/odom` `/imu`, cây TF, lái thử |
| `scripts/dev_sim_mapping_smoke.sh` | Gazebo + Cartographer: kiểm tra `/map`, TF `map→odom` |
| `scripts/dev_sim_nav_smoke.sh` | Gazebo + Cartographer + Nav2: gửi 1 goal, kiểm tra `SUCCEEDED` |
| `scripts/dev_sim_build_map.sh` | Tự lái tuần tra rồi lưu map ra `src/hbot_bringup/maps/` |
| `scripts/dev_sim_localization_smoke.sh` | Gazebo + AMCL + Nav2 trên map có sẵn: set initial pose, gửi goal |

Ví dụ:

```bash
./scripts/dev_sim_nav_smoke.sh 40 1.2 0.0     # warmup 40s, goal (1.2, 0.0)
```

---

## 7. Xử lý sự cố

| Triệu chứng | Nguyên nhân / cách xử lý |
|---|---|
| `package 'nav2_bringup' not found` | Chưa build submodule `navigation2`. Chạy `git submodule update --init` rồi `./build_packages.sh`. |
| `package 'hls_lfcd_lds_driver' not found` khi `simulation_mode:=True` | Đã được xử lý — launch bỏ qua driver lidar phần cứng trong sim. Nếu vẫn gặp, build lại `hbot_bringup`. |
| Robot **không nhúc nhích** khi gửi goal | Kiểm tra `ros2 topic echo /cmd_vel` có dữ liệu. Trong sim, Nav2 phải ghi thẳng `/cmd_vel` (nhánh `_sim`). Kiểm tra plugin diff-drive log `Subscribed to [/cmd_vel]`. |
| Nav2 báo `Failed to make progress`, `Collision Ahead` | Lidar "nhìn thấy" thân robot → vòng chướng ngại ảo. Đảm bảo dùng URDF đã cập nhật (hộp thân cao 0.11 m, dưới mặt phẳng quét 0.14 m). `ros2 topic echo /scan --field ranges` không được có giá trị ~0.15–0.20 m ở mọi hướng. |
| `controller_server: Control loop missed its desired rate` | Máy quá tải (Gazebo + Nav2 + RViz). Thêm `headless:=True`, tắt RViz, hoặc giảm tải máy. Cảnh báo lẻ tẻ không ảnh hưởng kết quả. |
| `lifecycle_manager_navigation: Failed to change state for node: controller_server ... async_send_request failed` / `Aborting bringup` | Máy quá tải lúc khởi động: `controller_server` chưa kịp trả lời `get_state` trong thời gian chờ của lifecycle manager nên cả stack Nav2 bị hủy. Thường gặp khi bật đồng thời sim + localization + Nav2 trên laptop yếu. Cách xử lý: đóng bớt ứng dụng, chạy `headless:=True` + tắt RViz, hoặc khởi động sim trước (`enable_navigation:=False`), đợi Gazebo ổn định rồi mới bật Nav2. Trong script `dev_sim_localization_smoke.sh` tăng `warmup` (tham số thứ 2) lên `60`. |
| AMCL không phát `map→odom` | Chưa đặt *2D Pose Estimate* / chưa publish `/initialpose`. |
| `Invalid frame ID "odom" ... frame does not exist` (vài giây đầu) | Bình thường — Gazebo mất ~2–3 s mới phát `odom→base_footprint`. Tự hết. |
| `ros2` không thấy topic nào | Sai `ROS_DOMAIN_ID`. Chạy `export ROS_DOMAIN_ID=9` (hoặc `source scripts/ros_env.sh`). |
| Gazebo mở nhưng đen/không robot | X11/GPU (gz sim cần OpenGL 3.3 cho ogre2). Thử `headless:=True` để tách vấn đề, hoặc kiểm tra `/dev/dri`. |
| Có `/clock` nhưng không có `/scan`/`/odom` | Bridge chưa chạy hoặc tên topic gz lệch: `ign topic -l` (Harmonic: `gz topic -l`) phải có `/scan`, `/odom`; so với `config/gz_bridge.yaml`. |

---

## 8. Thông số mô hình robot (sim ↔ thật)

Mô hình sim (`hbot_description/urdf/hbot.urdf.xacro`) được đồng bộ với URDF
robot thật (`hbot_bringup/config/hbot.urdf`) và tham số driver
(`hbot_bringup/config/yahboom_driver_params.yaml`):

| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Kiểu truyền động | vi sai (differential drive) | |
| Đường kính bánh | `0.065 m` (bán kính `0.0325 m`) | khớp `wheel_diameter` |
| Khoảng cách 2 bánh | `0.20 m` | khớp `wheel_track` của driver |
| `base_footprint → base_link` | trùng nhau (0,0,0) | giống robot thật |
| `base_link → laser` | `x=0.08, z=0.14`, không xoay yaw | giống robot thật |
| `base_link → imu_link` | (0,0,0) | giống robot thật |
| Lidar mô phỏng | YDLidar X3: 360°, 8 Hz, 0.12–8 m | gz `gpu_lidar` |
| Footprint Nav2 | chữ nhật `0.18 × 0.24 m` | `nav2_params.yaml`, không dùng `robot_radius` |
| Bộ điều khiển local | Regulated Pure Pursuit (RPP) | `desired_linear_vel: 0.2` |
| SLAM | Cartographer (`carto_mapping.lua`) | tracking frame `base_footprint` |
