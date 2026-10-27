# 谷蹬项目交接（Pi agent）

更新日期：2026-10-28  
仓库：`https://github.com/EasyIndie/EasyAPIClock`  
产品：谷蹬（DeepSeek API 峰谷钟点提醒）

本文供新的 Pi agent 恢复项目上下文。它是状态摘要，不替代仓库契约；实现前必须先读根目录 `AGENTS.md`，并按其中顺序查看产品、架构、任务和 ADR 文档。

## 交接时的 Git 状态

- 当前默认分支：`main`，交接前工作区干净。
- 最新提交：`a841b2e`（`fix: avoid command substitution in release notes (#8)`），标签 `v0.1.1`。
- 远端保留 `main` 与 `rules`。`rules` 是 Rules workflow 生成的规则快照分支，不要手工改写或删除。
- 已清理旧的 `codex/*` 本地分支和冗余的 `rules-publish` 本地分支；远端无开放 PR。
- 远端 `codex/macos-13-runtime` 已删除。它没有独有的有效代码：其历史内容已在 `main` 的 `2e79744` 基点合入；旧分支文件树与后续发布文件有差异，直接合并会覆盖 `main` 的发布修改，因此没有合并该分支。
- 本交接文档是本次新建的文档变更，尚未提交；创建它之前的 `main` 与 `origin/main` 一致。

Pi 接手时先运行：

```bash
git status --short --branch
git branch -avv
git log -1 --oneline --decorate
```

## 产品与实现概况

- 极简 macOS 菜单栏应用，显示 DeepSeek API 模型价格的峰/谷状态、距真实下一次切换的时长与提醒入口；不做账号、API Key、用量/费用分析、模型自动切换、任务管理或 Agent 集成。
- 价格状态统一按 `Asia/Shanghai`。周末（包含调休上班周末）及法定节假日全天为谷。规则覆盖不足时显示待更新，不猜状态、不发无法确认的价格提醒。
- 产品范围和验收以 `docs/product/requirements.md` 为准；Mac 视觉以 `docs/product/design-macos.md` 和 `docs/design/brand-refresh-2026-10-27/` 为准。iOS 仍是只读验证外壳，没有已确认的产品交互设计。
- Swift 6 分层：`GudengCore`（纯规则逻辑）→ `GudengRuntime`（共享会话和业务流程）→ `GudengKit`（SwiftUI、系统适配）→ `Apps/Mac` / `Apps/iOS`。相关决策见 ADR-0010、0011、0013。
- 最低目标 macOS 13.0、iOS 17.0。macOS 13.7.8 Intel（pro）有基础原生运行证据；macOS 13 arm64 与完整登录项/通知矩阵尚未通过。
- macOS 面板固定 334×322pt；已完成设置紧凑布局、菜单栏基线对齐、峰谷表达性视觉和受偏好/Reduce Motion 控制的反馈动效。用户此前已手动确认当时的 UI 视觉验收通过。
- 当前 Bundle ID：macOS `com.easyindie.easyapiclock`，iOS `com.easyindie.easyapiclock.ios`。v0.1.1 更换了应用身份，旧版偏好、通知授权和沙盒数据不会自动迁移。

## 发布与服务状态

- v0.1.1 GitHub Release 已使用 EasyIndie 组织的 EasyRelease reusable workflow 完成 Developer ID 签名、Apple 公证和 staple。发布入口是 `.github/workflows/publish-release.yml`，仅在 `main` 手动触发并确认；不要把本地 `make package-mac` 的 ad-hoc 包称为可分发的公证包。
- 共享发布逻辑来自固定提交 `1b2ccaec5bec0a557e86e11e28c9459a0b7c5633` 的 `EasyIndie/EasyRelease`；使用组织共享 secrets，不要读取、打印或写入凭据。
- GitHub Pages 产品页源在 `site/`，工作流在 `.github/workflows/pages.yml`，预期 URL 为 `https://easyindie.github.io/EasyAPIClock/`。上线状态应以 Pages workflow / 仓库设置证据为准。
- 规则更新源是仓库 `rules` 分支。客户端规则更新与维护者官方价格观察是两条不同链路；规则仅为声明式 JSON，SHA-256 是完整性检查，不是发布者数字签名。
- ADR-0012 的官方价格观察 workflow 已存在于当前 `main` 历史。`TASKS.md` / `docs/ops/functional-acceptance.md` 仍记有“定时任务尚未合并默认分支/线上未生效”的旧状态；接手后先核对 GitHub Actions 中是否有真实 `schedule` run 及权限结果，再更新状态，不能只因 workflow 文件在 `main` 就宣称已运行。
- 官方价格候选必须由维护者确认官方依据、摘要和生效时间；观察时间不能替代生效时间。不自动改 `Rules/`、合并 PR、提高权限或发布 Release。操作细节见 `docs/ops/official-pricing-automation.md`。

## 验收现状与优先待办

功能逐项记录在 `docs/ops/functional-acceptance.md`，平台证据在 `docs/ops/platform-validation.md`，总任务在 `TASKS.md`。不要把自动化测试或系统日志等同为用户实际收到提醒。

优先继续：

1. **核心提醒端到端验证**：正式切换提醒的可见横幅、实际声音、中等一次、强提醒有界重复和停止操作仍未完整通过；补 Focus/勿扰、静音、睡眠/唤醒、退出行为及 macOS 14/15 矩阵。2026-10-27 的预览排查发现勿扰模式抑制了横幅/声音；用户关闭后预览可收到。不要把预览投递记录当成正式提醒验收。
2. **macOS 13 兼容矩阵**：补 macOS 13 arm64；pro 上的 Intel 基础启动已验，登录后启动与完整通知行为仍待测。通用二进制编译成功不代表各架构真机通过。
3. **平台偏好与辅助功能**：验证登录项注销重登录后的实际启动、系统“减少动态效果”路径、VoiceOver/键盘/对比度；之前键盘焦点测试受系统条件限制，不判定通过。
4. **官方价格 CI 运行证据**：先按上节核对 Actions 定时运行，再修订相关过时文档。
5. **其他积压**：年度日历只在官方安排发布并核实后更新；Ed25519 签名、英文界面、iOS 设计、App Store 可行性均是独立后续工作，不要顺手扩大本轮范围。

## 操作与安全边界

- 最低提交门槛是 `make check`；不要为通过检查放宽规则校验，也不要把生成的 `.xcodeproj`、`Build/Generated/`、`.build/`、无依赖时的 `Package.resolved` 提交。
- 修改提醒前读 `docs/architecture/reminders.md`；系统通知、登录项、Focus、睡眠等行为必须如实记录平台、版本、权限、结果和证据路径。
- 本机稳定安装入口是 `/Applications/谷蹬.app`；源码变更不会自动更新此副本。更新安装版前先构建验证、备份旧包、退出对应实例，再从同路径启动。
- 之前用户明确允许用 SSH `pro` 做 macOS 13 真机验收，并允许 AppleScript/System Events 自动展开面板；若继续做 UI 自动化，应仅操作谷蹬相关 UI，保留原系统偏好，测试后恢复临时改动。
- 用户要求先验收并记录问题、集中处理；本次交接只记录已知状态，不把待验收问题伪装为已修复。
- 公开发布、公证、上传规则包等外部副作用必须遵循 `AGENTS.md` 与 `docs/ops/release.md` 的授权约束。当前 release workflow 已被配置，不代表每次改动都获准发布。

## 必读入口

1. `AGENTS.md`
2. `docs/product/overview.md`、`docs/product/requirements.md`、`docs/product/design-macos.md`
3. `docs/architecture/overview.md`、`rules-and-data.md`、`time-and-calendar.md`、`reminders.md`、`testing.md`
4. `TASKS.md`、`docs/ops/functional-acceptance.md`、`docs/ops/platform-validation.md`
5. `docs/adr/` 全部已接受决策，尤其 ADR-0009 至 ADR-0013
6. 发布或价格监测任务分别再读 `docs/ops/release.md`、`docs/ops/official-pricing-automation.md`

## 给 Pi agent 的接手提示词

```text
你将接手 EasyIndie/EasyAPIClock（产品名：谷蹬）。先把当前工作目录当作唯一事实来源：运行 git status、git branch -avv、git log -1；确认当前分支/提交和是否有未提交变更。不要假设旧对话中的分支状态仍然有效。

开始任何代码修改前，完整阅读根目录 AGENTS.md，并严格按其必读顺序读产品、架构、TASKS.md 和已接受 ADR。再读 docs/handoff/pi-agent-handoff-2026-10-28.md、docs/ops/functional-acceptance.md、docs/ops/platform-validation.md，了解当前验收证据和遗留问题。文档之间若有冲突，先核实代码、GitHub Actions 或设备证据，记录冲突后再修订，不要把推测写成结论。

项目当前基线是 main / v0.1.1，交接时提交 a841b2e；仓库迁入 EasyIndie，Bundle ID 为 com.easyindie.easyapiclock（iOS 后缀 .ios）。主分支和 rules 是应保留的分支。旧 codex/macos-13-runtime 已被确认无独有代码并清理，不要恢复它。远端规则分支由 workflow 生成，不要手工编辑。

当前最高优先级是完成核心提醒及 macOS 13 平台验收：真实切换通知的横幅/声音/次数/停止行为、Focus/静音/睡眠唤醒/退出边界，macOS 13 arm64，以及登录项重登录行为。用户此前允许 SSH 到 pro 做 macOS 13 真机验证，也允许 AppleScript/System Events 自动展开谷蹬面板。所有系统设置变更须最小化并恢复；不要通过改权限、通知数据库、BTM 或清理系统状态来强行制造“通过”。正式通知的验收不能用提醒预览或系统日志替代。

另外，ADR-0012 的官方价格观察 workflow 已存在于 main 历史，但任务文档仍说定时任务未上线。先查看 GitHub Actions 是否已有真实 schedule run、是否因权限失败，再依据证据同步 TASKS.md 和验收文档。价格/节假日数据只能依据官方来源，不得猜价格、节假日、生效时刻；候选 PR 必须由维护者确认，不自动合并。

每次只推进一组明确的验收项；先保存证据和实际结论，再修复已确认的问题。遵守现有产品边界、模块依赖方向、北京时间和不补发历史规则。逻辑改动先补固定时间 Swift Testing；提交前运行 make check。UI/系统行为记录版本、权限和证据。同步 CHANGELOG 与相关文档，使用 Conventional Commit。未经当前授权不要创建 Release、公证本地包、发布规则或改变 GitHub 权限。先给我一个基于当前证据的短计划，然后继续完成用户已授权的验收工作，不要只列建议后停下。
```
