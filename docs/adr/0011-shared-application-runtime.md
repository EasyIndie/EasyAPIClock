# ADR-0011：共享业务会话与界面适配分离

- 状态：已接受
- 日期：2026-10-26
- 依据：用户要求共享完整基础业务逻辑，隔离多设备界面，并为后续通用SDK提取建立边界。

## 决策

依赖方向为Apps → LiangWenKit → LiangWenRuntime → LiangWenCore。

- Core：规则、确定性引擎、提醒计划、声明式更新校验。网络传输通过RuleDataFetching注入，不默认创建URLSession。
- Runtime：共享ClockSession、可发送的ClockSessionState、更新／预览策略、偏好和排程协议、规则仓库与Foundation实现。不得import SwiftUI、AppKit、UIKit、Observation、Combine或UserNotifications。
- Kit：ClockModel作为薄的UI观察适配器（当前为Combine）；中文文案、SwiftUI视图和系统通知／登录项／UserDefaults具体适配保留在此。
- Apps：组合与生命周期；iOS仍是只读外壳，不因此扩展设计或通知功能。

ClockSession通过显式订阅／移除接口同步输出不可变状态，允许多个界面适配器共享同一个会话。界面订阅不触发通知或网络；所有修改通过会话操作进入，避免重复排程。取消订阅不取消共享会话中的业务任务。预览结果用类型化结果表达，由Kit转换为文案。

基础业务SDK产品先以LiangWenCore和LiangWenRuntime本地SwiftPM library提供；保留项目现有配置键和规则语义，不宣称已经形成稳定通用SDK或支持其他厂商。未来通用化需以实际复用需求提取配置、存储和错误模型，不引入第三方运行时。

## 兼容性与验证

分层本身不改变App最低系统、不改变UI、偏好键、规则数据、通知ID或实际业务行为。Runtime移除Observation后，macOS13适配可以集中在Kit层，ADR-0010在后续本轮适配中已实施，旧系统运行验收仍待完成。

保留既有回归测试，并新增仅依赖Core/Runtime的会话测试，验证多观察者、取消订阅、固定时间状态与提醒计划。make check和双端构建必须通过。新增依赖不反向流入Core；开发文档同步依赖图及SDK边界。
