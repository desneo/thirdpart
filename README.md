# 三方库归档

按库版本、CPU 架构和 Ubuntu 版本保存头文件与编译产物。`x64/ubuntu24.04` 对应 Ubuntu 24.04 x86_64 本机 Release 构建；纯头文件库使用通用目录。

| 库 | 版本 | Ubuntu 24.04 使用位置 |
| --- | --- | --- |
| BehaviorTree.CPP | 4.10.0 | `behaviortree/4.10.0/x64/ubuntu24.04` |
| Eigen | 5.0.1 | `eigen/5.0.1` |
| eventpp | 0.1.3 | `eventcpp/v0.1.3/include` |
| fmt | 12.2.0 | `fmt/12.2.0/x64/ubuntu24.04` |
| GeographicLib | 2.7 | `geographiclib/v2.7/x64/ubuntu24.04` |
| magic_enum | 0.9.8 | `magic_enum/v0.9.8/include` |
| [MAVSDK](mavsdk/README.md) | 4.1.0 + UDP 端口绑定补丁 | `mavsdk/v4.1.0/x64/ubuntu24.04` |
| nlohmann_json | 3.12.0 | `nlohmann_json/v3.12.0/include` |
| Pluma | 固定源码提交及连接入口补丁 | `pluma/x64/ubuntu24.04` |
| spdlog | 1.17.0 | `spdlog/v1.17.0/x64/ubuntu24.04` |
| zenoh-c | 1.10.0 | `zenohc/1.10.0/x64/ubuntu24.04` |
| zenoh-cpp | 1.10.0 | `zenohcpp/1.10.0/x64/ubuntu24.04` |
| ZLMediaKit | 4b07053 | `zlmediakit/4b07053/x64/ubuntu24.04` |

构建方法、依赖和验证说明见 [Ubuntu 24.04 构建说明](docs/ubuntu24.04.md)。

## 双端推送要求

每次执行 push，除原目标仓库外，必须额外同步到 [GitHub desneo/thirdpart](https://github.com/desneo/thirdpart)。两端须推送相同分支和提交；任一端失败都必须明确报告，不能将单端成功视为同步完成。

以当前 `main` 分支为例，依次执行：

```bash
git push origin main
git push git@github.com:desneo/thirdpart.git main
```

其他分支使用对应的相同分支名。GitHub 命令使用 SSH 地址，与上述 HTTPS 链接指向同一个仓库；推送后应核对两端分支的 commit 与本地一致。
