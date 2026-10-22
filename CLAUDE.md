# CLAUDE.md

本仓库的统一代理契约在 [`AGENTS.md`](AGENTS.md)。Claude Code 请先完整阅读该文件，再按其中「必读顺序」加载产品与架构文档。

关键提醒：

- 所有价格判断按 `Asia/Shanghai`，不得使用设备时区。
- 不编造节假日或价格；缺少数据时降级为「规则待更新」。
- 不扩大范围（无账号、API Key、统计、番茄钟、自动切换模型）。
- 规则数据改动后运行 `make rules-manifest && make validate-rules && make test`。
- 提交前运行 `make check`，不要提交生成的 `.xcodeproj` 或 `Build/Generated/`。
