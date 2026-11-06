#!/usr/bin/env bash
# 构建官方 MAVSDK v4.1.0，仅应用 UDP 本地绑定端口补丁。
set -euo pipefail
source /etc/os-release
if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != 24.04 || $(uname -m) != x86_64 ]]; then
    printf '错误：此脚本仅支持 Ubuntu 24.04 x86_64 本机构建。\n' >&2
    exit 1
fi
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=${BUILD_ROOT:-/tmp/common-build/mavsdk-v4.1.0}
source_dir="$work_dir/source"
build_dir="$work_dir/build"
prefix="$repo_root/mavsdk/v4.1.0/x64/ubuntu24.04"
patch_file="$repo_root/scripts/patches/mavsdk-v4.1.0-udp-port-binding.patch"
revision=52ea50b52d518b7ff5d550f572c0657b9225c475
mkdir -p "$work_dir"
if [[ ! -d "$source_dir/.git" ]]; then
    git clone --branch v4.1.0 --depth 1 https://github.com/mavlink/MAVSDK.git "$source_dir"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || { printf '错误：源码 HEAD 与固定版本不同。\n' >&2; exit 1; }
[[ $(git -C "$source_dir" rev-parse 'v4.1.0^{commit}') == "$revision" ]] || { printf '错误：v4.1.0 tag 与固定版本不同。\n' >&2; exit 1; }
# 工作区仅允许干净基线或已应用的精确补丁，不覆盖用户修改。
check_source() {
    python3 - "$source_dir" "$patch_file" <<'PY'
import pathlib, subprocess, sys
source, patch = sys.argv[1:]
def git(*args):
    return subprocess.check_output(['git', '-C', source, *args])
if git('diff', '--cached', '--name-only'):
    sys.exit('错误：源码存在暂存修改。')
if git('ls-files', '--others'):
    sys.exit('错误：源码存在未跟踪文件。')
actual = git('diff', '--binary', '--no-ext-diff')
if actual and actual != pathlib.Path(patch).read_bytes():
    sys.exit('错误：源码修改与允许的 UDP 端口补丁不一致。')
PY
    git -C "$source_dir" submodule foreach --recursive 'test -z "$(git status --porcelain --untracked-files=all)" && test -z "$(git ls-files --others)"' >/dev/null
    if git -C "$source_dir" submodule status --recursive | grep -Eq '^[+U]'; then
        printf '错误：子模块版本与固定版本不一致。\n' >&2
        exit 1
    fi
}
check_source
git -C "$source_dir" submodule update --init --recursive
check_source
if git -C "$source_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
    printf '已应用指定 UDP 端口补丁。\n'
else
    git -C "$source_dir" apply --check "$patch_file"
    git -C "$source_dir" apply "$patch_file"
fi
check_source
export CCACHE_DIR="$work_dir/ccache"
export CMAKE_BUILD_PARALLEL_LEVEL=${BUILD_JOBS:-4}
if [[ ! $CMAKE_BUILD_PARALLEL_LEVEL =~ ^[1-9][0-9]*$ ]]; then
    printf '错误：BUILD_JOBS 必须是正整数。\n' >&2
    exit 1
fi
# 上游 OpenSSL 使用 ProcessorCount 自行设置 make -j；限制亲和性以约束所有嵌套构建。
cpu_list=$(python3 - <<'PY'
import os
print(','.join(map(str, sorted(os.sched_getaffinity(0))[:int(os.environ['CMAKE_BUILD_PARALLEL_LEVEL'])])))
PY
)
taskset -c "$cpu_list" cmake -S "$source_dir/cpp" -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLED_PLUGINS= \
    -DBUILD_SHARED_LIBS=ON -DBUILD_MAVSDK_SERVER=OFF -DBUILD_TESTING=ON \
    -DBUILD_WITHOUT_CURL=OFF -DSUPERBUILD=ON -DMAVLINK_DIALECT=ardupilotmega
python3 - "$build_dir/CMakeCache.txt" "$prefix" <<'PY'
from pathlib import Path
import sys
cache = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line and ':' in line.split('=', 1)[0]:
        key, value = line.split('=', 1)
        cache[key.split(':', 1)[0]] = value
expected = {'CMAKE_BUILD_TYPE': 'Release', 'CMAKE_INSTALL_PREFIX': sys.argv[2],
            'CMAKE_INSTALL_LIBDIR': 'lib', 'ENABLED_PLUGINS': '', 'BUILD_SHARED_LIBS': 'ON',
            'BUILD_MAVSDK_SERVER': 'OFF', 'BUILD_TESTING': 'ON', 'BUILD_WITHOUT_CURL': 'OFF',
            'SUPERBUILD': 'ON', 'MAVLINK_DIALECT': 'ardupilotmega'}
for key, value in expected.items():
    if cache.get(key) != value:
        sys.exit(f'错误：CMake 缓存 {key} 与请求值不一致，请重新配置构建。')
PY
cmake --build "$build_dir" --parallel "$CMAKE_BUILD_PARALLEL_LEVEL" --target mavsdk unit_tests_runner
ctest --test-dir "$build_dir/src" --output-on-failure -R '^unit_tests$' --no-tests=error
check_source
cmake --install "$build_dir"
# 安装树使用相对 prefix；shared 构建已将私有依赖静态链接，无需消费者安装这些开发包。
python3 - "$prefix" "$work_dir" "$source_dir" "$build_dir" <<'PY'
from pathlib import Path
import sys
prefix = Path(sys.argv[1])
p = prefix / 'lib/pkgconfig/mavsdk.pc'
text = p.read_text().splitlines()
replacements = {'prefix': '${pcfiledir}/../..', 'exec_prefix': '${prefix}',
                'libdir': '${prefix}/lib', 'includedir': '${prefix}/include'}
text = [f'{line.split("=", 1)[0]}={replacements[line.split("=", 1)[0]]}'
        if '=' in line and line.split('=', 1)[0] in replacements else line
        for line in text]
text = ['Requires.private:' if line.startswith('Requires.private:') else
        line.replace('written in C++17', 'written in C++20') for line in text]
p.write_text('\n'.join(text) + '\n')
for p in (prefix / 'lib/cmake').rglob('*.cmake'):
    if any(str(Path(path).resolve()) in p.read_text() for path in sys.argv[1:]):
        sys.exit(f'错误：安装 CMake 配置包含构建绝对路径：{p}')
PY
mkdir -p "$prefix/share/licenses"
cp "$source_dir/LICENSE.md" "$prefix/share/licenses/MAVSDK-LICENSE.md"
python3 - "$build_dir/third_party" "$prefix/share/licenses" <<'PY'
from pathlib import Path
import shutil, sys
deps, licenses = map(Path, sys.argv[1:])
sources = {
    'fmt': 'fmt/fmt/src/fmt',
    'asio': 'asio/asio-prefix/src/asio/asio',
    'mavlink': 'mavlink/mavlink/src/mavlink',
    'libevents': 'libevents/libevents-prefix/src/libevents',
    'picosha2': 'picosha2/picosha2/src/picosha2',
    'tinyxml2': 'tinyxml2/tinyxml2/src/tinyxml2',
    'libmavlike': 'libmavlike/libmavlike/src/libmavlike',
    'nlohmann_json': 'nlohmann_json/nlohmann_json/src/nlohmann_json',
    'liblzma': 'liblzma/liblzma-prefix/src/liblzma',
    'openssl': 'openssl/openssl/src/openssl',
    'zlib-ng': 'zlib-ng/zlib-ng/src/zlib-ng',
    'curl': 'curl/curl/src/curl',
}
for name, relative in sources.items():
    files = [p for p in (deps / relative).iterdir()
             if p.is_file() and p.name.upper().startswith(('LICENSE', 'COPYING', 'COPYRIGHT', 'NOTICE'))]
    if not files:
        sys.exit(f'错误：未找到依赖许可证：{name}')
    destination = licenses / name
    destination.mkdir(exist_ok=True)
    for p in files:
        shutil.copy2(p, destination / p.name)
PY
python3 - "$source_dir" "$build_dir" "$prefix" "$patch_file" <<'PY'
from pathlib import Path
import configparser, hashlib, subprocess, sys
source, build, prefix, patch = map(Path, sys.argv[1:])
info_dir = prefix / 'share/build-info'
info_dir.mkdir(parents=True, exist_ok=True)
revisions = []
for dep in sorted((build / 'third_party').iterdir()):
    for gitdir in dep.glob('*/src/*/.git'):
        revision = subprocess.check_output(['git', '-C', str(gitdir.parent), 'rev-parse', 'HEAD'], text=True).strip()
        revisions.append(f'{dep.name} {revision}')
(info_dir / 'dependency-revisions.txt').write_text('\n'.join(revisions) + '\n')
info = configparser.ConfigParser()
info['build'] = {'source_revision': '52ea50b52d518b7ff5d550f572c0657b9225c475',
                 'version': subprocess.check_output(['git', '-C', str(source), 'describe', '--tags', '--dirty'], text=True).strip(),
                 'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
                 'system': 'Ubuntu 24.04 x86_64', 'configuration': 'Release',
                 'compiler': subprocess.check_output(['g++', '--version'], text=True).splitlines()[0],
                 'cmake': subprocess.check_output(['cmake', '--version'], text=True).splitlines()[0],
                 'ninja': subprocess.check_output(['ninja', '--version'], text=True).strip()}
with (info_dir / 'build.ini').open('w') as f:
    f.write('# 当前产物的源码、补丁与工具链信息。\n')
    info.write(f)
PY
printf 'MAVSDK v4.1.0 编译与上游单元测试完成：%s\n' "$prefix"
