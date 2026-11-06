#!/usr/bin/env bash
# 在 Ubuntu 24.04 x86_64 上编译四个常规 CMake 三方库并运行上游测试。
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=${BUILD_ROOT:-/tmp/common-build/standard}
jobs=${BUILD_JOBS:-4}
mkdir -p "$work"
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 && "$(uname -m)" == x86_64 ]] || {
  echo '需要 Ubuntu 24.04 x86_64 原生构建环境' >&2; exit 1;
}

fetch() {
  local name=$1 url=$2 tag=$3 commit=$4
  if [[ ! -d "$work/$name/.git" ]]; then
    git clone --depth 1 --branch "$tag" "$url" "$work/$name"
  fi
  [[ "$(git -C "$work/$name" rev-parse HEAD)" == "$commit" ]] || {
    echo "源码版本不匹配：$name" >&2; exit 1;
  }
}
fetch fmt https://github.com/fmtlib/fmt.git 12.2.0 1be298e1bd68957e4cd352e1f676f00e07dcfb57
fetch spdlog https://github.com/gabime/spdlog.git v1.17.0 79524ddd08a4ec981b7fea76afd08ee05f83755d
fetch behaviortree https://github.com/BehaviorTree/BehaviorTree.CPP.git 4.10.0 879522c75cce5e67f3dd7b5591bcb96eb3557a42
fetch geographiclib https://github.com/geographiclib/geographiclib.git v2.7 15cddd7eed9f7f61ead6dba2229d45b271dbdeda
fetch googletest https://github.com/google/googletest.git v1.15.2 b514bdc898e2951020cbdca1304b75f5950d1f59
fetch Catch2 https://github.com/catchorg/Catch2.git v3.5.0 53d0d913a422d356b23dd927547febdf69ee9081

build() {
  local name=$1 prefix=$2
  shift 2
  echo "正在编译和验证：$name"
  cmake -S "$work/$name" -B "$work/build-$name" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_INSTALL_LIBDIR=lib "$@"
  cmake --build "$work/build-$name" --parallel "$jobs"
  if [[ "$name" == geographiclib ]]; then
    cmake --build "$work/build-$name" --target testprograms --parallel "$jobs"
  fi
  # BehaviorTree 日志测试共用同一个临时目录，需要串行执行。
  local test_jobs=$jobs
  [[ "$name" != behaviortree ]] || test_jobs=1
  ctest --test-dir "$work/build-$name" --output-on-failure --parallel "$test_jobs"
  cmake --install "$work/build-$name"
}

fmt_prefix="$repo/fmt/12.2.0/x64/ubuntu24.04"
spdlog_prefix="$repo/spdlog/v1.17.0/x64/ubuntu24.04"
bt_prefix="$repo/behaviortree/4.10.0/x64/ubuntu24.04"
geo_prefix="$repo/geographiclib/v2.7/x64/ubuntu24.04"
build fmt "$fmt_prefix" -DBUILD_SHARED_LIBS=ON -DFMT_TEST=ON -DFMT_DOC=OFF
build spdlog "$spdlog_prefix" -DSPDLOG_BUILD_SHARED=ON -DSPDLOG_FMT_EXTERNAL=ON \
  -DSPDLOG_BUILD_TESTS=ON -DSPDLOG_BUILD_EXAMPLE=OFF -Dfmt_DIR="$fmt_prefix/lib/cmake/fmt" \
  -DFETCHCONTENT_SOURCE_DIR_CATCH2="$work/Catch2" \
  '-DCMAKE_INSTALL_RPATH=$ORIGIN/../../../../../fmt/12.2.0/x64/ubuntu24.04/lib'
build googletest "$work/test-deps" -DBUILD_GMOCK=OFF
# 现有包启用 Groot/ZeroMQ，关闭 SQLite 日志；保留相同功能开关。
# 上游日志测试未检查 SQLite 开关；仅停用依赖此未编译功能的 12 项测试。
# 修改仅限临时测试源码，发布库源码保持上游原样。
python3 - "$work/behaviortree" <<'PY'
import pathlib
import subprocess
import sys
source = pathlib.Path(sys.argv[1])
name = "tests/gtest_loggers.cpp"
text = subprocess.check_output(["git", "-C", str(source), "show", "HEAD:" + name], text=True)
marker = "// ============ SqliteLogger tests ============"
assert text.count(marker) == 1
text = text.replace(marker, "#if 0 // SQLite 日志功能关闭\n" + marker) + "\n#endif\n"
(source / name).write_text(text)
PY
build behaviortree "$bt_prefix" -DBTCPP_SHARED_LIBS=ON -DBTCPP_GROOT_INTERFACE=ON \
  -DBTCPP_SQLITE_LOGGING=OFF -DBTCPP_EXAMPLES=OFF -DBTCPP_BUILD_TOOLS=OFF \
  -DBUILD_TESTING=ON -DGTest_DIR="$work/test-deps/lib/cmake/GTest"
build geographiclib "$geo_prefix" -DBUILD_SHARED_LIBS=ON

# pkg-config 使用相对 prefix，以支持整个仓库移动到任意目录。
python3 - "$fmt_prefix" "$spdlog_prefix" "$geo_prefix" <<'PY'
import pathlib
import re
import sys
for prefix in sys.argv[1:]:
    for path in pathlib.Path(prefix, "lib/pkgconfig").glob("*.pc"):
        content = path.read_text()
        content = re.sub(r"^prefix=.*$", "prefix=${pcfiledir}/../..", content, flags=re.M)
        content = re.sub(r"^exec_prefix=.*$", "exec_prefix=${prefix}", content, flags=re.M)
        path.write_text(content)
PY
for item in "fmt:$fmt_prefix:LICENSE" "spdlog:$spdlog_prefix:LICENSE" \
            "behaviortree:$bt_prefix:LICENSE" "geographiclib:$geo_prefix:LICENSE.txt"; do
  IFS=: read -r name prefix license <<< "$item"
  mkdir -p "$prefix/share/licenses/$name"
  cp "$work/$name/$license" "$prefix/share/licenses/$name/"
done
for dependency in cppzmq minitrace tinyxml2 minicoro; do
  mkdir -p "$bt_prefix/share/licenses/behaviortree/$dependency"
  cp "$work/behaviortree/3rdparty/$dependency"/LICENSE* \
    "$bt_prefix/share/licenses/behaviortree/$dependency/"
done
echo '四个三方库编译、上游测试和安装完成'
