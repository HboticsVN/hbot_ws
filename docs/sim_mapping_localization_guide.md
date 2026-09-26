# HBOT – Bài thực hành: Mapping & Localization trên Simulation

> **Tài liệu khóa học.** Workspace `hbot_ws` (ROS 2 Humble, robot vi sai HBOT).
> Mọi lệnh chạy từ thư mục gốc workspace
> (`~/Documents/03.MyProjects/hbot_ws`, hoặc `~/hbot_ws` trên máy khác).
>
> Tài liệu tham chiếu chi tiết (kiến trúc, đầy đủ tham số, bảng sự cố):
> [`simulation_guide.md`](simulation_guide.md). Tài liệu này là **giáo án
> từng bước** cho học viên.

---

## 0. Mục tiêu buổi học

Sau buổi học, học viên:

1. Hiểu 2 cờ độc lập của `bringup.sh`: `simulation_mode` và `slam`.
2. Chạy được **Bài 1 – Mapping**: dựng bản đồ bằng Cartographer rồi lưu lại.
3. Chạy được **Bài 2 – Localization + Navigation**: định vị bằng AMCL trên
   bản đồ có sẵn và cho robot tự điều hướng tới đích.
4. Biết mô phỏng **giống robot thật** ở điểm nào và **khác** ở điểm nào.

### Sim giống robot thật (điều quan trọng nhất của buổi học)

Mô hình URDF trong sim được đồng bộ với URDF robot thật
(`src/hbot_bringup/config/hbot.urdf`) và tham số driver
(`yahboom_driver_params.yaml`):

| Hạng mục | Sim và thật đều dùng |
|---|---|
| Cây TF | `map → odom → base_footprint(≡ base_link) → laser (x=0.08, z=0.14) / imu_link` |
| Truyền động | vi sai, `wheel_separation = 0.20 m`, `wheel_diameter = 0.065 m` |
| Lidar | 360°, 10 Hz, tầm ~0.12–12 m (sim mô phỏng YDLidar X3) |
| SLAM | Cartographer (`carto_mapping.lua`), tracking frame `base_footprint` |
| Nav2 | cùng `nav2_params.yaml`, footprint chữ nhật `0.18 × 0.24 m`, controller RPP |

### Sim khác robot thật

| | Robot thật | Sim |
|---|---|---|
| `/odom` + TF `odom→base_footprint` | driver Yahboom + EKF `robot_localization` | system DiffDrive của gz sim phát trực tiếp qua ros_gz_bridge (không chạy EKF) |
| Trọng tài `/cmd_vel` | `twist_mux` trong `base_bringup.launch.py` (teleop ⇄ Nav2) | không có `twist_mux`; Nav2 ghi thẳng `/cmd_vel` |
| Lidar | driver phần cứng (`ydlidar_x3` / `lds`) | gz `gpu_lidar`; driver phần cứng được **bỏ qua** khi `simulation_mode:=True` |

> **Lưu ý:** phiên bản trước của sim có lỗi "gửi goal nhưng robot đứng im"
> (do remap `cmd_vel_nav_smoothed` chỉ hợp lệ trên phần cứng). Lỗi này **đã
> được sửa** — nhánh sim của `hbot_bringup.launch.py` không còn remap, Nav2
> điều khiển robot trực tiếp. Không cần workaround `topic_tools relay` nữa.

---

## 1. Luồng hoạt động của `bringup.sh`

`scripts/bringup.sh` → `ros2 launch hbot_bringup hbot_bringup.launch.py`.
Launch file rẽ nhánh theo các cờ:

| Cờ | Giá trị | Ý nghĩa |
|---|---|---|
| `simulation_mode` | `True` | Gazebo (`hbot_house.world`) + spawn robot; **không** chạy driver / lidar thật |
| | `False` | Robot thật: driver Yahboom + lidar vật lý |
| `slam` | `True` | **Mapping** – Cartographer dựng bản đồ mới |
| | `False` | **Localization** – `map_server` + AMCL định vị trên bản đồ có sẵn |
| `enable_navigation` | `True`/`False` | Bật/tắt stack Nav2 (planner/controller/bt_navigator) |
| `use_sim_time` | `True` | Dùng `/clock` của Gazebo – **luôn `True` khi `simulation_mode:=True`** |
| `run_rviz` | `True`/`False` | Mở RViz với config `hbot.rviz` |
| `headless` | `True`/`False` | `True` = chỉ chạy server gz sim, không GUI (máy yếu / CI). Mặc định `False` |
| `map` | đường dẫn `.yaml` | Bản đồ cho `slam:=False`. Mặc định: map mẫu `hbot_house_sim.yaml` đi kèm |

Thành phần theo chế độ:

- **Sim + SLAM**: Gazebo → `robot_state_publisher` → `cartographer_node` +
  `cartographer_occupancy_grid_node` (publish `/map`, TF `map→odom`).
- **Sim + Localization**: Gazebo → `robot_state_publisher` →
  `nav2_bringup/localization_launch.py` (`map_server` + `amcl`).
- Cấu hình: `src/hbot_bringup/config/` → `carto_mapping.lua`,
  `nav2_params.yaml` (chứa cả block `amcl`), `slam_params.yaml`.

---

## 2. Chuẩn bị môi trường (làm 1 lần)

### 2.1. Lấy source submodule

```bash
git submodule update --init --recursive
```

### 2.2. Build

**Cách A (Docker – khuyến nghị cho khóa học):** không phải lo dependency.

```bash
xhost +local:root
cd docker/laptop
docker compose build
docker compose run --rm hbot_laptop bash    # mở shell trong container
```

**Cách B (build native trên máy):** cần build cả stack Nav2/SLAM fork.

```bash
sudo apt update
rosdep install --from-paths src --ignore-src -r -y
conda deactivate 2>/dev/null                 # KHÔNG dùng Python của Conda/venv
./build_packages.sh                          # lần đầu build Nav2 mất ~10–15 phút
```

> `robot_localization` sẽ lỗi build nếu thiếu `geographic_msgs`. Gói này chỉ
> dùng trên phần cứng (EKF), không cần cho sim — bỏ qua:
> `colcon build --packages-ignore robot_localization`
> hoặc cài `sudo apt install ros-humble-geographic-msgs`.
> Kiểm tra đủ package: `ros2 pkg prefix nav2_bringup cartographer_ros ros_gz_sim ros_gz_bridge`.

### 2.3. Source workspace ở **mỗi** terminal mới

```bash
export HBOT_WS=$PWD
source scripts/ros_env.sh    # set ROS_DOMAIN_ID=9, CONTROLLER=yahboom, LIDAR_MODEL, source ROS + install/
```

> Tất cả terminal phải cùng `ROS_DOMAIN_ID=9` mới thấy topic của nhau.

---

## 3. Bài 1 – Sim + SLAM (dựng bản đồ)

### 3.1. Khởi chạy

```bash
./bringup.sh simulation_mode:=True use_sim_time:=True slam:=True \
    enable_navigation:=True run_rviz:=True
```

Thêm `headless:=True` nếu máy yếu (bỏ GUI Gazebo). Chờ tới khi:

- Cửa sổ Gazebo hiện robot trong `hbot_house`.
- RViz hiện lidar scan + bản đồ bắt đầu hình thành.

### 3.2. Kiểm tra nhanh (terminal thứ 2, đã source như 2.3)

```bash
ros2 node list                              # có /cartographer_node, /cartographer_occupancy_grid_node, Nav2...
ros2 topic hz /scan                         # ~10 Hz
ros2 topic hz /odom                         # ~30 Hz
ros2 run tf2_ros tf2_echo base_link laser   # phải ra [0.08, 0.0, 0.14], không xoay
ros2 run tf2_ros tf2_echo map odom          # Cartographer đang phát TF map→odom
```

### 3.3. Lái robot đi quét bản đồ

Chọn **một** cách:

- **RViz – nút *2D Goal Pose*:** đặt các đích liên tiếp, Nav2 tự lái robot đi quét.
- **Bàn phím:**
  ```bash
  ros2 run teleop_twist_keyboard teleop_twist_keyboard \
      --ros-args -p stamped:=false -r cmd_vel:=/cmd_vel
  ```

Lái **chậm**, cho robot **quay tại chỗ 360°** ở vài vị trí để Cartographer
đóng vòng (loop closure); đi hết các phòng/hành lang; quay lại điểm xuất phát.

### 3.4. Lưu bản đồ

```bash
mkdir -p src/hbot_bringup/maps
ros2 run nav2_map_server map_saver_cli \
    -f src/hbot_bringup/maps/hbot_house \
    --ros-args -p use_sim_time:=true
```

Sinh ra `hbot_house.pgm` + `hbot_house.yaml`. Chi tiết & phương án khác:
[`map_saving_guide.md`](map_saving_guide.md).

> Muốn map này thành **map mặc định** cho Bài 2: đặt tên `hbot_house_sim.*`
> trong `src/hbot_bringup/maps/` rồi build lại `hbot_bringup`
> (`setup.py` đã cài sẵn glob `maps/*`).

### 3.5. (Tùy chọn) Gửi goal điều hướng ngay khi đang map

Nếu chạy với `enable_navigation:=True`: dùng nút **2D Goal Pose** trong RViz,
hoặc:

```bash
ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
  "{pose: {header: {frame_id: map}, pose: {position: {x: 1.2, y: 0.0}, orientation: {w: 1.0}}}}"
```

Kỳ vọng: `Goal finished with status: SUCCEEDED`, robot tự chạy tới đích.

---

## 4. Bài 2 – Sim + Localization + Navigation (bản đồ có sẵn)

### 4.1. Khởi chạy

Dùng **map mẫu đi kèm** (`hbot_house_sim.yaml`, không cần tham số `map:`):

```bash
./bringup.sh simulation_mode:=True use_sim_time:=True slam:=False \
    enable_navigation:=True run_rviz:=True
```

Hoặc dùng bản đồ tự dựng ở Bài 1 (đường dẫn **tuyệt đối**):

```bash
./bringup.sh simulation_mode:=True use_sim_time:=True slam:=False \
    enable_navigation:=True run_rviz:=True \
    map:=$PWD/src/hbot_bringup/maps/hbot_house.yaml
```

### 4.2. Đặt initial pose (bắt buộc)

AMCL **không** phát TF `map→odom` cho tới khi biết robot đang ở đâu.

- **RViz:** bấm **2D Pose Estimate**, click + kéo đúng vị trí/hướng robot
  đang đứng trong Gazebo. Particle cloud của AMCL sẽ hội tụ về quanh robot.
- **Dòng lệnh** (với map mẫu `hbot_house_sim`, robot xuất hiện gần gốc bản đồ):
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
ros2 lifecycle get /map_server               # active
```

### 4.4. Gửi đích điều hướng

- **RViz:** nút **2D Goal Pose**.
- **Dòng lệnh:**
  ```bash
  ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
    "{pose: {header: {frame_id: map}, pose: {position: {x: 0.8, y: 0.0}, orientation: {w: 1.0}}}}"
  ```

Kỳ vọng: `Goal finished with status: SUCCEEDED`, robot dừng trong bán kính
`xy_goal_tolerance` (0.25 m). Đi qua nhiều điểm liên tiếp:

```bash
ros2 action send_goal /navigate_through_poses nav2_msgs/action/NavigateThroughPoses \
  "{poses: [ {header: {frame_id: map}, pose: {position: {x: 0.5, y: 0.0}, orientation: {w: 1.0}}},
             {header: {frame_id: map}, pose: {position: {x: 0.5, y: 0.5}, orientation: {w: 1.0}}} ]}"
```

**Tiêu chí đạt** (theo `docs/phase0_runbook.md`): các node lên không crash;
`/tf /odom /scan /cmd_vel` có dữ liệu đúng mode; robot đi được 5 waypoint
liên tiếp trong sim.

---

## 5. Bài 3 (nhanh) – Kiểm thử headless bằng script

Không cần GUI, hợp để chấm bài / kiểm tra máy học viên đã build đúng chưa:

| Script | Kiểm tra |
|---|---|
| `./scripts/dev_sim_smoke.sh` | Chỉ Gazebo: spawn, `/scan` `/odom` `/imu`, cây TF, lái thử |
| `./scripts/dev_sim_mapping_smoke.sh` | Gazebo + Cartographer: `/map`, TF `map→odom` |
| `./scripts/dev_sim_nav_smoke.sh 40 1.2 0.0` | Gazebo + Cartographer + Nav2: 1 goal → `SUCCEEDED` |
| `./scripts/dev_sim_localization_smoke.sh "" 60 0.8 0.0` | Gazebo + AMCL + Nav2 trên map mẫu: initial pose + goal |
| `./scripts/dev_sim_build_map.sh` | Tự lái tuần tra rồi lưu map ra `src/hbot_bringup/maps/` |

---

## 6. Sự cố thường gặp

| Triệu chứng | Nguyên nhân / xử lý |
|---|---|
| `package 'nav2_bringup' not found` | Chưa build submodule `src/navigation2` – xem 2.2, hoặc dùng Docker |
| `package 'hls_lfcd_lds_driver' / 'ydlidar_ros2_driver' not found` khi `simulation_mode:=True` | Đã xử lý trong launch (bỏ qua driver lidar thật trong sim). Nếu vẫn gặp, build lại `hbot_bringup` |
| RViz/Gazebo trống, không thấy scan | Thiếu `use_sim_time:=True`; hoặc terminal khác `ROS_DOMAIN_ID` |
| Bản đồ bị lệch/nhòe khi quay | Lái quá nhanh; đi chậm lại, tạo loop closure (quay 360° tại chỗ) |
| Robot **không nhúc nhích** khi gửi goal | `ros2 topic echo /cmd_vel` có dữ liệu không? Trong sim Nav2 ghi thẳng `/cmd_vel`; kiểm tra diff-drive log `Subscribed to [/cmd_vel]` |
| Nav2 báo `Failed to make progress` / vòng chướng ngại ảo quanh robot | Dùng URDF cũ (hộp thân cao chạm mặt phẳng quét). Build lại `hbot_description`; `ros2 topic echo /scan --field ranges` không được toàn ~0.15–0.20 m |
| `lifecycle_manager_navigation: ... Aborting bringup` | Máy quá tải lúc khởi động. Đóng bớt app; `headless:=True` + tắt RViz; hoặc bật sim trước (`enable_navigation:=False`) rồi mới bật Nav2. Script: tăng `warmup` lên 60 |
| `map:=hbot_house.yaml` báo không mở được | Phải là đường dẫn **tuyệt đối** (`$PWD/...`) |
| AMCL không hội tụ / không có `map→odom` | Chưa đặt **2D Pose Estimate** / chưa publish `/initialpose`, hoặc đặt sai vị trí |
| `Invalid frame ID "odom" ... frame does not exist` (vài giây đầu) | Bình thường – Gazebo mất ~2–3 s mới phát `odom→base_footprint`. Tự hết |
| Lỗi CMake/`colcon` lạ | Build dính Conda Python – xóa `build/ install/ log/`, build lại bằng `./build_packages.sh` |

---

## 7. Bảng lệnh tra nhanh

```bash
# Bài 1 – Sim + SLAM
./bringup.sh simulation_mode:=True use_sim_time:=True slam:=True enable_navigation:=True run_rviz:=True

# Lưu map
ros2 run nav2_map_server map_saver_cli -f src/hbot_bringup/maps/hbot_house --ros-args -p use_sim_time:=true

# Bài 2 – Sim + Localization + Nav (map mẫu đi kèm)
./bringup.sh simulation_mode:=True use_sim_time:=True slam:=False enable_navigation:=True run_rviz:=True

# ... hoặc với map tự dựng
./bringup.sh simulation_mode:=True use_sim_time:=True slam:=False enable_navigation:=True \
  map:=$PWD/src/hbot_bringup/maps/hbot_house.yaml run_rviz:=True

# Teleop
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -p stamped:=false -r cmd_vel:=/cmd_vel

# Gửi goal
ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
  "{pose: {header: {frame_id: map}, pose: {position: {x: 0.8, y: 0.0}, orientation: {w: 1.0}}}}"
```

---

## 8. So sánh với robot thật (chuyển bài lên phần cứng)

| | Sim | Robot thật |
|---|---|---|
| Lệnh | `simulation_mode:=True use_sim_time:=True` | `simulation_mode:=False use_sim_time:=False` |
| Mapping | `slam:=True enable_navigation:=True` | giống hệt |
| Localization | `slam:=False enable_navigation:=True` (map mẫu) | `slam:=False ... map:=/abs/đường/dẫn/map.yaml` (không có map mẫu) |
| Nguồn `/odom` | gz DiffDrive (qua bridge) | driver Yahboom + EKF |
| Nguồn `/scan` | gz `gpu_lidar` (qua bridge) | driver YDLidar X3 (`LIDAR_MODEL=ydlidar_x3`) |

Vì cây TF, tham số Nav2 và bộ SLAM **giống nhau**, kỹ năng đặt initial pose,
gửi goal, đọc costmap, tinh chỉnh `nav2_params.yaml` học trên sim áp dụng
trực tiếp lên robot thật.
