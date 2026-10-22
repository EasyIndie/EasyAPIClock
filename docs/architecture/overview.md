# 架构概览

## 目标

1. **正确**：北京时间、节假日、真实切换优先于任何 UI 便利。
2. **可降级**：规则过期、网络失败、数据损坏时保持诚实状态，不猜测。
3. **可更新**：价格、日历、提醒策略通过声明式数据更新，不发版改代码。
4. **可迭代**：纯逻辑核心可确定性测试；UI 与平台能力隔离；AI 代理能安全改动。
5. **可开源**：无第三方运行时依赖、无账号、无遥测、离线可用。

## 分层

```
┌──────────────────────────────────────────────┐
│ Apps/Mac        MenuBarExtra + 生命周期       │
│ Apps/iOS        最小只读外壳                  │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│ LiangWenKit                                   │
│  ClockModel (@MainActor @Observable)          │
│  SwiftUI 视图 / 中文文案                      │
│  通知调度 / UserDefaults / 规则安装           │
└──────────────────────┬───────────────────────┘
                       │
┌──────────────────────▼───────────────────────┐
│ LiangWenCore                                  │
│  规则模型 + 校验 + 规则包加载                 │
│  ClockEngine / PriceComparison                │
│  ReminderPlanner / 更新服务                   │
└──────────────────────────────────────────────┘
```

依赖方向只能向下。`LiangWenCore` 不 import SwiftUI、AppKit、UserNotifications 或网络客户端；它只接受 `Date`、`Data` 和已验证规则。

## 模块职责

### LiangWenCore（纯逻辑）

| 类型 | 职责 |
|---|---|
| `PricingRules` | 每周峰期窗口、模型与计费项、来源、时区 |
| `CalendarRules` | 覆盖范围、节假日、调休上班日（记录用） |
| `ReminderPolicy` | 默认强度、提前偏移、强提醒重复参数、声音开关 |
| `RuleBundleManifest` | 文件清单、SHA-256、发布时间、生效时间 |
| `RuleBundleLoader` | 解码、文件名安全、checksum、语义校验 |
| `RuleValidator` | 字段边界、重叠、覆盖、倍率可用性校验 |
| `ClockEngine` | 给定时刻的状态、当前窗口、下次真实切换、窗口结束 |
| `PriceComparison` | 从所有计费项推导统一倍率/百分比；不一致则降级 |
| `ReminderPlanner` | 从快照 + 偏好 + 策略生成未来提醒 |
| `RemoteRuleUpdater` | 拉取 manifest 与文件、校验、拒绝降级 |
| `RuleSourceConfiguration` | 从 Info.plist / 环境变量解析更新源，强制 HTTPS |

### LiangWenKit（平台与呈现）

| 类型 | 职责 |
|---|---|
| `ClockModel` | 持有规则/快照/偏好/授权/更新状态；每分钟刷新；驱动调度 |
| `AppEnvironment` | 组合根：规则仓库、偏好、通知调度、更新器、刷新循环 |
| `RuleRepository` | 内置/已安装/pending 规则目录的读取、安装、回退 |
| `UserNotificationScheduler` | UNUserNotificationCenter：授权、排程、停止、分类动作 |
| `StrongRepeatRetention` | 刷新时保留仍在窗口内的强提醒重复，避免被下一次替换取消 |
| `ClockText` | 状态名、价格行、倒计时、切换时间、日期摘要、菜单栏文本 |
| `ReminderCopy` | 通知标题/正文/副标题，全部由 `ReminderFacts` 推导 |
| `ClockPanelView` 等 | 304pt 面板、设置、状态栏标签 |

### Apps

- **Mac**：`MenuBarExtra` 场景、`AppDelegate` 观察唤醒/改时/时区变化。没有主窗口。
- **iOS**：只读外壳，使用共享 `ClockEngine` 与 `ClockText`，不请求通知、不含设置。不要在此发明正式设计。

## 数据流

### 启动

```
Bundle.main/Rules ──> RuleBundleLoader ──> VerifiedRuleBundle
                                  │
已安装规则目录（若有效）──────────┘（优先）
                                  │
                         ClockModel(active:)
                                  │
                  UserDefaults 偏好 / 授权状态
                                  │
                        首次刷新 + 通知排程
```

### 每分钟刷新

```
ClockModel.refresh(now:)
  ├─ RuleRepository.active(at: now)   // pending 到期则提升
  ├─ ClockEngine.snapshot(at: now)    // 纯计算
  ├─ ReminderPlanner.plan(...)        // 只排未来
  ├─ 计划签名变化？──否──> 结束
  └─ 是 ──> UserNotificationScheduler.replacePlan(...)
```

### 用户操作

- 改强度/提前提醒：写 UserDefaults → 清空计划签名 → 刷新 → 替换 pending。
- 检查更新：拉取并校验 → 安装到 active 或 pending → 重新加载规则 → 强制替换计划 → 显示真实结果。
- 停止强提醒：通知动作 `lw.stop` → 移除该事件所有 pending/已送达通知。

## 并发模型

- `ClockModel`、`AppEnvironment`、`UserNotificationScheduler` 都是 `@MainActor`。
- 核心类型是 `Sendable` 值类型；`ClockEngine` 可安全跨隔离域使用。
- `RuleRepository` 是 `Sendable` 的最终类，只在主 actor 调用；不持有共享可变内存状态。
- 通知回调通过 `@Sendable` 闭包 hop 回主 actor，不跨线程触碰 UI 状态。
- 刷新循环使用单个结构化 `Task`，按分钟边界睡眠；唤醒/改时由 AppDelegate 触发立即刷新。

## 时间模型

- 固定 `Calendar` + `Asia/Shanghai`，不使用 `TimeZone.current`。
- 所有 JSON 日期是本地日期（`YYYY-MM-DD`）或带时区的 ISO8601 时刻。
- 规则时间戳编码为 `+08:00`，便于中文维护者审阅。
- 详见 [`time-and-calendar.md`](time-and-calendar.md)。

## 失败策略

| 失败 | 行为 |
|---|---|
| 内置规则缺失/无效 | 应用打包缺陷；`preconditionFailure`（CI 会阻止） |
| 已安装规则损坏 | 回退内置规则；设置中显示错误 |
| 日历覆盖不足 | 状态未知或切换未确认；暂停价格提醒；显示「规则待更新」 |
| 更新下载失败 | 保留旧规则；设置显示失败原因 |
| 更新校验失败 | 不安装；保留旧规则 |
| 未来生效 | 放入 pending；到期提升，不提前改变状态 |
| 通知权限拒绝 | 时钟继续工作；设置显示「通知未授权」与系统设置入口 |
| 应用退出 | 已排定通知可能仍送达，但不再重排；文档明确不承诺 |

## 文件地图

```
Apps/Mac/Sources/            入口 + AppDelegate
Apps/iOS/Sources/            只读外壳
Packages/LiangWen/Sources/
  LiangWenCore/Domain/       LocalDate / MinuteOfDay / 金额 / 状态
  LiangWenCore/Rules/        规则模型、校验、manifest、加载
  LiangWenCore/Engine/       快照、比较、引擎
  LiangWenCore/Reminders/    计划器
  LiangWenCore/Updates/      远程更新与来源配置
  LiangWenCore/Support/      时区 / JSON 编解码
  LiangWenKit/Model/         模型、状态、组合根
  LiangWenKit/Services/      偏好、规则仓库、通知、内置规则
  LiangWenKit/Presentation/  文案与格式化
  LiangWenKit/Views/         SwiftUI 面板
Rules/                       唯一规则数据源
```

## 构建系统

- SwiftPM 负责 `LiangWenCore` / `LiangWenKit` / CLI / 测试。
- XcodeGen 2.46.0 从 `project.yml` 生成两个应用工程；`.xcodeproj` 不提交。
- 版本固定在 `.xcodegen-version`；`Scripts/install-xcodegen.sh` 下载官方 universal release（含 `SettingPresets`）并校验 SHA-256；`make doctor` 检查工具链。
- `Rules/` 以 folder reference 原样复制到两个 app bundle。
- 详见 [ADR-0002](../adr/0002-xcodegen.md)。

## 改动放在哪里

| 需求 | 位置 |
|---|---|
| 新价格字段 | `Core/Rules/PricingRules.swift` + 校验 + 文档 |
| 新日期语义 | `Core/Engine/ClockEngine.swift` + 测试 + 时间文档 |
| 新提醒阶段 | `ReminderPolicy` + `ReminderPlanner` + 文案 + 平台验证 |
| 新 UI 区块 | `LiangWenKit/Views`，先对照设计基准与需求 |
| 平台能力 | `LiangWenKit/Services`，通过协议注入模型 |
| 规则数据 | `Rules/` + manifest + runbook |
