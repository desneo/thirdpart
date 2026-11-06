#!/usr/bin/env bash
# 在 Ubuntu 24.04 x64 编译固定版本，保留现有归档的 C API、服务端、SRT 和 OpenSSL 功能。
set -euo pipefail
source /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != 24.04 || $(uname -m) != x86_64 ]]; then
    printf '错误：此脚本仅支持 Ubuntu 24.04 x86_64 本机构建。\n' >&2
    exit 1
fi
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=${BUILD_ROOT:-/tmp/common-build/complex}
source_dir="$work_dir/ZLMediaKit"
build_dir="$work_dir/zlmediakit-build"
prefix="$repo_root/zlmediakit/4b07053/x64/ubuntu24.04"
revision=4b07053aa5f6d35505e8c548c2a08a978143fcf1
mkdir -p "$work_dir"
export CCACHE_DIR="$work_dir/ccache"
if [[ ! -d "$source_dir/.git" ]]; then
    git clone https://github.com/ZLMediaKit/ZLMediaKit.git "$source_dir"
fi
git -C "$source_dir" checkout --detach "$revision"
git -C "$source_dir" submodule update --init --recursive
# 原归档未包含 WebRTC、FFmpeg 编解码、x264 或 FAAC；显式固定选项防止本机依赖改变功能。
cmake -S "$source_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" -DENABLE_API=ON -DENABLE_SERVER=ON \
    -DENABLE_SRT=ON -DENABLE_OPENSSL=ON -DENABLE_WEBRTC=OFF -DENABLE_SCTP=OFF \
    -DENABLE_FFMPEG=OFF -DENABLE_X264=OFF -DENABLE_FAAC=OFF -DENABLE_MYSQL=OFF \
    -DENABLE_TESTS=OFF -DENABLE_OBJCOPY=OFF -DCMAKE_DISABLE_FIND_PACKAGE_JEMALLOC=ON
cmake --build "$build_dir" --parallel "${BUILD_JOBS:-4}" --target mk_api MediaServer
mkdir -p "$prefix/include" "$prefix/lib" "$prefix/bin"
cp "$source_dir"/api/include/*.h "$build_dir/api/mk_export.h" "$prefix/include/"
cp "$source_dir/release/linux/Release/libmk_api.so" "$prefix/lib/"
cp "$source_dir/release/linux/Release/MediaServer" "$prefix/bin/"
strip --strip-unneeded "$prefix/lib/libmk_api.so" "$prefix/bin/MediaServer"
mkdir -p "$prefix/share/licenses"
cp "$source_dir/LICENSE" "$prefix/share/licenses/ZLMediaKit-LICENSE"
for dependency in ZLToolKit jsoncpp media-server; do
    cp "$source_dir/3rdpart/$dependency/LICENSE" "$prefix/share/licenses/$dependency-LICENSE"
done
printf 'ZLMediaKit 编译完成：%s\n' "$prefix"
