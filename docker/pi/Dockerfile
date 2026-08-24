FROM --platform=linux/arm64 ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash-completion \
    git \
    sudo \
    python3-flask \
    python3-flask-socketio \
    python3-psutil \
    python3-eventlet \
    ros-humble-rosidl-default-generators \
    ros-humble-rosidl-default-runtime \
    ros-humble-rosidl-typesupport-c \
    ros-humble-rosidl-typesupport-cpp \
    ros-humble-geographic-msgs \
    ros-humble-diagnostic-updater \
    libgeographic-dev \
    ros-humble-angles \
    libboost-system-dev \
    build-essential \
    ros-humble-cartographer \
    ros-humble-cartographer-ros \
    ros-humble-hls-lfcd-lds-driver \
    cmake \
    && rm -rf /var/lib/apt/lists/*


# Pre-install workspace dependencies using rosdep
WORKDIR /root/hbot_ws
COPY src ./src

# Build + install the YDLidar SDK system-wide, for arm64. It's a bare CMake
# project (no package.xml) that ydlidar_ros2_driver's CMakeLists
# find_package()s and links in statically (libydlidar_sdk.a) - it's not a
# colcon package itself (src/ydlidar_x3/YDLidar-SDK-master/COLCON_IGNORE),
# so neither rosdep below nor build_packages_pi.sh ever build or install it.
# Doing it here, once, at image-build time (rather than in
# build_packages_pi.sh, which reruns on every `docker compose up`) means
# every container built from this image already has it - and because the
# resulting driver binary links it statically, install_pi/ is self-contained
# afterwards: sync_to_pi.sh never needs to ship the SDK to the robot itself.
RUN cd src/ydlidar_x3/YDLidar-SDK-master && \
    rm -rf build && mkdir build && cd build && \
    cmake .. && \
    make -j"$(nproc)" && \
    make install

RUN rm -rf src/hbot_simulation && \
    apt-get update && \
    rosdep update && \
    rosdep install --from-paths src --ignore-src -y --rosdistro humble \
    --skip-keys "rviz2 rviz_common rviz_default_plugins rviz_ogre_vendor rviz_rendering nav2_rviz_plugins" && \
    rm -rf src && \
    rm -rf /var/lib/apt/lists/*
