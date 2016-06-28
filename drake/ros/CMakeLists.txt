find_program(ROSTEST_EXECUTABLE NAMES rostest)

if(ROSTEST_EXECUTABLE)
  message(STATUS "Found rostest: ${ROSTEST_EXECUTABLE} (found version \"$ENV{ROS_DISTRO}\")")
else()
  message(FATAL_ERROR "Could NOT find rostest")
endif()

add_subdirectory(drake)

# add_library_with_exports(LIB_NAME drakeROS
#     SOURCE_FILES )

drake_install_headers(
  ros_sensor_publisher_joint_state.h
  ros_sensor_publisher_lidar.h
  ros_sensor_publisher_odometry.h
  ros_tf_publisher.h
  ros_vehicle_system.h)