# AGENTS.md

本文件是 AI 开发代理（以及人类贡献者）进入本仓库的唯一工作契约。开始改动前必须读完本文件，并按「必读顺序」阅读产品与架构文档。

## 1. 项目一句话

梁文钟是一个常驻 macOS 菜单栏的极简 API 峰谷价格时钟，使用 Swift 6 + SwiftUI；共享纯逻辑核心同时服务 macOS 应用和未定稿的 iOS 外壳。

## 2. 必读顺序

1. `docs/product/overview.md`
2. `docs/product/requirements.md`（F01–F12 与 A01–A15 验收）
3. `docs/product/design-macos.md`
4. `docs/architecture/overview.md`
5. 与任务相关的架构文档：`rules-and-data.md`、`time-and-calendar.md`、`reminders.md`、`testing.md`
6. `TASKS.md` 中的当前任务与验收标准
7. `docs/adr/` 中已接受的决策

设计与视觉以 `docs/handoff/design-preview.html` 为基准；产品范围以 `docs/product/requirements.md` 为准；实时价格以 DeepSeek 官方来源为准。发现冲突时先记录，再解决，不得默默沿用模拟数据。

## 3. 不可违反的规则

1. **北京时间。** 所有价格状态、节假日和切换时刻按 `Asia/Shanghai` 计算，与设备时区无关。不要用 `TimeZone.current`。
2. **不伪造数据。** 不得编造节假日、调休、价格或来源。没有官方依据时，保持「规则待更新」的降级状态。
3. **不猜测。** 日期覆盖不足、规则无效或下次切换无法确认时，不展示精确倒计时，不发送价格提醒。
4. **周末/调休语义。** 周末与法定节假日全天为谷；调休上班的周末 **仍然是谷**，不要按“是否上班”改写价格。
5. **真实切换。** 下次切换是状态真正变化的时刻；周末、假期、跨年连续谷期要合并，不得在午夜制造伪切换。
6. **不补发历史。** 启动、唤醒、改时、规则更新后只安排未来事件；不要把错过的切换集中补发。
7. **用户偏好优先。** 远程规则更新不得覆盖或提高用户选择的提醒强度，也不得关闭/开启提前提醒。
8. **声明式配置。** 只接受有限 JSON 字段；不得引入远程脚本、表达式求值或任意代码执行。
9. **完整性。** 规则包必须成套校验（manifest + 三个文件 + SHA-256 + 语义校验）后才能替换；失败保留旧版本。
10. **不扩大范围。** 不做番茄钟、账号、API Key、Token 统计、消费分析、任务管理、自动切换模型、Agent 集成、硬件配网。iOS 页面未设计，不得声称已设计完成。
11. **不虚假承诺。** 不承诺跨时段请求锁价；不说“全部 API 费用减半”（Search/Fetch 单独计费）；不承诺覆盖专注模式、静音或系统限制。
12. **视觉克制。** 不增加图表、完整价格表、装饰动效或常驻主窗口；正式 UI 不包含设计稿底部的演示控件。

## 4. 命令

```bash
make bootstrap        # 安装固定版本 XcodeGen + 生成工程 + 环境检查
make doctor           # 检查 macOS / Xcode / Swift / XcodeGen 版本
make generate         # 仅生成 Xcode 工程
make test             # swift test --package-path Packages/LiangWen
make validate-rules   # 校验 Rules/ 规则包
make rules-manifest   # 重新计算 manifest 校验和（修改规则后必须执行）
make rules-publish-dry-run  # 校验 + 检查 publishedAt，不推送
make rules-publish    # 校验 + 发布到 rules 分支（通常由 Rules workflow 执行）
make build-mac
make build-mac-adhoc  # ad-hoc 签名构建，不启动
make build-ios
make run-mac          # ad-hoc 签名并启动 macOS 应用
make package-mac      # Release 通用二进制 + zip/dmg（ad-hoc）
make package-mac-notarized  # Developer ID 公证并打包（需授权与凭据）
make serve-test-rules # 生成近期切换测试规则并启动本地服务器
make test-rules       # 只生成测试规则包
make format           # swift format 全量格式化
make lint             # swift format lint
make check            # 规则校验 + 测试 + lint + 双端构建
```

`make check` 是提交前的最低门槛。CI 会重复执行这些检查。

XcodeGen 版本固定在 `.xcodegen-version`，由 `Scripts/install-xcodegen.sh` 下载官方 release 并校验 SHA-256。不要用 `brew install/upgrade xcodegen` 绕过固定版本；升级流程见 ADR-0002。

`.swift-format` 必须保持与 CI 的 Xcode 16.4 / swift-format 600 兼容；不要加入只有新工具链才支持的键（例如 `reflowMultilineStringLiterals`）。CI 会执行 `make lint`。

## 5. 代码地图与依赖方向

```
Apps/Mac  ──┐
Apps/iOS  ──┴──> LiangWenKit ──> LiangWenCore
                  SwiftUI/通知/偏好/安装      纯逻辑，无 SwiftUI/AppKit
```

- `LiangWenCore`：规则解码与校验、`ClockEngine`、`PriceComparison`、`ReminderPlanner`、`RuleBundleLoader`、`RemoteRuleUpdater`。必须保持可测试、确定性、无 UI 依赖。
- `LiangWenKit`：`ClockModel`（@MainActor @Observable）、`AppEnvironment`、通知调度、UserDefaults 偏好、规则安装、所有 SwiftUI 视图与中文文案。
- `Apps/Mac`：只做应用入口、`MenuBarExtra` 场景、唤醒/改时观察。
- `Apps/iOS`：只做最小只读外壳。不要在这里发明 iOS 交互；先补设计文档与 ADR。
- `Rules/`：唯一规则数据源；应用通过 folder reference 打包。不要在其他地方复制规则 JSON。

新增跨层依赖前先写 ADR。不得引入第三方运行时依赖；SwiftPM 依赖会破坏“离线、可审计”的定位。

## 6. 修改指南

### 改价格或节假日

1. 打开官方来源并记录 URL 与核对日期。
2. 只改 `Rules/` 中对应 JSON；价格、日历、提醒策略可分别更新，但必须成套发布。
3. 更新 `manifest.json` 的 `bundleVersion`、`publishedAt`、`effectiveFrom`；未来生效的规则会被放进 pending 区。
4. 执行 `make rules-manifest`，再执行 `make validate-rules`。
5. 运行 `make test`；如价格快照变化，同步更新 `RuleBundleTests.pricesMatchSnapshot` 与产品文档中的快照表。
6. 在 PR 中附来源链接、核对日期、变更摘要与未覆盖风险。
7. 合并到 `main` 后，`Rules` workflow 会再次校验并发布到 `rules` 分支。`publishedAt` 必须严格递增，否则发布 job 失败；完全相同视为已发布。
8. **不要直接编辑 `rules` 分支。** 它是生成物，下一次发布（force push）会覆盖手工改动。

不要为了让测试通过而放宽校验。不要在没有新来源时“顺手”改数字。

### 修改引擎或时间语义

- 先补/改测试，再改实现。测试使用固定的北京时间字符串（例如 `2026-10-21T09:00:00+08:00`），不得使用 `.now` 或真实当前日期。
- 覆盖左闭右开、跨午夜、跨周末、连续假期、覆盖边界、未来生效规则。
- 保持 `ClockEngine` 纯函数式；不要在核心中读取系统时区、网络、UserDefaults 或当前时间。

### 修改提醒

- 先读 `docs/architecture/reminders.md`。
- 提醒事件 ID 必须保持确定性；同一事件只安排一次。
- 不为过去的事件补发；提前提醒错过就跳过，正式切换仍可提醒。
- 强提醒必须有有界重复与停止路径；不得无限循环。
- 用户关闭提醒后立即取消 pending；规则更新后重新安排，但不得改变用户强度。

### 修改 UI

- 以 `docs/product/design-macos.md` 为准，面板宽度约 304pt。
- 文案集中放在 `ClockText` / `ReminderCopy`，不要在视图里散落硬编码数字（倍率、百分比、时长都必须来自规则或 facts）。
- 价格说明必须带基准（峰期倍率或谷期低百分比），不能只写“半价”。
- 未知状态显示「待确认 / 规则待更新 / —」，不要显示看似精确的时间。
- 新增交互前先确认它在 F01–F12 内；超出范围先写需求与 ADR。

## 7. 定义完成（DoD）

- [ ] 行为符合 `docs/product/requirements.md` 中相关条目与验收场景。
- [ ] 新逻辑有单元测试；失败路径（坏数据、过期覆盖、更新失败）也有测试。
- [ ] `make check` 通过。
- [ ] 用户可见变更已更新 `CHANGELOG.md`；架构/数据格式变更已更新对应文档与 ADR。
- [ ] 规则数据变更已更新 manifest、来源与核对日期，并验证 checksum。
- [ ] 没有新增范围外功能、第三方运行时依赖或网络调用（测试中也不访问真实网络）。
- [ ] 没有提交生成物：`LiangWenClock.xcodeproj`、`Build/Generated/`、`.build/`、`Package.resolved`（无依赖时）。
- [ ] PR 描述写清：改了什么、为什么、如何验证、平台限制、剩余事项。

## 8. 测试约定

- 使用 Swift Testing（`import Testing`、`@Test`、`#expect`、`#require`），不新增 XCTest。
- 时间固定；禁止 `sleep`、`Date()` 断言和依赖真实时钟的测试。
- 引擎测试使用 `Packages/LiangWen/Tests/LiangWenCoreTests/Fixtures.swift`；规则包端到端测试读取仓库 `Rules/`。
- 网络更新测试使用内存 `RuleDataFetching` 假实现，不访问网络。
- 验收场景与测试的映射见 `docs/architecture/testing.md`；新增验收项时同步更新该表。

## 9. 提交与 PR

- 提交信息使用 Conventional Commits：`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, `rules:`。
- 一个提交只做一件事；不要格式化无关文件。
- PR 使用 `.github/PULL_REQUEST_TEMPLATE.md`；规则变更使用 `rule_update` issue 模板先记录来源。
- 未获明确授权不得发布、公证、上传规则包到线上或创建 Release。`make package-mac` 只做本地 ad-hoc 打包；`make package-mac-notarized` 会提交 Apple 公证，必须获得授权。`.github/workflows/release.yml` 只手动产出 workflow artifact，不创建公开 Release。

## 10. 文档同步表

| 改动 | 必须同步 |
|---|---|
| 价格/节假日 JSON | `Rules/manifest.json`、`docs/product/requirements.md` 快照、`CHANGELOG.md` |
| 规则字段或校验 | `docs/architecture/rules-and-data.md`、ADR、CLI 帮助 |
| 时间语义/引擎 | `docs/architecture/time-and-calendar.md`、验收测试 |
| 提醒策略/调度 | `docs/architecture/reminders.md`、`docs/ops/platform-validation.md` |
| UI 布局/文案 | `docs/product/design-macos.md`、`ClockText`/`ReminderCopy`、测试 |
| 工程结构/构建 | `README.md`、`docs/architecture/overview.md`、CI |
| 发布流程 | `docs/ops/release.md`、`CHANGELOG.md` |

## 11. 已知限制（不要假装已解决）

- iOS 交互设计未确认；当前只是只读外壳。
- 强提醒使用有界重复的系统通知，不是独立浮层，也无法覆盖专注模式/静音。
- 规则包只有 SHA-256 完整性校验，没有数字签名；信任根是 HTTPS、GitHub 仓库控制权与 Actions 权限。
- 规则默认托管在 `raw.githubusercontent.com/.../rules`；依赖 GitHub 可用性，raw CDN 可能缓存数分钟；仓库转私有后客户端无法匿名读取。
- 2026 年之后没有内置节假日数据；2027 年安排公布前会显示「规则待更新」。
- 真实设备上的通知、睡眠唤醒、退出应用、权限与专注模式行为尚待验证，见 `docs/ops/platform-validation.md`。
- 应用图标、签名、公证、DMG、英文界面尚未完成；`make package-mac` 的默认产物是 ad-hoc，不可分发。
- 通知点击目前只激活应用，不会自动展开面板。

如果任务要求解决上述限制，先确认产品范围并新建 ADR；不要用占位数据或未验证的“看起来能用”替代。
