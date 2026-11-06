# Ubuntu 24.04 x64 构建

构建平台为 Ubuntu 24.04.5 LTS x86_64，GCC/G++ 13.3.0、CMake 3.28.3、Ninja 1.11.1。所有二进制均在本机从源码编译，使用 Release 配置。源码及中间文件默认保存在 `/tmp/common-build`，仓库保存安装产物、构建脚本和必要补丁。

## 构建入口

在仓库根目录运行下列脚本，`BUILD_JOBS` 可设置并行数，默认 4。源码下载需要访问 GitHub，Zenoh 另需访问 Rust 工具链及 crates 源。各脚本固定源码 commit；Zenoh 使用上游 `Cargo.lock` 和 `--locked`。

基础构建依赖为 `build-essential cmake ninja-build git python3 pkg-config patch`，BehaviorTree 需要 `libzmq3-dev`，ZLMediaKit 需要 `libssl-dev`。fmt/spdlog/BehaviorTree 的测试依赖由脚本下载至临时目录。

```bash
bash scripts/build-standard.sh
bash scripts/build-pluma.sh
bash scripts/build-zlmediakit.sh
bash scripts/build-zenoh.sh
bash scripts/build-mavsdk.sh
bash scripts/verify-mavsdk.sh
bash scripts/verify-headers.sh
python3 scripts/verify-archives.py
```

`build-standard.sh` 构建 fmt、spdlog、BehaviorTree.CPP 和 GeographicLib，并运行相应上游测试。BehaviorTree 的 SQLite 功能关闭；脚本排除依赖该功能的 12 项测试，保留其余测试。Groot 测试需要允许本机监听端口，并串行执行。

Zenoh 构建使用 Rust 1.97.1。通过 `PATH`、`CARGO_HOME`、`RUSTUP_HOME` 指向工具链即可运行脚本；临时工具链目录为 `/tmp/common-build/zenoh/cargo` 和 `/tmp/common-build/zenoh/rustup`，未修改用户的 Rust 配置。

Zenoh 的 keyexpr 测试需要允许创建本机网络 session；运行这些测试时，环境须允许本机 socket 通信。

MAVSDK 使用官方 v4.1.0，并应用独立的 UDP 端口绑定补丁。源码基线、实际端口规则、手动应用/撤销命令及 v4 ABI 兼容要求见 [MAVSDK 专用说明](../mavsdk/README.md)。

## 产物功能与使用

| 库 | 构建配置及说明 |
| --- | --- |
| fmt | 共享库，提供 CMake 和 pkg-config 配置 |
| spdlog | 共享库，使用归档的外部 fmt 12.2.0；移动时保持两库的相对目录结构 |
| BehaviorTree.CPP | 共享库，启用 ZeroMQ/Groot，关闭 SQLite 日志 |
| GeographicLib | 共享库及命令行工具；地理数据集需按实际用途单独安装 |
| Pluma | 固定提交 `a885b073edd1fd639f9744856092518f94b18f15`，沿用归档头文件；`scripts/patches/pluma-connector.patch` 将插件入口设为 `connectToPlumaHost` |
| Zenoh C | 共享库及静态库，开启 shared-memory、unstable API，以及原有 transport/auth 特性 |
| Zenoh C++ | 头文件及 CMake/pkg-config 配置，使用同版本 Zenoh C |
| ZLMediaKit | `libmk_api.so` 和 `MediaServer`；启用 OpenSSL、SRT、HLS、MP4、RTPPROXY；关闭 WebRTC、SCTP、FFmpeg 编解码、x264、FAAC、MySQL |
| MAVSDK | v4.1.0 共享库、全部官方插件、CURL、ardupilotmega；关闭 gRPC server，使用 UDP 端口绑定补丁，消费方使用 C++20 |

Eigen 5.0.1、eventpp 0.1.3、magic_enum 0.9.8、nlohmann_json 3.12.0 为纯头文件库，使用仓库中的通用目录。`verify-headers.sh` 使用 C++17 编译并运行覆盖四个库的最小使用示例。

可将各包根目录加入 `CMAKE_PREFIX_PATH`，或将 `lib/pkgconfig` 加入 `PKG_CONFIG_PATH`。运行时依赖 Ubuntu 24.04 的标准 C/C++ 运行库，BehaviorTree 还依赖 ZeroMQ，ZLMediaKit 依赖 OpenSSL 3。

`verify-archives.py` 检查所有预期归档目录、相对符号链接、ELF 的 x86_64 架构以及动态依赖解析；它会使用归档各库的 `lib` 目录作为 `LD_LIBRARY_PATH`。

## 验证范围

| 库 | 已通过的验证 |
| --- | --- |
| fmt | 21 项上游 CTest |
| spdlog | 180 个测试用例、589 条断言 |
| BehaviorTree.CPP | 499 项上游 CTest |
| GeographicLib | 199 项上游 CTest、GeodSolve 命令行运行 |
| 上述四库 | 复制至独立目录后通过 CMake 联合编译、链接及实际调用 |
| Pluma | 编译并运行归档 testalgo/testmain 示例，通过定制入口加载插件 |
| Zenoh C | config、encoding、keyexpr、payload、shared-build 共 5 项上游测试 |
| Zenoh C++ | bytes、closures、details、serialization、config、warnings 共 6 项上游测试 |
| Zenoh C/C++ | 独立目录 C shared、C static、C++ 三种 CMake 消费方式编译运行 |
| ZLMediaKit | MediaServer 版本检查及 C API 初始化、配置读写、关闭调用 |
| 四个通用头文件库 | C++17 编译及实际运行 |
| MAVSDK | 442 项上游单元测试分网络环境全部通过；独立目录 C++20 消费者及 6 个 UDP 场景通过，包含实际端口、断流恢复和连接重建 |

Zenoh 验证不覆盖完整网络互通矩阵，ZLMediaKit 验证不覆盖实际音视频推拉流。
