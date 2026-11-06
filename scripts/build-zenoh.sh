#!/usr/bin/env bash
# 在 Ubuntu 24.04 x64 构建 Zenoh 1.10.0，保留原归档的 transport/auth/shared-memory/unstable 特性。
# 需要 Rust 1.97.1；可通过 PATH、RUSTUP_HOME、CARGO_HOME 指定临时隔离工具链。
set -euo pipefail
source /etc/os-release
if [[ $ID != ubuntu || $VERSION_ID != 24.04 || $(uname -m) != x86_64 ]]; then
    printf '%s\n' '仅支持在 Ubuntu 24.04 x64 本机执行。' >&2
    exit 1
fi
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=${BUILD_ROOT:-/tmp/common-build/zenoh}
jobs=${BUILD_JOBS:-4}
export CARGO_BUILD_JOBS="$jobs"
mkdir -p "$work"
for component in c cpp; do
    if [[ $component == c ]]; then
        commit=7d586a9c19c0623144e06bd795e8c2b85dd722d4
    else
        commit=738d848cc66ba75038ea9ce0037ddc74dde734b0
    fi
    if [[ ! -d "$work/zenoh-$component/.git" ]]; then
        git clone --depth 1 --branch 1.10.0 "https://github.com/eclipse-zenoh/zenoh-$component.git" "$work/zenoh-$component"
    fi
    [[ $(git -C "$work/zenoh-$component" rev-parse HEAD) == "$commit" ]]
done
cmake -S "$work/zenoh-c" -B "$work/c-build" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX="$repo/zenohc/1.10.0/x64/ubuntu24.04" \
    -DZENOHC_BUILD_WITH_SHARED_MEMORY=ON -DZENOHC_BUILD_WITH_UNSTABLE_API=ON \
    '-DZENOHC_CARGO_FLAGS=--locked;--no-default-features;--features=auth_pubkey,auth_usrpwd,transport_multilink,transport_quic,transport_tcp,transport_tls,transport_udp,transport_unixsock-stream,transport_ws'
cmake --build "$work/c-build" -j"$jobs"
cmake --install "$work/c-build"
cmake --build "$work/c-build" --target z_api_config_test z_api_encoding_test z_api_keyexpr_test z_api_payload_test z_build_shared -j"$jobs"
ctest --test-dir "$work/c-build" -R '(unit_z_api_(config|encoding|keyexpr|payload)_test|build_z_build_shared)$' --output-on-failure --timeout 30
cmake -S "$work/zenoh-cpp" -B "$work/cpp-build" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_PREFIX_PATH="$repo/zenohc/1.10.0/x64/ubuntu24.04" \
    -DCMAKE_INSTALL_PREFIX="$repo/zenohcpp/1.10.0/x64/ubuntu24.04" \
    -DZENOHCXX_ENABLE_TESTS=ON -DZENOHCXX_ENABLE_EXAMPLES=ON -DZENOHCXX_EXAMPLES_PROTOBUF=OFF
cmake --build "$work/cpp-build" -j"$jobs"
cmake --install "$work/cpp-build"
cmake --build "$work/cpp-build" --target bytes_zenohc closures_zenohc details_zenohc serialization_zenohc config_zenohc warnings_zenohc -j"$jobs"
ctest --test-dir "$work/cpp-build" -R '^test_(bytes|closures|details|serialization|config|warnings)_zenohc$' --output-on-failure --timeout 30
cp "$work/zenoh-c/LICENSE" "$repo/zenohc/1.10.0/x64/ubuntu24.04/LICENSE"
cp "$work/zenoh-cpp/LICENSE" "$repo/zenohcpp/1.10.0/x64/ubuntu24.04/LICENSE"
cp "$work/zenoh-c/NOTICE.md" "$repo/zenohc/1.10.0/x64/ubuntu24.04/NOTICE.md"
cp "$work/zenoh-cpp/NOTICE.md" "$repo/zenohcpp/1.10.0/x64/ubuntu24.04/NOTICE.md"
# pkg-config 使用相对前缀，使归档可在任意检出路径使用。
for pkg in zenohc zenohcpp; do
    sed -i 's|^prefix=.*|prefix=${pcfiledir}/../..|' "$repo/$pkg/1.10.0/x64/ubuntu24.04/lib/pkgconfig/"*.pc
done
printf '%s\n' 'Zenoh C/C++ 构建完成。'
