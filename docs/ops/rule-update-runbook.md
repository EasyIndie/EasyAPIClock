# 规则更新操作手册

规则数据会影响所有用户。按本手册执行，不要凭记忆改数字。

## 0. 原则

- 只使用 **官方来源**：DeepSeek 价格页、国务院/中国政府网节假日通知。
- 价格、日历、提醒策略可以单独修改，但必须作为 **一个完整规则包** 发布。
- 没有来源就不改；无法确认就保持「规则待更新」。
- 不为了“看起来完整”而延长 coverage 或编造假期。
- 更新不能改变用户本地提醒强度。

## 1. 确认要改什么

| 变更 | 文件 |
|---|---|
| 单价、峰谷时段、模型 | `Rules/pricing.json` |
| 法定节假日、调休、覆盖范围 | `Rules/calendar-2026.json`（未来可改名） |
| 默认强度、提前偏移、强提醒参数、声音 | `Rules/reminder-policy.json` |
| 文件清单、版本、校验和、生效时间 | `Rules/manifest.json` |

## 2. 核对官方来源

价格：

1. 打开 <https://api-docs.deepseek.com/zh-cn/quick_start/pricing/>。
2. 记录核对日期（北京时间）与页面原文。
3. 确认模型名、计费项、单位、峰谷时段与“谷期为峰期一半”的描述。
4. 注意 Search / Fetch 是独立计费，不进入模型倍率。

节假日：

1. 搜索「国务院办公厅关于20XX年部分节假日安排的通知」。
2. 优先 `gov.cn` 原文，记录文号、发布日期、URL。
3. 抄录放假日期范围与调休上班日。
4. 记住：调休上班的周末仍按官方文字视为谷，仅记录到 `makeupWorkdays`。

如果官方页面结构与描述变化（例如不再统一半价），先更新需求文档与代码，再改数据。

## 3. 选择版本与时间

- `bundleVersion`：建议 `YYYY.MM.DD` 或 `YYYY.MM.DD.N`；不要复用。
- `publishedAt`：必须 **严格晚于** 客户端当前版本，否则更新不会安装。
- `effectiveFrom`：规则真正开始适用的时刻。
  - 立即生效：设为当前或稍早。
  - 未来生效：设为未来时刻；客户端会放入 pending，到期启用。
- 价格/日历/策略各自的 `version` 可以不同，但要与内容一致。
- `source.checkedAt` 记录你核对官方的时刻。

## 4. 修改文件

只改必要的 JSON。注意：

- 金额用字符串（`"0.02"`），保持精确小数。
- 时间用 `HH:mm`，窗口左闭右开。
- `weekday` 为 ISO 编号，只允许 1–5。
- 节假日范围不得重叠、不得超出 coverage、单项不超过 62 天。
- coverage 含首尾；新年度需扩展 `through` 并加入该年度假期。
- 不删除仍被用户时钟需要的年份数据；引擎会从当前时刻向后搜索。

### 跨年扩展

当 2027 年安排公布后：

1. 把 2027 年放假范围加入日历文件。
2. 将 `coverage.through` 改为 `2027-12-31`（`from` 可保持 2026-01-01）。
3. 建议把文件重命名为 `calendar-cn.json`，并同步 `manifest.files.calendar`；旧文件名不再声明。
4. 增加跨年测试（2026-12-31 晚间 → 2027 第一个工作日）。
5. 更新产品文档中的覆盖范围描述。

## 5. 重算 manifest

```bash
make rules-manifest
# 或指定版本/时间：
swift run --package-path Packages/Gudeng gudeng-rules manifest Rules \
  --bundle-version 2026.11.01 \
  --published-at 2026-10-31T18:00:00+08:00 \
  --effective-from 2026-11-01T00:00:00+08:00
```

工具会重算三个文件的 SHA-256 并写回 `Rules/manifest.json`。手动修改校验和不可接受。

## 6. 校验与测试

```bash
make validate-rules
make test
make check
```

- `validate-rules` 会输出包版本、覆盖范围、模型数量与倍率关系。
- 若价格变化，更新 `RuleBundleTests.pricesMatchSnapshot` 与 `docs/product/requirements.md` 的快照表。
- 若提醒策略变化，检查 `ReminderPlannerTests` 与 `ReminderCopyTests`。
- CI 会重新运行 `manifest` 并检查 `git diff`；忘记重算会被拦截。

## 7. 本地端到端演练（建议每次发布前）

用本地静态服务器模拟更新源：

```bash
# 1. 复制一份规则，避免污染仓库
cp -R Rules /tmp/lw-rules-test

# 2. 修改 /tmp/lw-rules-test 中的内容并把 publishedAt 调晚
#    然后重算该目录的 manifest
swift run --package-path Packages/Gudeng gudeng-rules manifest /tmp/lw-rules-test

# 3. 启动本地源（仅 localhost；macOS Info.plist 已开启 NSAllowsLocalNetworking）
python3 -m http.server 8000 --directory /tmp/lw-rules-test

# 4. 用环境变量启动应用（覆盖 Info.plist）
GUDENG_RULE_SOURCE=http://localhost:8000 \
  .build/DerivedData/Build/Products/Debug/GudengMac.app/Contents/MacOS/GudengMac
```

在应用中打开「设置 → 检查规则更新」，验证：

- 成功更新并显示新的 bundleVersion；
- 设置中的规则来源/版本/覆盖更新；
- 未来 `effectiveFrom` 显示为待启用，当前状态不变；
- 篡改文件后显示失败，旧规则仍可用；
- 停止服务器后显示失败，不崩溃、不清空本地规则。

> 不要提交测试用的临时规则或修改过的窗口时间。

## 8. 发布规则包（自动化）

正常流程不需要手动上传：

1. 在 PR 中修改 `Rules/`，递增 `bundleVersion` 与 `publishedAt`（未来生效可设 `effectiveFrom`）。
2. 运行 `make rules-manifest`、`make validate-rules`、`make test`。
3. 推送 PR；`Rules` workflow 会校验规则并跑测试。
4. 合并到 `main`；`Rules` workflow 的 `publish` job 会：
   - 再次校验；
   - 要求 `publishedAt` 严格晚于 `rules` 分支当前值；
   - 把 `Rules/` 快照强制推送到 `rules` 分支。
5. 验证：

```bash
gh run list --workflow Rules --limit 3
curl -fsSL https://raw.githubusercontent.com/EasyIndie/EasyAPIClock/rules/manifest.json | head
```

6. 在真实设备上执行一次「检查更新」。raw CDN 可能缓存数分钟；如果仍是旧版本，稍后重试，不要通过改客户端来“强制刷新”。

维护者本地命令（通常不需要）：

```bash
make rules-publish-dry-run   # 校验 + 检查 publishedAt，不推送
make rules-publish           # 校验 + 推送到 rules 分支
```

客户端的 base URL 来自 `project.yml` 的 `GudengRuleSourceBaseURL`（开发时可用 `GUDENG_RULE_SOURCE` 覆盖）。fork 需要同时修改 URL 与发布远端。

**不要直接编辑 `rules` 分支。** 它是生成物，下一次发布会覆盖手工改动。

## 9. PR 与记录

- 使用 `.github/ISSUE_TEMPLATE/rule_update.yml` 先记录来源与核对日期。
- PR 描述包含：来源 URL、核对日期、旧值 → 新值、覆盖范围、验证结果、未覆盖风险。
- 更新 `CHANGELOG.md`（用户可见变化）与相关文档。
- 不把“更新规则”与代码重构混在一个 PR。
- 合并后确认 `Rules` workflow 的 `publish` job 成功；失败时不要绕过，先修正 `publishedAt` 或规则内容。

## 10. 回滚

**远端**：发布一个 `publishedAt` 更新、内容修正的规则包（走正常 PR → 合并 → Rules workflow）。客户端不会安装更旧的包，因此不能靠“重新上传旧文件”回滚。不要手工改 `rules` 分支。

**本地**：删除 active 目录，应用回退内置规则：

```bash
rm -rf ~/Library/Containers/com.easyindie.easyapiclock/Data/Library/Application\ Support/Gudeng/Rules/active
```

**紧急**：如果错误包已经发布，尽快准备一个 `publishedAt` 更新的修正包；不要在 `rules` 分支上手工删除文件，下一次发布会覆盖，且无法保证客户端看到一致状态。

## 11. 常见错误

| 现象 | 原因 |
|---|---|
| 应用显示「已是最新」但数据没变 | `publishedAt` 没有晚于当前 |
| 更新成功但当前状态没变 | `effectiveFrom` 在未来，进入 pending |
| 更新失败「校验失败」 | 改了 JSON 但没重算 manifest |
| 更新失败「文件名不安全」 | 文件名含路径或非法字符 |
| 覆盖过期 | 没有扩展 `coverage.through` 或没有加入新年度假期 |
| 周末被算成峰 | 错误地把调休上班日当成工作日；应保持周末为谷 |
| 用户强度被重置 | 不应发生；检查是否误写了 UserDefaults 或在更新流程中重建偏好 |
| Rules workflow 发布失败「publishedAt 必须晚于」 | 合并前忘记递增 `publishedAt`，或 `rules` 分支已有更新版本 |
| 合并后客户端看不到新规则 | Rules workflow 未完成 / 失败，或 raw CDN 仍在缓存；先看 workflow 与 raw URL |
| `rules` 分支出现手工改动 | 不要手改；运行 `make rules-publish` 或重新触发 workflow 覆盖 |
