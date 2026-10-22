# ADR-0002：用 XcodeGen 生成工程，不提交 .xcodeproj

- 状态：已接受
- 日期：2026-10-23
- 决策者：项目维护者

## 背景

应用需要 macOS/iOS 两个 target、Info.plist、entitlements、SwiftPM 本地包依赖与 Rules 资源。开源协作与 AI 代理都要求工程结构可读、可审阅、合并冲突少。

## 决策

- `project.yml` 是工程结构的唯一来源。
- 使用 **XcodeGen** 生成 `LiangWenClock.xcodeproj`。
- `.xcodeproj` 与 `Build/Generated/` 不提交，加入 `.gitignore`。
- Makefile 与 CI 在构建前执行 `xcodegen generate`。
- 部署目标、Swift 版本、bundle id、Info.plist 字段、entitlements 全部写在 `project.yml`。

## 后果

正面：

- 工程变更以 YAML diff 呈现，评审容易。
- 不会出现 `.pbxproj` 合并冲突。
- AI 代理可以安全地增删 target、设置、资源。
- 生成结果确定，CI 与本地一致。

代价：

- 贡献者需要安装 XcodeGen（`make bootstrap` 自动处理）。
- 打开 Xcode 前必须先 `make generate`。
- 极少数 Xcode 高级设置需要回退到 `settings` 或 `postBuildScripts`。

## 备选方案

- **提交 .xcodeproj**：零依赖，但合并冲突频繁、不可读，AI 容易改坏 UUID。
- **Tuist**：同样是 manifest-as-code，但依赖更重、版本耦合更强；本机虽已安装，不作为项目依赖。
- **纯 SwiftPM + 手写打包脚本**：无法自然支持 iOS target、Info.plist 与 entitlements，签名流程也更脆弱。
- **Bazel**：过度工程化，不适合小型开源应用。

## 后续

- 保持 XcodeGen 主版本固定；升级时在 CI 验证生成结果。
- 若未来 target 数量显著增长，再评估 Tuist。
