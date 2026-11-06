cmake_minimum_required(VERSION 3.12)

project(testmain)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--allow-shlib-undefined")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fpermissive -O2")
set(CMAKE_BUILD_TYPE "Release")

# 依赖的pluma文件
set(PLUMA_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../..)
include_directories(${PLUMA_PATH}/include)
link_directories(${PLUMA_PATH}/lib/)

# 引用的插件头文件路径
set(TEST_PLUGIN_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../testalgo)
include_directories(${TEST_PLUGIN_PATH}/include)

# 依赖的当前项目路径
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} pluma dl)



set(TESTALGO_LIBRARY "${CMAKE_CURRENT_SOURCE_DIR}/../testalgo/build/libtestalgo.so" CACHE FILEPATH "测试插件库")

# 打包so到lib文件夹下
add_custom_target(CopyLibs ALL

    # 创建插件目录
    COMMAND ${CMAKE_COMMAND} -E make_directory
    ${CMAKE_BINARY_DIR}/plugins

    # 复制插件so
    COMMAND ${CMAKE_COMMAND} -E copy
    ${TESTALGO_LIBRARY}
    ${CMAKE_BINARY_DIR}/plugins/
)
add_dependencies(CopyLibs ${PROJECT_NAME})
