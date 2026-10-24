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
  - 现状：ad-hoc 包在本机授权为 denied；需 Developer ID 签名后复测允许路径。
  - 验收：每个场景有“通过/失败/受限”与证据；失败项有 issue 或产品降级说明。
- [ ] **签名与公证**：Developer ID 证书已存在（`Developer ID Application: Zhizhou Wang (2N62934Y28)`）；当前 login keychain 未解锁，`codesign` 返回 `errSecInternalComponent`；公证 profile 未配置。
  - 下一步：解锁 login keychain → `DEVELOPER_ID_APPLICATION=... DEVELOPER_TEAM=2N62934Y28 make package-mac` → 配置 `notarytool` profile → `make package-mac-notarized`。
  - 验收：`codesign --verify` 通过；`spctl -a -vv` 通过；Gatekeeper 无警告；步骤写入 `docs/ops/release.md`。
- [ ] **应用图标与截图**：提供 1024pt 图标、菜单栏图形资产、README 截图；图标不暗示自动切换模型。
  - 验收：Asset Catalog 完整；浅色/深色菜单栏可辨；README 使用真实截图。
- [x] **更新源部署**：`Rules` workflow 校验后发布到仓库 `rules` 分支；`LiangWenRuleSourceBaseURL` 默认指向该 raw 地址。
  - 验收：raw manifest 与三个文件 checksum 一致；一次成功更新与一次坏包回退待真机记录。
- [x] **Release 打包骨架**：`make package-mac` 生成通用二进制 zip/dmg；CI 增加 Release 通用构建；手动 Release workflow 只产出 artifact。
- [x] **A15 测试工具**：`make serve-test-rules` 生成近期切换规则包并本地提供，支持提前提醒场景。

## P1 · 首版应有

- [ ] **2027 节假日日历**：官方安排发布后新增 `calendar-2027.json`，更新 coverage 与 manifest；补测试。
- [ ] **规则包数字签名**：Ed25519（CryptoKit）签名 + 公钥内置，解决 SHA-256 无法防篡改源的问题；写 ADR 并更新 runbook。
- [ ] **可访问性审计**：VoiceOver 朗读、对比度、动态字体、键盘操作；记录未覆盖项。
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
