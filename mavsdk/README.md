# MAVSDK

## 基线和安装目录

Ubuntu 24.04 x64 归档使用官方 [MAVSDK v4.1.0](https://github.com/mavlink/MAVSDK/tree/v4.1.0)，固定 commit `52ea50b52d518b7ff5d550f572c0657b9225c475`，递归子模块使用该提交记录的版本。

安装位置为 `mavsdk/v4.1.0/x64/ubuntu24.04`，包含头文件、共享库、CMake/pkg-config 配置和许可证。原 `v3.17.4` 的 Ubuntu 22.04 归档单独保留。

v4.1.0 为 v4 ABI，使用 C++20。消费方须重新编译，并配套使用 v4 的头文件和共享库；不能将其作为 v3 二进制的直接替代品。

## UDP 端口绑定定制

补丁为 [`mavsdk-v4.1.0-udp-port-binding.patch`](../scripts/patches/mavsdk-v4.1.0-udp-port-binding.patch)。项目所称的“UDP 重连修改”通过该补丁调整 UDP 端口绑定，本身不新增自动重连算法。基线的断流检测和恢复行为由测试另行验证。

补丁只修改 `cpp/src/mavsdk/core/mavsdk_impl.cpp` 中创建 UDP 连接时的本地端口参数：

```cpp
udp.mode == CliArg::Udp::Mode::In ? udp.port + 100 : udp.port,
```

| URL | 实际本地绑定 | 远端 |
| --- | --- | --- |
| `udpin://0.0.0.0:14540` | `0.0.0.0:14640` | 从收到的有效消息中发现 |
| `udpout://192.168.1.10:14540` | `0.0.0.0:14540` | `192.168.1.10:14540` |
| `udp://:14540` | `0.0.0.0:14640` | 与 udpin 一致 |
| `udp://192.168.1.10:14540` | `0.0.0.0:14540` | 与 udpout 一致 |

旧式 `udp://` 的模式判定沿用上游；新代码建议使用明确的 `udpin://` 或 `udpout://`。udpout 不再使用随机本地端口，部署时需要为其绑定端口留出空间。

udpin URL 中的端口须不大于 **65435**，加 100 后最高为 65535。补丁不增加范围校验；不要传入会使实际端口溢出的数值。补丁不包含 DYT 接口或其他本地分支修改，也不新增公开 API 或运行时开关。

## 从 GitHub Gist 获取补丁

远端副本保存在 [GitHub Secret Gist](https://gist.github.com/desneo/172d3f20a9a884bd14961a9b60cb9cb9)，固定 revision 为 `9897649bc47f6d8f3290a9090d7a54b6968c6e70`。任何获得链接的人均可读取，不依赖本归档仓库的访问权限。

[固定版本补丁下载](https://gist.github.com/desneo/172d3f20a9a884bd14961a9b60cb9cb9/raw/9897649bc47f6d8f3290a9090d7a54b6968c6e70/mavsdk-v4.1.0-udp-port-binding.patch)与本仓库补丁逐字节一致，SHA-256 为 `08580b6d13f23d1cec943c4423e5214a2444e65cc6709466d0cb12aa90c3002a`。获取时使用固定 revision 并校验内容：

```bash
patch_file="$PWD/mavsdk-v4.1.0-udp-port-binding.patch"
curl -fL 'https://gist.github.com/desneo/172d3f20a9a884bd14961a9b60cb9cb9/raw/9897649bc47f6d8f3290a9090d7a54b6968c6e70/mavsdk-v4.1.0-udp-port-binding.patch' \
  -o "$patch_file"
printf '%s  %s\n' \
  '08580b6d13f23d1cec943c4423e5214a2444e65cc6709466d0cb12aa90c3002a' \
  "$patch_file" | sha256sum --check -
```

对干净的官方 v4.1.0 源码，可用 `git -C "$source_dir" apply --check "$patch_file"` 检查，再用 `git -C "$source_dir" apply "$patch_file"` 应用；基线 commit 必须与本文一致。已应用补丁的源码不要重复应用。

归档构建脚本继续使用仓库内的补丁文件。修改补丁时须同时维护 Gist、固定 revision、校验值及验证结果，不要将可变的 latest/raw 链接用作重建依据。

## 原生构建

需要 Ubuntu 24.04 x86_64、GCC/G++ 13、CMake、Ninja、Git、Python 3、Perl、Make、`taskset`（util-linux）和联网下载依赖的权限。从本仓库根目录执行：

```bash
BUILD_JOBS=4 bash scripts/build-mavsdk.sh
bash scripts/verify-mavsdk.sh
python3 scripts/verify-archives.py
```

默认工作目录为 `/tmp/common-build/mavsdk-v4.1.0`，源码在 `source`，构建目录在 `build`。可通过 `BUILD_ROOT` 指定其他临时工作目录，通过 `BUILD_JOBS` 控制并行数。脚本限制配置过程的 CPU 亲和性，使上游 superbuild 中自行计算 CPU 数量的嵌套构建也遵守并行限制。

构建脚本固定官方 tag 和 commit，检查递归子模块，确认源码为干净基线或仅包含本补丁，再自动应用补丁。版本不符、补丁冲突或存在额外源码修改时立即停止；重复执行会识别已应用状态。

构建入口为上游 `cpp`，配置 Release、共享库、全部官方插件、ardupilotmega dialect、CURL 支持及上游测试，关闭 gRPC server；依赖通过上游 superbuild 构建。版本字符串保留补丁产生的真实 dirty 标记。

依赖下载规则沿用该基线的官方 recipe，其中包含分支引用；安装包的 `share/build-info` 保存当次构建信息和实际依赖 revision，用于核对版本，不承诺不同时间重建的逐字节一致性。

## 手动应用与撤销补丁

以下命令中的 `repo_dir` 为本归档仓库根目录，`source_dir` 为干净的官方 v4.1.0 checkout；命令不对归档中的二进制打补丁。

```bash
git -C "$source_dir" rev-parse HEAD
# 应为 52ea50b52d518b7ff5d550f572c0657b9225c475
git -C "$source_dir" submodule update --init --recursive
git -C "$source_dir" apply --check "$repo_dir/scripts/patches/mavsdk-v4.1.0-udp-port-binding.patch"
git -C "$source_dir" apply "$repo_dir/scripts/patches/mavsdk-v4.1.0-udp-port-binding.patch"

# 已应用状态的检查与撤销：
git -C "$source_dir" apply --reverse --check "$repo_dir/scripts/patches/mavsdk-v4.1.0-udp-port-binding.patch"
git -C "$source_dir" apply --reverse "$repo_dir/scripts/patches/mavsdk-v4.1.0-udp-port-binding.patch"
```

## 验证入口

构建脚本默认运行全部上游 unit tests，包含 URL 解析用例；需要飞控或 SITL 的 system tests 不属于本机验收范围。上游 CURL 用例需要访问测试 HTTP 文件，并确认无效域名 `notexisting.file` 返回 DNS 解析失败。

若网络通过透明 DNS/Fake-IP 将无效域名解析为内部地址，DNS 失败用例会收到不同错误码，设置 `NO_PROXY` 也无法恢复其前提。此时分别在可访问测试 HTTP 文件的环境运行其余用例、在能真实返回 DNS 解析失败的环境运行该用例，两部分都必须通过：

```bash
# 可访问外网的环境：构建、运行其余用例并安装。
GTEST_FILTER=-Curl.DownloadFile_ProgressFeedback_COULDNT_RESOLVE_HOST \
  bash scripts/build-mavsdk.sh

# DNS 能真实返回解析失败的环境：补全上游 DNS 用例验证。
GTEST_FILTER=Curl.DownloadFile_ProgressFeedback_COULDNT_RESOLVE_HOST \
  ctest --test-dir /tmp/common-build/mavsdk-v4.1.0/build/src \
  --output-on-failure --verbose
```

这是测试运行环境的划分，不修改上游源码、断言或 DNS 实现。使用自定义 `BUILD_ROOT` 时，相应调整第二条命令的构建目录。

`verify-mavsdk.sh` 将安装包复制到临时独立位置，通过 `find_package(MAVSDK)` 编译 C++20 消费者并实际运行，验证：

- udpin 的监听端口偏移、udpout 的实际源端口、旧式 URL，以及 `65435 → 65535` 边界。
- 模拟 MAVLink heartbeat 的设备发现、断流后的断开状态及同一设备恢复发送后的重新连接。
- 销毁连接后重新创建并再次接收消息。

测试使用本机 UDP socket，需要运行环境允许本地端口绑定及通信，不需要飞控或 SITL。全仓库归档检查另外验证 x86_64 ELF 架构、动态依赖和相对符号链接。修改基线或补丁后必须重新运行这些验证。

当前归档验证结果：442 项上游单元测试分网络环境全部通过（外网环境 441 项，真实 DNS 失败环境 1 项）；复制安装目录后的 C++20 消费者及 6 个 UDP 场景全部通过，包含同一设备对象断流恢复、连接移除后端口释放和重新创建。库的 SONAME 为 `libmavsdk.so.4`，无 RPATH/RUNPATH，仅依赖标准 C/C++ 运行库。
