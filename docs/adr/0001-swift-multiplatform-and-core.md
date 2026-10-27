# ADR-0001：Swift 6 + SwiftUI，纯逻辑核心独立成包

- 状态：已接受
- 日期：2026-10-23
- 决策者：项目维护者

> 后续修订：macOS最低目标与界面观察机制见ADR-0010，共享业务层见ADR-0011；下文保留最初决策。

## 背景

交接包明确技术栈未定稿，但要求：macOS 常驻状态栏、同范围 iOS、真实系统通知、离线规则、可更新数据、可测试的规则与时间语义、便于 AI 迭代。网页设计稿只是视觉参考，不是技术选择。

候选方案包括 Electron/Tauri、Flutter、纯 AppKit、SwiftUI + SwiftPM。

## 决策

1. 语言/运行时：**Swift 6**，严格并发检查。
2. UI：**SwiftUI**；macOS 使用 `MenuBarExtra(.window)`，不建立主窗口。
3. 共享核心：**SwiftPM 包** `LiangWenCore`，只依赖 Foundation/CryptoKit，不依赖 UI 或平台通知。
4. 平台层：`LiangWenKit` 使用 SwiftUI、UserNotifications、UserDefaults。
5. 最低版本：**macOS 14 / iOS 17**（`@Observable`、现代 SwiftUI API）。
6. 通知：系统 `UserNotifications`，不做自定义守护进程。

## 后果

正面：

- 原生菜单栏、系统通知、沙盒与后续公证路径清晰。
- 核心可在毫秒级做确定性测试，不启动 UI。
- 类型安全、编译期并发检查适合 AI 代理迭代。
- 无第三方运行时依赖，供应链面小。

代价：

- 需要 Xcode；CI 只能用 macOS runner。
- 无法在 Linux 上跑核心测试（CryptoKit 也是 Apple-only）。
- 最低版本限制较新的系统。
- SwiftUI 菜单栏的呈现能力受系统限制（无法自定义通知外观）。

## 备选方案

- **Electron/Tauri**：跨平台成熟，但常驻内存高、菜单栏体验不原生、通知与沙盒模型不同。
- **Flutter**：UI 一致性好，但 macOS 菜单栏与系统通知仍需原生桥接，核心测试依赖 Dart。
- **纯 AppKit**：控制力强，但代码量与可维护性成本更高，SwiftUI 已足够。
- **SwiftPM-only 应用**：构建简单，但 iOS 目标、Info.plist、资源与签名流程需要手写脚本，不适合作为开源主路径。

## 后续

- 在 Xcode 16 与 Xcode 27 上验证 Swift 6 模式兼容性（CI 使用 macOS 15 runner）。
- 发布前确认签名、公证与分发渠道。
- 若未来需要 Linux 端（如 ESP 网关），把核心中 CryptoKit 依赖替换为可移植实现，并新增 ADR。
