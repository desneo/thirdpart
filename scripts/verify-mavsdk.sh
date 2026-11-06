#!/usr/bin/env bash
# 复制归档到独立目录，用 find_package 编译并运行真实 UDP 消费者。
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
prefix=${1:-"$repo_dir/mavsdk/v4.1.0/x64/ubuntu24.04"}
[[ -d "$prefix/lib/cmake/MAVSDK" ]] || { echo "缺少 MAVSDK 安装目录: $prefix" >&2; exit 1; }
test_dir=$(mktemp -d /tmp/mavsdk-verify.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
cp -a -- "$prefix" "$test_dir/install"
# 禁用用户和系统 package registry，确保解析复制后的归档。
cmake -S "$repo_dir/scripts/tests/mavsdk" -B "$test_dir/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER="${CXX:-g++}" \
    -DMAVSDK_DIR="$test_dir/install/lib/cmake/MAVSDK" \
    -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF
cmake --build "$test_dir/build" --parallel "${BUILD_JOBS:-4}"
# 直接检查动态加载器选中的 MAVSDK，防止绝对路径悄然回退到原始归档。
resolved_lib=$(env -u LD_LIBRARY_PATH -u LD_PRELOAD ldd "$test_dir/build/mavsdk_udp_verification" |
    awk '$1 == "libmavsdk.so.4" && $2 == "=>" { print $3 }')
[[ -n "$resolved_lib" && "$(realpath -- "$resolved_lib")" == "$(realpath -- "$test_dir/install/lib/libmavsdk.so.4")" ]] || {
    echo "运行时未从复制后的安装目录加载 libmavsdk.so.4: $resolved_lib" >&2
    exit 1
}
# 清除外部动态加载设置，验证复制后 CMake target 及运行时路径。
env -u LD_LIBRARY_PATH -u LD_PRELOAD ctest --test-dir "$test_dir/build" --output-on-failure --verbose
printf 'MAVSDK 独立目录 find_package 消费者编译运行通过（6 个 UDP 场景）\n'
