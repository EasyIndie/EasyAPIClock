# ADR-0014：工程标识统一为 Gudeng

- 状态：已接受
- 日期：2026-10-28
- 依据：产品已更名并迁入 EasyIndie，用户要求清除实现与文档中的旧「LiangWen」工程标识。

## 背景

对外产品名、Bundle ID（`com.easyindie.easyapiclock`）和规则源都已切换，但 SwiftPM 包、模块、Xcode target、工程文件与 CLI 仍保留 `LiangWen*`。这会让贡献者在代码、构建命令和文档之间看到两套命名，也容易把旧品牌误认为仍在使用。审计确认用户可见文案已无旧名，剩余问题集中在工程结构与少量持久化键。

## 决策

工程标识统一为 **Gudeng**（产品「谷蹬」的拼音），对应关系：

| 旧 | 新 |
|---|---|
| `Packages/LiangWen` | `Packages/Gudeng` |
| `LiangWenCore` / `LiangWenRuntime` / `LiangWenKit` | `GudengCore` / `GudengRuntime` / `GudengKit` |
| `LiangWenRuleTool` + `liangwen-rules` | `GudengRuleTool` + `gudeng-rules` |
| `LiangWenClock.xcodeproj` | `GudengClock.xcodeproj` |
| `LiangWenMac` / `LiangWeniOS` target 与产物 | `GudengMac` / `GudengiOS` |
| `LiangWenRuleSourceBaseURL` | `GudengRuleSourceBaseURL` |
| `LIANGWEN_*` 环境变量 | `GUDENG_*` |

### 保持不变

- Bundle ID `com.easyindie.easyapiclock`（含 iOS `.ios`）与规则源地址。
- 通知请求 ID 前缀 `lw.`、动作 `lw.stop`、分类 `lw.strong`、`userInfo` 键 `lw.eventID`。这些是已发布版本使用的通知协议标识：升级后若改动前缀，旧版本留下的 pending 无法被新计划清理，可能重复送达；旧胶囊通知上的「停止提醒」也会失效。`lw.` 从此只作为稳定协议标识，不再代表模块缩写。
- 规则 JSON 结构、manifest 字段、通知分类语义与提醒策略。
- 历史记录：`docs/handoff/` 原始交接包、既有 ADR、`docs/design/verification-*` 证据与 `CHANGELOG` 历史条目保留旧名，作为事实记录，不追改。

### 迁移

- 偏好：读取 `gudeng.preferences.v1`；缺失时回退读取 `liangwen.preferences.v1`，成功解码后写入新键，并保留旧键以支持回滚。
- 已安装规则：启动时若 `Application Support/Gudeng` 不存在且旧目录 `Application Support/LiangWen` 存在，整体移动；移动失败则复制，避免丢失已校验的下载包。
- 规则源：优先 `GudengRuleSourceBaseURL` / `GUDENG_RULE_SOURCE`，缺失时回退旧键，覆盖已发布的 v0.1.1 Info.plist。
- 通知线程标识改为 `gudeng.price-transition`；它只影响系统分组，不参与去重或迁移。

## 后果

- 贡献者使用 `Packages/Gudeng`、`gudeng-rules`、`GudengClock.xcodeproj` 与 `Gudeng*` target；CI、脚本、Dependabot 与模块边界检查同步更新。
- 升级用户保留提醒强度、提前提醒与已安装规则；通知 ID 不变，不会产生孤儿 pending。
- 旧 ADR 与归档文档继续使用历史名称，引用新实现时以本 ADR 和当前架构文档为准。

## 验证

- `PreferencesMigrationTests`：旧键读取、写入新键、新键优先、空存储返回 nil。
- `RuleStorageMigrationTests`：旧目录整体迁移、已有新目录时不覆盖。
- `RuleSourceConfigurationTests`：旧 plist/env 键回退、新键优先。
- `make check` 通过；`GudengMac.app` 以 `com.easyindie.easyapiclock`、最低 macOS 13 构建并启动。
