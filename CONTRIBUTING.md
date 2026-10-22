# 参与贡献

感谢你愿意改进梁文钟。请先阅读 [`AGENTS.md`](AGENTS.md) 与 [`docs/product/requirements.md`](docs/product/requirements.md)，再开始改动。

## 环境

- macOS 14+、Xcode 16+（Swift 6）
- XcodeGen 2.46.0：由 `make bootstrap` 自动安装并校验 SHA-256，不需要 `brew install`
- 不需要账号、密钥或后端服务

```bash
make bootstrap     # 安装固定版本 XcodeGen + 生成工程 + 环境检查
make doctor
make test
make validate-rules
make run-mac
```

不要用 `brew upgrade xcodegen` 改变生成器版本；升级流程见 [`docs/adr/0002-xcodegen.md`](docs/adr/0002-xcodegen.md)。

## 工作流

1. 先在 issue 中描述问题、范围与验收方式；超出首版范围的需求先讨论。
2. 从 `main` 建分支，保持提交聚焦。
3. 先补测试，再实现；失败路径同样要有测试。
4. 运行 `make check`。
5. 提交 PR，填写模板中的验证结果与平台限制。

提交信息使用 Conventional Commits：

```
feat: add early reminder option
fix: keep valley state across holiday midnight
rules: refresh 2026 holiday calendar
docs: clarify notification limitations
test: cover expired calendar coverage
```

## 规则数据变更

价格与节假日属于高风险管理数据。任何改动必须：

- 附官方来源链接与核对日期；
- 说明覆盖范围与例外；
- 更新 `Rules/manifest.json` 并执行 `make rules-manifest`；
- 执行 `make validate-rules`；
- 同步更新 `docs/product/requirements.md` 的快照表与 `CHANGELOG.md`；
- 不用「是否上班」替代官方峰谷定义。

详步骤见 [`docs/ops/rule-update-runbook.md`](docs/ops/rule-update-runbook.md)。

## 代码风格

- Swift 6 语言模式，严格并发检查；核心逻辑保持纯函数、可确定性测试。
- 使用 Swift Testing（`import Testing`），不新增 XCTest。
- 格式化与 lint：`make format` / `make lint`（`swift-format`）。
- 不引入第三方运行时依赖；确需引入时先写 ADR。
- 生成物（`LiangWenClock.xcodeproj`、`Build/Generated/`、`.build/`）不提交。

## 使用 AI 代理

AI 代理必须遵守 [`AGENTS.md`](AGENTS.md)。如果代理生成的改动与产品范围冲突，以文字需求为准，不要接受“顺手增加”的功能。使用 AI 的 PR 请在描述中说明哪些部分由代理生成、你如何验证。

## 文档

用户可见行为、规则字段、通知语义、发布流程发生变化时，同步更新对应文档。文档索引见 [`docs/README.md`](docs/README.md)。

## 行为准则

参与本项目即表示同意遵守 [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)。安全问题请走私密渠道，见 [`SECURITY.md`](SECURITY.md)。
