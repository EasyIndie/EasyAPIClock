# 共享业务SDK与设备界面适配

依据ADR-0011。当前是可复用的项目业务库，不是已经承诺稳定API的通用商业SDK。

## 产品与依赖

- LiangWenCore：只需要判断价格／日历／下次切换或生成提醒计划的宿主可单独使用。RemoteRuleUpdater要求显式提供RuleDataFetching，不默认联网。
- LiangWenRuntime：需要完整规则安装、偏好修改、排程去重、自动更新或提醒预览的宿主使用ClockSession。该target只依赖Core，不importSwiftUI、AppKit、UIKit、Observation、Combine或UserNotifications。
- LiangWenKit：本项目现有Apple原生系统服务、中文文案及SwiftUI面板；ClockModel把会话值状态桥接为Combine ObservableObject，并转发操作。macOS13沿用同一业务会话，视图使用@ObservedObject订阅适配器。

依赖只向下。共享逻辑不复制到Apps或不同设备视图中。iOS当前只读外壳仍只使用引擎，不启用通知、自动更新或新交互。

## 接入会话

宿主提供Rules目录、规则支持目录、PreferencesStoring与ReminderScheduling实现、更新器（可为nil）、独立UserDefaults配置及初始时间，构造ClockSession。资源和服务选择由宿主负责，不要求加载谷蹬SwiftUI视图。

```swift
import LiangWenCore
import LiangWenRuntime

// repository / initialNow / preferences / stores / scheduler由宿主提供。
let session = ClockSession(
    active: repository.active(at: initialNow),
    preferences: preferences,
    repository: repository,
    preferencesStore: preferencesStore,
    scheduler: scheduler,
    updater: updater,
    settingsDefaults: settingsDefaults,
    initialNow: initialNow)
let observationID = session.observe { state in
    // 将Sendable值快照映射到本设备的界面状态。
}
await session.refresh(now: initialNow)
// 界面解绑时：
session.removeObserver(observationID)
```

上述代码应在MainActor执行。observe立即发送当前状态，后续在业务状态变更时同步推送，支持多个观察者；订阅本身不触发网络、磁盘或通知。状态不是可写的双向绑定，宿主通过setIntensity、setEarlyReminderEnabled、checkForUpdates等会话操作改变业务。

同一进程多个界面可以共享同一个会话；停止订阅不停止共享业务。一个会话只维护一份提醒计划签名、预览任务和自动更新节流状态，避免因多界面各自重算而重复排程。ClockModel(session:)是现有SwiftUI的接入方式，其释放只移除自身观察者，不取消其他界面或共享任务。

## 尚未通用化的部分

- 默认配置键、预览ID前缀与规则格式仍属于谷蹬；保留它们避免破坏已安装用户偏好。
- Runtime使用Foundation、OSLog、UserDefaults和MainActor，Core使用CryptoKit；本轮不宣称Linux或硬件运行时支持。
- 提醒预览结果已经类型化为PreviewOutcome；Core既有错误仍有中文LocalizedError，稳定SDK发布前需评估错误码和本地化边界。
- RuleRepository仍是现有目录存储实现。后续有真实嵌入式／内存存储需求时再提取仓库协议，不提前加入插件系统。
- Package.swift当前平台为macOS13/iOS17；Kit的Combine适配及双端构建已完成，macOS13真机运行仍待实测。
- 同一套代码在不同设备复用，不表示自动同步各设备偏好或通知任务。

## 验证

ClockSessionTests只导入Core／Runtime，覆盖多观察者、移除订阅、固定北京时间快照、提醒计划去重及类型化预览失败；Kit测试覆盖多个观察适配器共享会话与独立释放。既有设置／规则／预览回归保持。

make check-layers和CI限制Core/Runtime导入UI框架；SwiftPM依赖图限制反向模块依赖。make check仍运行规则校验、全部测试、lint与双端构建。

本次额外验证：独立临时副本将Package.swift设为macOS13，仅构建LiangWenRuntime成功；随后正式工程目标也降至13.0并完成构建；macOS13运行验收尚未完成。

ClockSessionState.lastAutomaticAttemptAt为既有自动更新节流记录的只读输出，包含失败、跨实例保留；手动检查不会修改。它是尝试收据，不是网络成功或新规则安装的保证。Kit负责北京时间格式化。
