# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Planned

- 真实设备通知矩阵验证（Focus、静音、睡眠/唤醒、退出应用）
- 应用图标、Developer ID 签名、公证与 DMG
- 2027 年节假日日历（官方安排公布后）
- 英文界面
- iOS 交互设计与正式实现

## [0.1.0] - 2026-10-23

首个开源工程脚手架。

### Added

- 纯 Swift `LiangWenCore`：价格规则、日期覆盖、北京时间价格引擎、下次真实切换计算、价格倍率推导。
- 2026 价格快照与 2026 年法定节假日日历（来源与核对日期见 `Rules/` 与文档）。
- 结构化规则包：`manifest.json` + 价格/日历/提醒策略，SHA-256 校验、语义校验、原子安装、未来生效的 pending 区。
- 提醒计划：关闭/中等/强，提前 5 分钟选项，确定性事件 ID，不补发历史通知，强提醒有界重复与停止操作。
- macOS 菜单栏应用：`MenuBarExtra` 状态栏、304pt 面板、内嵌设置、本地偏好、规则来源/版本/覆盖展示、检查更新入口。
- iOS 最小只读外壳，复用共享引擎；明确标注交互设计未确认。
- `liangwen-rules` CLI：规则包校验与 manifest 校验和重算。
- 56 个 Swift Testing 单元测试，覆盖时段边界、周末/节假日、跨日、覆盖过期、规则完整性、提醒计划与文案。
- XcodeGen 工程定义、Makefile、GitHub Actions CI、issue/PR 模板、安全与贡献文档。
- 固定 XcodeGen 2.46.0 的安装脚本（官方 release + SHA-256 校验）与 `make doctor` 工具链检查。
- GitHub `Rules` workflow：PR/主分支校验规则与测试，主分支通过后自动发布到 `rules` 分支；应用默认从该分支读取规则。
- `make rules-publish` / `make rules-publish-dry-run` 与合作式 `Scripts/publish-rules.sh`。
- `make package-mac`：Release 通用二进制、签名/公证校验、zip/dmg 与 SHA-256；默认 ad-hoc。
- `make serve-test-rules`：生成近期峰谷切换的临时规则包并启动 localhost 规则源，辅助真机通知验证。
- 手动 `Release` workflow：只产出 workflow artifact，不创建公开 Release。
- 面向 AI 代理的 `AGENTS.md` 与分主题架构文档。

### Known limitations

- 未签名、未公证、无应用图标；尚未发布正式二进制。`make package-mac` 默认生成 ad-hoc 产物，仅用于本地验证。
- 规则源默认指向仓库 `rules` 分支；fork 需要同时修改 `project.yml` 与发布远端。只有 SHA-256 完整性校验，没有数字签名。
- 真实系统通知行为尚未在目标设备上记录验证结果。
- 强提醒使用重复通知，不是独立浮层，无法覆盖专注模式或静音。
- iOS 未设计，只有验证用外壳。
- 界面仅中文。
