#!/usr/bin/env python3
"""检查 Ubuntu 24.04 归档的符号链接、ELF 架构和运行时依赖。"""

import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
ARCHIVES = [
    "behaviortree/4.10.0/x64/ubuntu24.04",
    "fmt/12.2.0/x64/ubuntu24.04",
    "geographiclib/v2.7/x64/ubuntu24.04",
    "mavsdk/v4.1.0/x64/ubuntu24.04",
    "pluma/x64/ubuntu24.04",
    "spdlog/v1.17.0/x64/ubuntu24.04",
    "zenohc/1.10.0/x64/ubuntu24.04",
    "zenohcpp/1.10.0/x64/ubuntu24.04",
    "zlmediakit/4b07053/x64/ubuntu24.04",
]


def main():
    errors = []
    count = 0
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = ":".join(str(ROOT / item / "lib") for item in ARCHIVES)
    for relative in ARCHIVES:
        directory = ROOT / relative
        if not directory.is_dir():
            errors.append(f"缺少归档目录：{relative}")
            continue
        for path in sorted(directory.rglob("*")):
            label = path.relative_to(ROOT)
            if path.is_symlink():
                target = os.readlink(path)
                if os.path.isabs(target) or not path.exists():
                    errors.append(f"绝对路径或失效符号链接：{label} -> {target}")
                continue
            if not path.is_file():
                continue
            with path.open("rb") as stream:
                if stream.read(4) != b"\x7fELF":
                    continue
            count += 1
            header = subprocess.check_output(["readelf", "-h", str(path)], text=True)
            if "Advanced Micro Devices X86-64" not in header:
                errors.append(f"非 x86_64 ELF：{label}")
            result = subprocess.run(["ldd", str(path)], env=env, text=True, capture_output=True)
            if result.returncode or "not found" in result.stdout:
                errors.append(f"运行时依赖检查失败：{label}\n{result.stdout}{result.stderr}")
        print(f"已检查：{relative}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"全部归档通过检查，共 {count} 个 ELF 文件。")


if __name__ == "__main__":
    main()
