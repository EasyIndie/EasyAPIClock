# ADR-0010：macOS 13 的状态观察兼容方案

- 状态：已接受（代码已实施，旧系统完整运行矩阵待完成）
- 日期：2026-10-26
- 关联：ADR-0001、ADR-0009、`docs/ops/macos-13-compatibility.md`

## 背景

用户要求在提交推送当前界面迭代后，下一步准备支持 macOS 13。实施前正式目标为 macOS 14 / iOS 17。临时副本降至13试编译，确认 ClockModel 与 LoginItemController 的 Observation 宏和运行时是阻塞点。

## 决策

1. 仅将 macOS 最低版本降至13.0；iOS维持17.0。保持Swift6与严格并发检查，不改界面设计、业务规则、通知或偏好键。
2. 使用系统Combine的ObservableObject与@Published替代两个模型的@Observable；服务依赖、Task、引擎和内部缓存不发布。维持@MainActor隔离。不引入第三方回移植库，也不维护两套模型。
3. SwiftUI消费者明确使用@ObservedObject订阅借入的模型；生命周期继续由AppEnvironment持有，不在子视图创建第二个ClockModel。
4. 登录项是嵌套对象，需要独立订阅LoginItemController（优先提取登录设置子视图）。仅订阅ClockModel不足以接收子对象状态／错误变化，不能依赖每分钟父模型刷新掩盖遗漏。
5. 工程定义和Package.swift同步调整；保留Release arm64+x86_64通用构建与架构断言。旧ADR保留历史决策，实施时由本ADR说明最低版本与观察机制的变更。

## 验证门槛

- 补充发布者及视图订阅相关回归，覆盖倒计时刷新、预览开始／停止、异步规则更新反馈和登录项审批／错误更新。
- make check通过；Release双架构构建通过，lipo确认两种slice，Info.plist与Mach-O的最低系统一致为13.0。
- macOS13上实测启动、菜单栏刷新、设置亮暗／滚动／重开、偏好持久化、登录启动与通知路径。分别记录arm64与x86_64运行证据；Rosetta不能替代macOS13实测。
- iOS保持17.0，构建与只读外壳不回归；现有UI验收未覆盖项继续保留，不因兼容构建通过而标完成。

## 备选与取舍

- 给@Observable加macOS14 availability：只能隐藏主体功能，无法满足13上完整菜单栏与设置，排除。
- 运行时分叉两套模型：增加重复状态和通知排程风险，不采用。
- 第三方Observation回移植：违反项目无第三方运行时依赖约束，不采用。
- 系统Combine：增加显式发布与订阅代码，但兼容版本充足、依赖可审计，适合本项目。

已在正式工程和SwiftPM中实施13.0目标，完成Combine桥接和嵌套登录视图订阅；这不代表macOS13真机运行验收已完成。

## ADR-0011之后的实施调整

共享业务已迁往独立ClockSession，Kit的ClockModel只持有ClockSessionState并桥接观察；本轮已迁移这一状态属性及LoginItemController，不再给业务流程引入Combine。Runtime已在临时副本13目标单独编译通过，正式包最低版本现已调整为13.0。

2026-10-26补充：pro（macOS13.7.8 x86_64）已原生运行通用Release，菜单栏及设置基础路径可用。详细记录见 `docs/design/verification-2026-10-26/macos13-intel/`；此项不替代arm64的macOS13、登录启动和通知完整矩阵。
