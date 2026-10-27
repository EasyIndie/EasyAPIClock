# 文档索引

本目录同时保存 **当前实现文档** 与 **原始设计交接包**。两者冲突时，按下方权威顺序处理。

当前产品名为「谷蹬」，副标题「DeepSeek API 峰谷钟点提醒」。原始交接包中的旧名称仅为历史来源记录，当前产品文案以 `product/` 为准。

## 权威顺序

1. **产品范围与验收**：`product/requirements.md`、`product/overview.md`
2. **视觉与布局**：`handoff/design-preview.html`，经 `product/design-macos.md` 解释原生适配
3. **数据语义与实现**：`architecture/*.md` 与 `adr/*.md`
4. **当前规则数据**：`Rules/` 中的 JSON 与 `manifest.json`
5. **实时价格与计费定义**：DeepSeek 官方来源（见 `Rules/pricing.json` 的 `source`）

发现文档与代码不一致时，不要默默选择一方：在 PR 中修正文档或代码，并说明原因。

## 目录

```
product/
  overview.md          定位、范围、成功标准
  requirements.md      价格快照、日期规则、F01–F12、验收 A01–A15
  design-macos.md      已确认的 Mac 视觉与交互，以及原生实现映射
  glossary.md          术语
architecture/
  overview.md          分层、模块、数据流、生命周期
  shared-sdk.md        共享业务SDK边界、接入与设备适配
  rules-and-data.md    规则 JSON、manifest、完整性、安装与更新
  time-and-calendar.md 北京时间、窗口、覆盖、切换算法
  reminders.md         提醒策略、计划、去重、平台限制
  testing.md           测试策略、验收映射、手动清单
adr/
  0001-swift-multiplatform-and-core.md
  0002-xcodegen.md
  0003-holiday-calendar.md
  0004-rule-bundles.md
  0005-reminder-scheduling.md
  0006-chinese-first-and-ios-shell.md
  0007-github-rules-branch.md
  0008-product-name-gudeng.md
  0009-settings-services.md
  0010-macos-13-observation-compatibility.md  已实施，旧系统待验
  0011-shared-application-runtime.md  共享会话与界面适配
ops/
  release.md           签名、公证、发布检查
  macos-13-compatibility.md macOS13编译审计、迁移方案与验收门槛
  mac-app-store-readiness.md Mac App Store要求初查与项目差距
  rule-update-runbook.md 规则更新操作手册
  platform-validation.md 真实设备验证矩阵（待执行）
design/
  README.md            设计资料入口
handoff/               2026-10-21 原始交接包（归档，不直接修改）
roadmap.md             里程碑、开放问题、明确不做
```

## 按角色阅读

- **产品/设计**：`product/` → `handoff/design-preview.html` → `roadmap.md`
- **首次贡献者**：根目录 `AGENTS.md` → `product/requirements.md` → `architecture/overview.md` → `architecture/testing.md`
- **AI 代理**：`AGENTS.md`（强制）→ 与任务相关的架构文档 → `TASKS.md`
- **发布维护者**：`ops/release.md` → `ops/rule-update-runbook.md` → `ops/platform-validation.md`
- **安全审查**：`SECURITY.md` → `adr/0004-rule-bundles.md` → `architecture/rules-and-data.md`

## 原始交接包

`handoff/` 是 2026-10-21 的设计交接材料，保留原始内容以便追溯：

- `01-product-plan.md` → 已整理进 `product/overview.md`
- `02-requirements-and-rules.md` → 已整理进 `product/requirements.md`
- `03-design-spec.md` → 已整理进 `product/design-macos.md`
- `04-agent-prompt.md` → 已转化为 `AGENTS.md` 与 `TASKS.md`
- `design-preview.html` → 仍是视觉基准；仅用于审阅，不代表生产实现

整理说明与价格复核记录见 [`handoff/PROVENANCE.md`](handoff/PROVENANCE.md)。

## 更新文档

| 变更 | 更新 |
|---|---|
| 功能范围 / 验收 | `product/requirements.md`、`CHANGELOG.md` |
| UI 视觉 / 文案 | `product/design-macos.md`、`ClockText`/`ReminderCopy` |
| 规则字段 / 更新机制 | `architecture/rules-and-data.md`、ADR、CLI 帮助 |
| 时间语义 | `architecture/time-and-calendar.md`、测试 |
| 通知行为 | `architecture/reminders.md`、`ops/platform-validation.md` |
| 构建 / 发布 | `architecture/overview.md`、`ops/release.md`、`README.md` |

- [官方价格自动化](ops/official-pricing-automation.md)
- [ADR-0012 官方来源观察](adr/0012-official-pricing-observation.md)
- [ADR-0013 品牌与动效](adr/0013-brand-and-controlled-motion.md)
- [本轮视觉规范](design/brand-refresh-2026-10-27/README.md)
