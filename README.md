# 梁文钟 · LiangWen Clock

> 一个极简的 API 峰谷价格时钟：现在贵还是便宜、距离下次切换还有多久、切换时怎么提醒我。

梁文钟常驻 macOS 菜单栏，用「峰 / 谷 + 剩余时间」回答 DeepSeek API 的当前价格时段。点击展开一个小面板，只显示价格状态、模型单价差异、下一切换倒计时和一句日期摘要。它不做账号、API Key、用量统计、任务调度，也不会替你切换模型。

> 本项目是社区项目，与 DeepSeek 官方无隶属关系。价格以 [DeepSeek 官方价格页](https://api-docs.deepseek.com/zh-cn/quick_start/pricing/) 为准。

[![CI](https://github.com/wangzhizhou/liangwen-clock/actions/workflows/ci.yml/badge.svg)](https://github.com/wangzhizhou/liangwen-clock/actions/workflows/ci.yml)
[![Rules](https://github.com/wangzhizhou/liangwen-clock/actions/workflows/rules.yml/badge.svg)](https://github.com/wangzhizhou/liangwen-clock/actions/workflows/rules.yml)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

> 仓库：<https://github.com/wangzhizhou/liangwen-clock>。发布步骤见 [`docs/ops/release.md`](docs/ops/release.md)。

## 当前状态

这是 **v0.1.0 工程脚手架**，不是已发布产品。

| 能力 | 状态 |
|---|---|
| 北京时间峰谷规则、节假日覆盖、下次真实切换计算 | ✅ 已实现，56 个单元测试覆盖 |
| 内置 2026 价格与节假日规则包，SHA-256 校验 | ✅ 已实现 |
| macOS 菜单栏、主面板、内嵌设置、本地提醒偏好 | ✅ 已实现并可通过 `make run-mac` 启动 |
| 中等 / 强提醒的通知计划、去重、拒绝补发历史通知 | ✅ 计划/去重已实现；macOS 27 已验权限拒绝降级，通知投递待签名后复测 |
| 远程规则包下载、完整性校验、原子替换、未来生效 | ✅ 机制已实现；默认指向仓库 `rules` 分支，由 Rules workflow 发布 |
| iOS 共享引擎 | ✅ 最小外壳，仅用于验证跨平台核心 |
| 发布打包 | ✅ `make package-mac` 生成通用二进制 zip/dmg；Developer ID 签名待解锁 keychain，公证待配置 |
| iOS 交互设计 | ⛔ 尚未确认，当前外壳不代表正式设计 |
| 签名、公证、DMG、应用图标、英文界面 | ⛔ 未完成 |
| 规则包数字签名 | ⛔ 仅 SHA-256 完整性校验，见 [ADR-0004](docs/adr/0004-rule-bundles.md) |

设计基准是 [`docs/handoff/design-preview.html`](docs/handoff/design-preview.html)。用浏览器直接打开即可查看，它是交互示意，不是生产实现。

## 快速开始

要求：macOS 14+、Xcode 16+（Swift 6）。XcodeGen 由脚本安装固定版本，无需手动 `brew install`。

```bash
make bootstrap     # 安装固定 2.46.0 XcodeGen（SHA-256 校验）+ 生成工程 + 环境检查
make doctor        # 检查 macOS / Xcode / Swift / XcodeGen
make test          # 运行核心与界面文案测试
make validate-rules
make run-mac       # 构建并以 ad-hoc 签名启动菜单栏应用
make package-mac   # Release 通用二进制 + zip/dmg（ad-hoc，本地验证）
make serve-test-rules  # 生成近期切换测试规则并启动本地服务器
```

XcodeGen 版本固定在 [`.xcodegen-version`](.xcodegen-version)，安装脚本只下载官方 release 并校验 SHA-256；不会使用“latest”。

`LiangWenClock.xcodeproj` 是生成产物，不提交到仓库。修改工程结构请编辑 [`project.yml`](project.yml)。

只运行 SwiftPM 部分：

```bash
swift test --package-path Packages/LiangWen
swift run --package-path Packages/LiangWen liangwen-rules validate Rules
```

## 项目结构

```
Apps/
  Mac/                 macOS 菜单栏外壳（MenuBarExtra、唤醒/改时刷新）
  iOS/                 最小 iOS 外壳（仅验证共享引擎，设计未确认）
Packages/LiangWen/
  Sources/LiangWenCore   纯逻辑：规则、日历、引擎、提醒计划、更新校验
  Sources/LiangWenKit    SwiftUI 面板/设置、偏好、通知调度、规则安装
  Sources/LiangWenRuleTool 规则包校验与 manifest 重新计算 CLI
Rules/                 内置规则包（价格、2026 节假日、提醒策略、manifest）
Scripts/               固定版本工具安装、开发环境检查
docs/                  产品、架构、ADR、运维与原始交接包
```

依赖方向固定为 `Apps → LiangWenKit → LiangWenCore`。`LiangWenCore` 不依赖 SwiftUI、AppKit 或网络，所有时间答案由传入的 `Date` 和已验证规则决定。

## 关键约束

- 所有价格状态按 **Asia/Shanghai** 计算，不随设备时区改变。
- 周末与法定节假日全天为谷；调休上班的周六/周日 **不会** 变成峰。
- 时段是左闭右开：09:00 属峰，12:00 属谷，14:00 属峰，18:00 属谷。
- 倒计时指向真正的状态变化，不会在周末/假期午夜制造伪切换。
- 日期数据过期或缺失时显示「规则待更新」，暂停无法确认的价格提醒，不伪装成准确状态。
- 规则更新只接受声明式 JSON，不执行远程代码；更新不能覆盖用户选择的提醒强度。
- 启动、唤醒或改时后只安排未来事件，不补发历史通知。

更完整的产品与验收要求见 [`docs/product/requirements.md`](docs/product/requirements.md)。

## 规则数据

`Rules/` 中的价格快照核对于 **2026-10-23**，节假日依据国务院办公厅 2026 年放假安排整理。价格与政策会变化；发布前、以及每年新节假日安排公布后都需要重新核对。

```bash
# 修改 JSON 后重新计算 manifest 校验和
make rules-manifest

# 校验整个规则包
make validate-rules
```

`Rules/` 是唯一数据源。合并到 `main` 后，[`Rules` workflow](.github/workflows/rules.yml) 会重新校验并发布到独立的 `rules` 分支；应用默认读取：

```
https://raw.githubusercontent.com/wangzhizhou/liangwen-clock/rules
```

`rules` 分支是生成物，不要手工编辑。发布要求 `publishedAt` 严格递增，否则发布 job 会失败。CDN 可能有数分钟缓存。

更新流程、来源要求和回滚方式见 [`docs/ops/rule-update-runbook.md`](docs/ops/rule-update-runbook.md)，托管决策见 [ADR-0007](docs/adr/0007-github-rules-branch.md)。

## 文档

- [文档索引与权威顺序](docs/README.md)
- [产品概览](docs/product/overview.md) · [需求与验收](docs/product/requirements.md) · [Mac 设计基准](docs/product/design-macos.md)
- [架构概览](docs/architecture/overview.md) · [规则与数据](docs/architecture/rules-and-data.md) · [时间与日历](docs/architecture/time-and-calendar.md) · [提醒](docs/architecture/reminders.md) · [测试](docs/architecture/testing.md)
- [路线图](docs/roadmap.md) · [发布](docs/ops/release.md) · [平台验证清单](docs/ops/platform-validation.md)
- [给 AI 开发代理的约定](AGENTS.md) · [任务清单](TASKS.md)

## 参与

提交前请阅读 [`CONTRIBUTING.md`](CONTRIBUTING.md) 与 [`AGENTS.md`](AGENTS.md)。涉及价格或节假日的改动必须附官方来源、核对日期，并重新生成 manifest。

安全问题请按 [`SECURITY.md`](SECURITY.md) 私下报告，不要公开提交可利用细节。

## English summary

LiangWen Clock is a minimal, open-source API price-window clock for macOS (with a shared Swift core and an iOS shell). It shows whether DeepSeek API model tokens are currently in peak or valley pricing, the next real transition, and an optional notification. It is not affiliated with DeepSeek. Rules are declarative JSON with SHA-256-verified bundles; the app never executes remote code and always degrades to "rules need update" instead of guessing. See `docs/architecture/` for the design.

## License

[MIT](LICENSE) © 2026 LiangWen Clock contributors.
