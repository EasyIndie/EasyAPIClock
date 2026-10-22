# 安全策略

## 支持范围

当前仅维护最新 `0.1.x` 预发布版本。项目尚未发布正式签名版本。

## 报告漏洞

请 **不要** 通过公开 issue 报告安全问题。请使用 GitHub 的 [私密安全公告](https://docs.github.com/zh/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities)（Security → Report a vulnerability），并提供：

- 受影响的版本或提交
- 复现步骤与影响
- 是否需要特定规则包、系统版本或网络条件
- 你希望的署名方式（可选）

我们会在合理时间内确认收到并给出处理计划。未修复前请不要公开细节。

## 威胁模型

本项目不处理账号、密码、API Key 或用户内容。主要风险面是 **规则数据** 与 **通知调度**：

1. **恶意或损坏的规则包**：应用只执行声明式 JSON，不接受远程代码。规则包在安装前会校验 manifest、文件名、SHA-256、字段语义、时区与覆盖范围；校验失败保留旧版本。
2. **降级或重放**：仅当远端 `publishedAt` 晚于当前版本时才安装；未来 `effectiveFrom` 的包进入 pending 区，到期才启用。
3. **网络中间人**：默认要求 HTTPS（仅 localhost 开发允许 HTTP）。当前不使用证书固定。
4. **供应链**：应用无第三方运行时依赖；XcodeGen 仅用于生成工程，不参与运行时。
5. **隐私**：应用不收集、上传或分析任何使用数据；唯一网络请求是用户主动触发的规则更新（默认未配置更新源）。

## 已知限制

- 规则包只有 SHA-256 完整性校验，**没有数字签名**。信任根是 HTTPS 与仓库/发布账号的控制权。数字签名方案见 [`docs/adr/0004-rule-bundles.md`](docs/adr/0004-rule-bundles.md) 的后续工作。
- 规则更新源的可用性、缓存与域名安全由部署方负责。
- 通知权限、专注模式与静音属于系统行为，应用无法绕过。
- 本地偏好与已安装规则位于应用沙盒容器内，未做加密；其中不含敏感信息。

## 安全相关配置

- macOS 应用启用 App Sandbox 与 `com.apple.security.network.client`。
- ATS 仅额外允许本地网络（`NSAllowsLocalNetworking`），用于 localhost 规则调试；不放开任意 HTTP。
- 不请求 Apple Events、辅助功能、屏幕录制或完全磁盘访问权限。
- 发布前应启用 Hardened Runtime、Developer ID 签名与公证；见 [`docs/ops/release.md`](docs/ops/release.md)。
