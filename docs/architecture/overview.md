# 架构概览

## 目标

1. **正确**：北京时间、节假日、真实切换优先于任何 UI 便利。
2. **可降级**：规则过期、网络失败、数据损坏时保持诚实状态，不猜测。
3. **可更新**：价格、日历、提醒策略通过声明式数据更新，不发版改代码。
4. **可迭代**：纯逻辑核心可确定性测试；UI 与平台能力隔离；AI 代理能安全改动。
5. **可开源**：无第三方运行时依赖、无账号、无遥测、离线可用。

## 分层

```
Apps/Mac（菜单栏／生命周期）   Apps/iOS（只读外壳）
                       ↓
GudengKit：SwiftUI／文案／ClockModel观察适配／系统通知与登录项
                       ↓
GudengRuntime：ClockSession／值状态／业务流程／存储与能力协议
                       ↓
GudengCore：规则／校验／北京时间引擎／提醒计划／更新校验
```

依赖方向只能向下。Core与Runtime不依赖SwiftUI、AppKit、UIKit、Observation、Combine或UserNotifications。Core不创建网络客户端；RemoteRuleUpdater必须显式注入RuleDataFetching，URLSession实现位于Runtime。`make check-layers`与CI检查模块import边界。

## 模块职责

### GudengCore（纯逻辑）

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

### GudengRuntime（共享业务与Foundation能力）

| 类型 | 职责 |
|---|---|
| `ClockSession` | 共享价格刷新、未来提醒去重、偏好变更、规则更新和预览生命周期 |
| `ClockSessionState` | Sendable／Equatable值快照，供不同界面读取 |
| `PreviewOutcome` / `UpdateState` | 类型化业务结果；由呈现层生成本地化文案 |
| `PreferencesStoring` / `ReminderScheduling` | 注入的偏好和提醒能力接口 |
| `RuleRepository` / `RuleStatus` | 内置／下载／pending规则读取安装与状态 |
| `AutomaticUpdateSchedule` / `ReminderPreviewPlan` | 六小时尝试节流及有界预览策略 |
| `StrongRepeatRetention` | 刷新时保留窗口内强提醒重复 |
| `URLSessionRuleDataFetcher` / `RuleSourceConfiguration` | Foundation网络适配与宿主更新源配置 |

### GudengKit（界面与Apple平台适配）

| 类型 | 职责 |
|---|---|
| `ClockModel` | 薄的@MainActor ObservableObject适配器（@Published状态），订阅ClockSessionState并转发用户操作；可将同一会话注入多个适配器 |
| `AppEnvironment` | 组合根与分钟循环；持有会话适配器、通知实现、偏好存储及更新器 |
| `UserNotificationScheduler` | 系统通知授权、排程和停止，实现Runtime定义的协议 |
| `UserDefaultsPreferences` / `BundledRules` | 系统偏好持久化及宿主Bundle规则装载，资源不进入SDK |
| `LoginItemController` | SMAppService平台状态与审批／错误呈现，不进入共享业务会话 |
| `ClockText` / `ReminderCopy` | 中文格式化与通知文案；预览结果映射、RuleStatus.originText留在呈现边界 |
| `ClockPanelView` 等 | 固定334×322pt面板、设置、菜单栏标签 |

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
                         ClockSession(active:) → ClockModel(session:)
                                  │
                  UserDefaults 偏好 / 授权状态
                                  │
                        首次刷新 + 通知排程
```

### 每分钟刷新

```
ClockSession.refresh(now:)
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

- ClockSession与界面／系统服务都保持@MainActor隔离；SDK没有绑定任何UI观察框架。多个观察者收到同一会话的值快照，订阅不产生业务副作用。
- 核心类型是 `Sendable` 值类型；`ClockEngine` 可安全跨隔离域使用。
- `RuleRepository` 是 `Sendable` 的最终类，只在主 actor 调用；不持有共享可变内存状态。
- 通知回调通过 `@Sendable` 闭包 hop 回主 actor，不跨线程触碰 UI 状态。
- 刷新循环使用组合根持有的单个 `Task`，按分钟边界睡眠；唤醒/改时由 AppDelegate 触发立即刷新。

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
Packages/Gudeng/Sources/
  GudengCore/Domain/       LocalDate / MinuteOfDay / 金额 / 状态
  GudengCore/Rules/        规则模型、校验、manifest、加载
  GudengCore/Engine/       快照、比较、引擎
  GudengCore/Reminders/    计划器
  GudengCore/Updates/      远程更新与来源配置
  GudengCore/Support/      时区 / JSON 编解码
  GudengRuntime/Session/   共享会话、类型化值状态
  GudengRuntime/Services/  能力协议、预览／自动更新／重复保留策略
  GudengRuntime/Storage/   规则安装与Bundle装载
  GudengRuntime/Transport/ URLSession和宿主更新源配置
  GudengKit/Model/         观察适配器、组合根
  GudengKit/Services/      系统偏好、通知与登录项适配
  GudengKit/Presentation/  文案与格式化
  GudengKit/Views/         SwiftUI 面板
Rules/                       唯一规则数据源
```

## 构建系统

- SwiftPM 负责 `GudengCore` / `GudengRuntime` / `GudengKit` / CLI / 测试。
- XcodeGen 2.46.0 从 `project.yml` 生成两个应用工程；`.xcodeproj` 不提交。
- 版本固定在 `.xcodegen-version`；`Scripts/install-xcodegen.sh` 下载官方 universal release（含 `SettingPresets`）并校验 SHA-256；`make doctor` 检查工具链。
- `Rules/` 以 folder reference 原样复制到两个 app bundle。
- 工程标识统一为 `Gudeng`；偏好键、已安装规则目录与规则源配置在升级时迁移，Bundle ID 与 `lw.` 通知协议 ID 不变。见 [ADR-0014](../adr/0014-engineering-identity-gudeng.md)。
- 详见 [ADR-0002](../adr/0002-xcodegen.md)。

## 改动放在哪里

| 需求 | 位置 |
|---|---|
| 新价格字段 | `Core/Rules/PricingRules.swift` + 校验 + 文档 |
| 新日期语义 | `Core/Engine/ClockEngine.swift` + 测试 + 时间文档 |
| 新提醒阶段 | `ReminderPolicy` + `ReminderPlanner` + 文案 + 平台验证 |
| 新 UI 区块 | `GudengKit/Views`，先对照设计基准与需求 |
| 平台能力 | Kit提供原生实现，通过Runtime协议注入会话 |
| 共享业务流程 | `GudengRuntime/Session`，不得依赖界面与系统通知框架 |
| 规则数据 | `Rules/` + manifest + runbook |

### 菜单栏面板外观

`PanelAppearanceBridge` 位于 Kit 的 macOS 视图边界，用 NSViewRepresentable 将用户外观选择应用到所属 NSWindow；纯逻辑核心与 iOS 外壳不引入 AppKit。SwiftUI colorScheme 同步显式设置，避免菜单栏宿主未传递偏好导致视图颜色不变。

本地 `make run-mac` 构建成功后调用 `Scripts/run-mac.sh`，仅退出相同可执行文件完整路径的旧进程，限时等待后重新 open；若未退出则停止启动，避免误验旧实例。

### 设置平台服务与自动更新

`LoginItemController` 通过可替换LoginItemManaging服务读取SMAppService真实状态，Mac主应用注册、不使用辅助进程；错误与审批显式呈现。`AutomaticUpdateSchedule` 用固定时间判断6小时节流，ClockSession持久化开关/最近尝试并校验自动请求代次，禁止关闭期间安装在途结果。AppEnvironment单独持有自动检查Task，不阻塞分钟刷新；手动检查和自动检查共用现有整包更新流程。iOS不调度自动更新。详见ADR-0009。

## SDK提取与多设备界面

Core和Runtime已经各自导出SwiftPM library。设备界面共享会话流程，不复制价格或提醒逻辑；会话显式订阅后须removeObserver，ClockModel释放时自动解绑其订阅。SDK接入与已知边界见 [shared-sdk.md](shared-sdk.md) 和 ADR-0011。当前包部署目标为macOS13/iOS17。Kit用Combine桥接值状态，借入模型的视图通过@ObservedObject订阅；LoginSettingsContent单独订阅嵌套登录控制器。macOS13旧系统运行验收仍待完成。

维护者侧来源观察/候选规则由Scripts/official_pricing*.py及Official pricing workflow处理（ADR-0012），不进入Core/Runtime/Kit运行时。构建号2包含原创图标与品牌化状态UI（ADR-0013），最低系统与iOS范围不变。
