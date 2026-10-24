# 任务清单

给人类与 AI 代理共用的 backlog。开始任务前先读 `AGENTS.md`。完成一项时提交 PR，并同步 `CHANGELOG.md` 与相关文档。

标记：`P0` 阻塞发布，`P1` 首版应有，`P2` 后续。

## 已完成

- [x] 价格规则、日期覆盖与北京时间引擎
- [x] 下次真实切换、连续谷期合并、覆盖不足降级
- [x] 提醒计划、提前提醒、强提醒有界重复、不补发历史
- [x] 规则包 manifest、SHA-256、原子安装、未来生效、失败回退
- [x] macOS 菜单栏面板、设置、偏好、规则状态
- [x] 2026 价格与节假日内置数据
- [x] 单元测试、规则 CLI、CI、工程脚手架
- [x] 产品/架构/ADR/运维文档与交接包归档

## P0 · 发布前

- [x] **2026-10-24 macOS 27 真机初验**：完成界面、周末状态、设置、规则更新/失败回退、退出、偏好持久化与通知授权拒绝路径；记录见 `docs/ops/platform-validation.md`。
- [ ] **真实设备通知验证**：在 macOS 14/15 与当前系统上记录权限允许、通知投递、Focus、静音、睡眠唤醒、退出应用、强提醒停止的结果。
  - 现状：Developer ID 签名后仍为 denied；在 /Applications 启动也未出现权限弹窗。需在公证/重启或清理系统通知状态后复测允许路径。
  - 验收：每个场景有“通过/失败/受限”与证据；失败项有 issue 或产品降级说明。
- [x] **Developer ID 签名**：`package-mac` 现在先构建未签名产物，再手动 Developer ID 签名并加安全时间戳；生成通用二进制 zip/dmg。
  - 验收：`codesign --verify` 通过；`Authority=Developer ID Application`、`TeamIdentifier=2N62934Y28`、`Timestamp` 存在。
  - 注意：必须从 GUI 会话运行；SSH 会话访问 login keychain 会返回 `errSecInternalComponent`。
- [ ] **公证**：创建 `notarytool` profile（`liangwen-notary`），运行 `make package-mac-notarized`，staple 后用 `spctl -a -vv` 验证。
  - 现状：公证凭据未配置；`spctl` 目前只报 `source=Unnotarized Developer ID`。
- [x] **应用图标**：提供 1024pt 峰谷分色时钟图标，AppIcon 10 个尺寸完整，`make icon` 可重复生成。
  - 验收：Asset Catalog 编译通过；不暗示自动切换模型。
- [x] **README 截图**：已在 macOS 27 通过 GUI 会话截取真实主面板与设置页；截图机器未授权通知，README 已说明。
  - 验收：使用真实截图，不使用设计稿冒充成品。
- [x] **更新源部署**：`Rules` workflow 校验后发布到仓库 `rules` 分支；`LiangWenRuleSourceBaseURL` 默认指向该 raw 地址。
  - 验收：raw manifest 与三个文件 checksum 一致；一次成功更新与一次坏包回退待真机记录。
- [x] **Release 打包骨架**：`make package-mac` 生成通用二进制 zip/dmg；CI 增加 Release 通用构建；手动 Release workflow 只产出 artifact。
- [x] **A15 测试工具**：`make serve-test-rules` 生成近期切换规则包并本地提供，支持提前提醒场景。

## P1 · 首版应有

- [ ] **2027 节假日日历**：官方安排发布后新增 `calendar-2027.json`，更新 coverage 与 manifest；补测试。
- [ ] **规则包数字签名**：Ed25519（CryptoKit）签名 + 公钥内置，解决 SHA-256 无法防篡改源的问题；写 ADR 并更新 runbook。
- [ ] **可访问性审计**：已补充设置按钮/强度选择器/检查更新的显式标签；VoiceOver 朗读、对比度、动态字体、键盘操作仍需真机记录。
- [ ] **多语言**：把 `ClockText` / `ReminderCopy` 迁移到 String Catalog，至少提供英文。
- [ ] **倒计时刷新边界**：验证跨分钟、跨日、系统时间跳变时无重复/漏排通知；补测试或手动记录。
- [ ] **通知点击行为**：评估点击通知打开面板/设置的原生方案；无法实现时在文档中明确。
- [ ] **进程退出语义**：验证退出应用后已排定通知的可达性，并把结论写入产品文档与设置说明。
- [ ] **App Store 可行性**：评估沙盒、通知、更新源是否符合审核要求；不承诺上架。
- [ ] **验证 raw CDN 传播与发布回滚**：记录合并到 `rules` 分支后客户端看到新版本的时延；验证 `publishedAt` 递增、相同包幂等、坏包不发布。
- [ ] **规则源可用性**：为 `rules` 分支/manifest 增加维护者侧监控（仅告警，不自动改数据）。

## P2 · 后续

- [ ] iOS 交互设计与正式实现（需产品确认；当前外壳不代表设计）。
- [ ] 强提醒独立浮层（若平台验证表明通知不足；需设计确认）。
- [ ] 价格页面变更监测脚本（仅用于维护者核对，不进入运行时）。
- [ ] 规则包 CDN 与灰度发布策略。
- [ ] 西班牙语/日语等更多语言（社区驱动）。

## 明确不做

- 账号、API Key、Token 用量、消费分析
- 番茄钟、任务管理、Agent 集成
- 自动切换模型或自动暂停任务
- 硬件配网/设备管理（ESP 仅作为未来语义复用方向）
- 在 UI 中展示完整价格表或复杂日历

## 任务模板

新增任务时请写清：

```
### 目标
### 不在范围
### 验收标准（可测试）
### 涉及文件/模块
### 需要同步的文档
```
