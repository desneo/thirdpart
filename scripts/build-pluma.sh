#!/usr/bin/env bash
# 在 Ubuntu 24.04 x64 构建归档接口兼容的 Pluma；仅修改临时源码和新归档目录。
set -euo pipefail
source /etc/os-release
if [[ $ID != ubuntu || $VERSION_ID != 24.04 || $(uname -m) != x86_64 ]]; then
    printf '%s\n' '仅支持在 Ubuntu 24.04 x64 本机执行。' >&2
    exit 1
fi
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=${BUILD_ROOT:-/tmp/common-build/zenoh}
src="$work/pluma"
dest="$repo/pluma/x64/ubuntu24.04"
commit=a885b073edd1fd639f9744856092518f94b18f15
mkdir -p "$work" "$dest/include" "$dest/lib" "$dest/examples"
if [[ ! -d "$src/.git" ]]; then
    git clone https://github.com/Yurii-huang/pluma.git "$src"
    git -C "$src" checkout --detach "$commit"
fi
[[ $(git -C "$src" rev-parse HEAD) == "$commit" ]]
# 上游使用 CRLF；补丁统一按 LF 应用。保留许可证中的修改标记要求。
python3 - "$src/src/Pluma/PluginManager.cpp" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text())
PY
if ! grep -q 'getSymbol("connectToPlumaHost")' "$src/src/Pluma/PluginManager.cpp"; then
    patch -d "$src" -p1 < "$repo/scripts/patches/pluma-connector.patch"
fi
# 公开头文件沿用已归档的定制接口；源实现使用固定上游提交和 connector 补丁。
cp -a "$repo/pluma/x64/ubuntu22.04/include/Pluma" "$dest/include/"
cp -a "$repo/pluma/x64/ubuntu22.04/examples/." "$dest/examples/"
python3 - "$dest" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
header = (root / 'include/Pluma/Config.hpp').read_text().splitlines()
license_text = '\n'.join(line.removeprefix('//').lstrip() for line in header[2:21])
(root / 'LICENSE').write_text(license_text + '\n')
PY
# 示例可在任意构建目录使用；插件库位置允许显式传入。
python3 - "$dest/examples" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for p in root.glob('*/CMakeLists.txt'):
    text = p.read_text().replace('set(PLUMA_PATH ../../)', 'set(PLUMA_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../..)')
    if p.parent.name == 'testmain':
        text = text.replace('# 打包so到lib文件夹下', 'set(TESTALGO_LIBRARY "${CMAKE_CURRENT_SOURCE_DIR}/../testalgo/build/libtestalgo.so" CACHE FILEPATH "测试插件库")\n\n# 打包so到lib文件夹下')
        text = text.replace('${CMAKE_CURRENT_SOURCE_DIR}/../testalgo/build/libtestalgo.so \n', '${TESTALGO_LIBRARY}\n')
    p.write_text(text)
PY
c++ -std=c++17 -O3 -DNDEBUG -fPIC -shared \
    -I"$dest/include" -I"$src/src" \
    "$src/src/Pluma/DLibrary.cpp" "$src/src/Pluma/Dir.cpp" \
    "$src/src/Pluma/Host.cpp" "$src/src/Pluma/PluginManager.cpp" "$src/src/Pluma/Provider.cpp" \
    -Wl,-soname,libpluma.so -ldl -o "$dest/lib/libpluma.so"
cmake -S "$dest/examples/testalgo" -B "$work/pluma-testalgo"
cmake --build "$work/pluma-testalgo" -j"${BUILD_JOBS:-4}"
cmake -S "$dest/examples/testmain" -B "$work/pluma-testmain" \
    -DTESTALGO_LIBRARY="$work/pluma-testalgo/libtestalgo.so"
cmake --build "$work/pluma-testmain" -j"${BUILD_JOBS:-4}"
(cd "$work/pluma-testmain" && ./testmain) | tee "$work/pluma-test.log"
grep -qx keyboard "$work/pluma-test.log"
printf '%s\n' 'Pluma 构建完成。'
