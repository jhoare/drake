# Drake-ROS Car Simulation Setup Procedure

_Note:_ These instructions are working notes for running the Drake + ROS
integration for simulating a vehicle. It should be considered "beta" and not a
replacement for the [official Drake instructions](http://drake.mit.edu/installation.html).

## Install Prerequisites

Install [Ubuntu 14.04 64-bit LTS](http://releases.ubuntu.com/14.04/) and [ROS Indigo](http://wiki.ros.org/indigo).

Install Drake's prerequisites by following the instructions here: http://drake.mit.edu/ubuntu.html.

## Install CMake 3.5.2

```bash
$ mkdir -p ~/tools
$ cd ~/tools
$ wget https://cmake.org/files/v3.5/cmake-3.5.2-Linux-x86_64.tar.gz
$ tar zxvf cmake-3.5.2-Linux-x86_64.tar.gz
$ rm cmake-3.5.2-Linux-x86_64.tar.gz
$ cd cmake-3.5.2-Linux-x86_64/bin
$ printf "\nexport PATH=\$HOME/tools/cmake-3.5.2-Linux-x86_64/bin:\$PATH" >> ~/.bashrc
```

## Install Ninja

```bash
$ mkdir -p ~/tools/ninja
$ cd ~/tools/ninja
$ wget https://github.com/ninja-build/ninja/releases/download/v1.7.1/ninja-linux.zip
$ unzip ninja-linux.zip
$ rm ninja-linux.zip
$ printf "\nexport PATH=\$HOME/tools/ninja:\$PATH" >> ~/.bashrc
```

## Check Tool Versions

Before doing this, you may want to close and re-open your terminals to ensure the previous settings are applied.

```
$ ninja --version
1.7.1
$ ccmake --version
ccmake version 3.5.2
```

## Install Drake

```bash
$ mkdir -p ~/dev
$ cd ~/dev

$ git clone git@github.com:liangfok/drake.git drake-distro
# or:
$ git clone https://github.com/liangfok/drake.git drake-distro

$ cd drake-distro
$ git checkout feature/golfcart_adapter
```

## Compile and Setup the Drake ROS Workspace

```bash
$ cd ~/dev/drake-distro/drake/examples/Cars/drake_catkin_workspace
$ source /opt/ros/indigo/setup.bash
$ catkin_make
$ source devel/setup.bash
$ printf "\nsource \$HOME/dev/drake-distro/drake/examples/Cars/drake_catkin_workspace/devel/setup.bash" >> ~/.bashrc

# Adds the "ackerman_drive_teleop" package to the ROS workspace.
$ cd ~/dev/drake-distro/drake/examples/Cars/drake_catkin_workspace/src

$ git clone git@github.com:liangfok/ackermann-drive-teleop.git ackermann_drive_teleop
# or
$ git clone https://github.com/liangfok/ackermann-drive-teleop.git ackermann_drive_teleop

$ cd ackermann_drive_teleop
$ git checkout feature/ackermann_drive_stamped
```

# Compile Drake

```bash
$ cd ~/dev
$ mkdir drake-build
$ cd drake-build
$ env CXX=g++-4.9 CC=gcc-4.9 cmake ../drake-distro -G Ninja -DCMAKE_BUILD_TYPE:STRING=Release -DDISABLE_MATLAB=ON
$ ninja -j1
````

Note that the `-j1` in the last command above specifies a single-threaded build. If your computer has enough memory and processor capability, you can use more than one thread. For example, use `-j8` to use eight threads.

# Run the Simulation

```bash
# Starts RViz.
$ roslaunch drake_cars_examples rviz_prius.launch

# Starts Drake.
$ cd ~/dev/drake-build/drake
$ ./bin/car_sim_lcm_and_ros ../../drake-distro/drake/examples/Cars/models/prius/prius_with_lidar.sdf ../../drake-distro/drake/examples/Cars/models/stata_garage_p1.sdf

# Starts the steering command driver, which provides a GUI for issuing driving commands to the simulated vehicle.
$ rosrun ackermann_drive_teleop ackermann_drive_keyop.py 1.0 0.7
```