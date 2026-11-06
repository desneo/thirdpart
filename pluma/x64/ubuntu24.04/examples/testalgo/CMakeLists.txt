cmake_minimum_required(VERSION 3.12)

project(testalgo)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--allow-shlib-undefined")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fpermissive -O2")
set(CMAKE_BUILD_TYPE "Release")

# 依赖的pluma文件
set(PLUMA_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../..)
include_directories(${PLUMA_PATH}/include)
link_directories(${PLUMA_PATH}/lib)

# 依赖的当前项目路径
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# 源文件
set(SRC
    source/connector.cpp
    source/device.cpp
    source/keyboard.cpp
)

add_library(${PROJECT_NAME} SHARED ${SRC})
target_link_libraries(${PROJECT_NAME} pluma dl)
