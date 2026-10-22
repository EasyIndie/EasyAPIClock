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
- 固定 XcodeGen **2.46.0**：版本写入 `.xcodegen-version`。
- `Scripts/install-xcodegen.sh` 下载官方 universal release，**校验 SHA-256** 后把完整发行包（`bin/` + `share/xcodegen/SettingPresets`）放入 `.build/tools/xcodegen/`。不安装“latest”，也不只拷贝裸二进制。
- Makefile 的 `generate` 使用 `.build/tools/xcodegen/bin/xcodegen`；`make doctor` 检查完整工具链；CI 使用同一脚本，不使用 `brew install xcodegen`。

## 后果

正面：

- 工程变更以 YAML diff 呈现，评审容易。
- 不会出现 `.pbxproj` 合并冲突。
- AI 代理可以安全地增删 target、设置、资源。
- 生成结果确定，CI 与本地一致。

代价：

- 贡献者需要运行 `make bootstrap`；首次会下载约 10 MB 的官方二进制，需要网络。
- 打开 Xcode 前必须先 `make generate`。
- 极少数 Xcode 高级设置需要回退到 `settings` 或 `postBuildScripts`。
- 升级 XcodeGen 需要同时更新版本与 SHA-256，并重新检查生成结果。
- 官方 zip 是 universal 二进制；校验和固定后，下载内容不会被“latest”悄悄替换。
- **必须安装完整发行包，而不是只复制二进制。** XcodeGen 从可执行文件旁的 `share/xcodegen/SettingPresets` 读取平台预设（`SDKROOT`、`SUPPORTED_PLATFORMS` 等）。只复制 `bin/xcodegen` 会让 iOS target 静默失去平台设置，scheme 被识别为 macOS，构建出现难以定位的模块/架构错误。安装脚本会检查 `SettingPresets` 是否存在。

## 备选方案

- **提交 .xcodeproj**：零依赖，但合并冲突频繁、不可读，AI 容易改坏 UUID。
- **Tuist**：同样是 manifest-as-code，但依赖更重、版本耦合更强；本机虽已安装，不作为项目依赖。
- **纯 SwiftPM + 手写打包脚本**：无法自然支持 iOS target、Info.plist 与 entitlements，签名流程也更脆弱。
- **Bazel**：过度工程化，不适合小型开源应用。

## 升级流程

1. 修改 `.xcodegen-version`。
2. 下载对应 release 的 `xcodegen.zip`，用 `shasum -a 256` 计算校验和。
3. 更新 `Scripts/install-xcodegen.sh` 中的 `SHA256`（URL 由版本号自动拼接）。
4. `rm -rf .build/tools && make bootstrap`，确认版本与生成结果。
5. 运行 `make check`，在 PR 中记录升级原因与生成差异。
6. 不要用 `brew install xcodegen` 或 `brew upgrade` 绕过固定版本；`make doctor` 会报告不匹配。

## 后续

- 若 target 数量显著增长、需要模块图与缓存，再评估 Tuist。
- 若贡献者普遍不愿运行生成步骤，可改为提交 `.xcodeproj`，同时保留 `project.yml` 作为可选生成方式；这一回退不需要改业务代码。
