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

### 不做旧数据兼容

MVP 尚未对外发布，当前构建就是第一版。因此不实现旧键回退、目录迁移或旧配置键兼容：首次运行直接写入 `gudeng.preferences.v1` 并创建 `Application Support/Gudeng`。发布后再按正常版本演进原则处理偏好、规则目录与配置键的兼容。

### 从第一版起固定的标识

- 通知请求 ID 前缀 `lw.`、动作 `lw.stop`、分类 `lw.strong`、`userInfo` 键 `lw.eventID` 自第一版起就作为稳定协议标识使用，与模块名无关；后续如需改动必须提供迁移。

## 后果

- 贡献者使用 `Packages/Gudeng`、`gudeng-rules`、`GudengClock.xcodeproj` 与 `Gudeng*` target；CI、脚本、Dependabot 与模块边界检查同步更新。
- 开发机或测试安装中遗留的旧容器数据不迁移；需要干净状态时删除对应容器即可。
- 旧 ADR 与归档文档继续使用历史名称，引用新实现时以本 ADR 和当前架构文档为准。

## 验证

- `make check` 通过；`GudengMac.app` 以 `com.easyindie.easyapiclock`、最低 macOS 13 构建并启动。
- 改名后首次启动使用默认偏好与内置规则，菜单栏状态正常。
