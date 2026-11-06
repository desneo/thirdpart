# 项目文档索引

- 库版本与归档目录：[README.md](README.md)。
- Ubuntu 24.04 构建与验证：[docs/ubuntu24.04.md](docs/ubuntu24.04.md)。
- MAVSDK 基线、UDP 定制和重建：[mavsdk/README.md](mavsdk/README.md)。
- 执行 push 前必须读取并遵守 [双端推送要求](README.md#双端推送要求)。

## MAVSDK 工作入口

- 修改或重建 MAVSDK 前，先读取其专用 README。
- v4.1.0 归档必须使用指定官方 commit，并应用对应 UDP 端口绑定补丁。
- 外部获取补丁时，使用 MAVSDK README 中的 Gist 固定 revision 并校验 SHA-256。
- 升级 MAVSDK 时重新适配补丁并验证实际端口、断流恢复和重定位消费。
- 版本、补丁或构建方式变动时，同步维护上述文档与归档检查入口。
