# CI 与分支保护

## 工作流结构

`.github/workflows/ci.yml` 在 pull request、`main` push 和手动触发时运行：

1. **Classify changes**（ubuntu）：比较 base/head，判断是否只有文档变更。
2. **Rules + tests + lint**（macOS）与 **Build macOS + iOS**（macOS）：仅在代码变更时并行运行。
3. **CI gate**（ubuntu）：始终运行，汇总结果。代码变更必须两项 macOS job 都成功；纯文档变更允许跳过 macOS job。

分支保护的必需检查是 **`CI gate`**。`Rules + tests + lint` 与 `Build macOS + iOS` 仍会显示在 PR 上，但不再单独设为必需，避免文档 PR 因 job 被跳过而卡住。

## 什么算文档变更

只有以下路径会走快速路径：

- `docs/**`
- `site/**`
- `LICENSE`
- 任意 `*.md`
- `.github/ISSUE_TEMPLATE/**`

其他任何改动（Swift、`Rules/`、`Scripts/`、workflow、`project.yml` 等）都会触发完整 macOS 测试与构建。无法取得 base 或 diff 失败时默认跑完整 CI，不会误判为文档。

## 仍然必须完整检查的场景

- 代码 PR：`CI gate` 强制要求两个 macOS job 成功。
- 发布：`Notarize preview`、`Publish macOS Release` 和本地 `make check` 仍执行完整规则校验、测试、lint 与双端构建。
- 文档 PR 只跳过 CI 中的 macOS job，不改变本地 `make check` 的提交前要求。

## 维护提示

- 修改必需检查时，同步更新 GitHub 分支保护和本文档；不要只改 workflow 名称。
- 修改路径分类规则时，先确认 `Scripts/`、`Rules/`、`.github/workflows/` 等仍被当作代码。
- 若 PR 上的 `CI gate` 一直等待，检查它是否运行以及 `Classify changes` 是否成功；必要时用 `workflow_dispatch` 手动跑完整 CI。

## 实测记录

- 2026-11-04：纯文档 PR 改动本文件时，只运行 `Classify changes` 与 `CI gate`，macOS 测试/构建为 skipped；`CI gate` 成功，分支保护允许合并。
