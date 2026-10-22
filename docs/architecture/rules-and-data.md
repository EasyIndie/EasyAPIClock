# 规则与数据

规则是 **声明式 JSON**，不是远程代码。应用把「价格」「日期」「提醒策略」分成三个文件，用 `manifest.json` 绑成一套完整规则包。

## 目录

```
Rules/
  manifest.json          清单：文件、校验和、版本、发布/生效时间
  pricing.json           峰期窗口、模型、计费项、来源
  calendar-2026.json     日期覆盖、法定节假日、调休上班日
  reminder-policy.json   默认强度、提前偏移、强提醒参数、声音
```

同一套文件会以 folder reference 原样复制进 macOS/iOS app bundle；运行时从 `Bundle.main/Rules/` 读取。

## manifest.json

```json
{
  "schemaVersion": 1,
  "bundleVersion": "2026.10.23",
  "publishedAt": "2026-10-23T02:00:00+08:00",
  "effectiveFrom": "2026-10-23T00:00:00+08:00",
  "files": {
    "pricing": "pricing.json",
    "calendar": "calendar-2026.json",
    "reminderPolicy": "reminder-policy.json"
  },
  "sha256": {
    "pricing": "…",
    "calendar": "…",
    "reminderPolicy": "…"
  },
  "notes": "维护者备注，可选"
}
```

| 字段 | 约束 |
|---|---|
| `schemaVersion` | 当前只支持 `1` |
| `bundleVersion` | 非空；建议日期式，便于排序与展示 |
| `publishedAt` | 发布时间；更新服务仅在它 **严格晚于** 当前版本时安装 |
| `effectiveFrom` | 生效时间；晚于当前时刻则进入 pending，不提前启用 |
| `files` | 恰好三个文件名；不得包含路径、`..`、隐藏文件或非 `[A-Za-z0-9._-]` 字符 |
| `sha256` | 三个文件的十六进制 SHA-256；大小写不敏感 |

## pricing.json

```json
{
  "schemaVersion": 1,
  "version": "2026.10.23",
  "effectiveFrom": "2026-10-23T00:00:00+08:00",
  "source": {
    "name": "DeepSeek API Docs · 模型 & 价格",
    "url": "https://api-docs.deepseek.com/zh-cn/quick_start/pricing/",
    "checkedAt": "2026-10-23T10:00:00+08:00"
  },
  "timeZone": "Asia/Shanghai",
  "currency": "CNY",
  "unit": "perMillionTokens",
  "weeklyPeakWindows": [
    { "weekday": 1, "start": "09:00", "end": "12:00" },
    { "weekday": 1, "start": "14:00", "end": "18:00" }
  ],
  "models": [
    {
      "id": "deepseek-flash",
      "displayName": "deepseek-flash",
      "tiers": [
        { "id": "inputCacheHit", "label": "输入（缓存命中）", "valley": "0.02", "peak": "0.04" }
      ]
    }
  ],
  "notes": ["Search / Fetch 独立计费，不包含在内。"]
}
```

- `weekday` 使用 ISO 编号：周一 = 1 … 周日 = 7。当前校验只允许 **1–5**；周末固定为谷。
- `start` / `end` 是左闭右开区间；`"24:00"` 只能作为结束时间。
- 金额使用 **字符串**，避免二进制浮点改变发布价格；解码也接受 JSON 数字（手工 fixture 用）。
- `models` 至少一项；`tiers` 至少一项；至少一个 `valley > 0` 才能推导倍率。
- `timeZone` 必须为 `Asia/Shanghai`。

## calendar-2026.json

```json
{
  "schemaVersion": 1,
  "version": "2026.1",
  "timeZone": "Asia/Shanghai",
  "source": {
    "name": "国务院办公厅关于2026年部分节假日安排的通知（国办发明电〔2025〕7号）",
    "url": "https://www.gov.cn/zhengce/content/202511/content_7047090.htm",
    "checkedAt": "2026-10-23T10:00:00+08:00"
  },
  "coverage": { "from": "2026-01-01", "through": "2026-12-31" },
  "holidays": [
    { "name": "国庆节", "from": "2026-10-01", "through": "2026-10-07" }
  ],
  "makeupWorkdays": ["2026-10-10"],
  "notes": ["调休上班的周末仍视为谷期。"]
}
```

- `coverage` 含首尾。超出范围的 **工作日** 无法确认；周末仍可确认为谷。
- `holidays` 必须落在 coverage 内、互不重叠、单项不超过 62 天。
- `makeupWorkdays` 仅作记录。DeepSeek 官方文字把「周末」整体定义为谷，因此补班周末 **不改为峰**；这是有意的产品决策，见 [ADR-0003](../adr/0003-holiday-calendar.md)。
- 每年新增一个日历文件（例如 `calendar-2027.json`），并更新 manifest 的 `files.calendar` 与 `coverage`。不要删除旧年份文件直到确定不再需要。

## reminder-policy.json

```json
{
  "schemaVersion": 1,
  "version": "2026.1",
  "defaultIntensity": "medium",
  "advanceOptionsSeconds": [300],
  "strongRepeatIntervalSeconds": 30,
  "strongMaxRepeats": 10,
  "soundEnabled": true,
  "notes": ["强提醒受系统通知权限、专注模式与静音影响。"]
}
```

- `advanceOptionsSeconds`：升序、去重、每项 60–7200 秒；首版只取第一项作为提前提醒偏移。
- `strongRepeatIntervalSeconds`：10–600 秒。
- `strongMaxRepeats`：1–60 次，且总时长不得超过 30 分钟。
- `soundEnabled`：中等与强提醒是否使用系统默认声音。

## 校验清单

`RuleValidator` 与 `RuleBundleLoader` 会拒绝：

- 不支持的 `schemaVersion`；空版本号。
- 时区不是 `Asia/Shanghai`，或价格/日历时区不一致。
- 峰期窗口 `weekday` 不在 1–5、`start >= end`、重叠、开始时间为 24:00。
- 模型/计费项为空、id 重复、单价为负、全部谷期单价为 0。
- 覆盖范围颠倒、早于 2000 年。
- 节假日为空名、起止颠倒、超出覆盖、相互重叠、超过 62 天。
- 调休上班日重复或超出覆盖。
- 提前偏移越界/重复/未升序；强提醒参数越界或总时长超过 30 分钟。
- 缺少文件、包含未声明文件、文件名不安全、SHA-256 不匹配、JSON 解析失败。

错误会聚合成 `RuleValidationError`，不会部分安装。

## 生命周期

```
内置 Rules/（app bundle）
        │ 仅当没有有效已安装版本
        ▼
Application Support/LiangWen/Rules/active/     ← 已安装、当前有效
Application Support/LiangWen/Rules/pending/    ← 已校验、尚未到 effectiveFrom
```

- `RuleRepository.active(at:)`：
  1. 若 pending 到期，先提升为 active；
  2. 尝试加载 active；成功则使用；
  3. 失败则加载内置；记录 `installedError` 供设置展示；
  4. 内置也失败属于打包缺陷，触发 `preconditionFailure`（CI 会拦截）。
- `install`：
  1. 在 `staging-<UUID>/` 写入 manifest 与三个文件；
  2. 用完整 loader 复验 staging；
  3. 删除旧目标目录并移入 staging；
  4. 安装 active 时清掉 pending。
- 这是 **暂存后替换**，不是数据库级事务。删除与移动之间有一个极短窗口；崩溃时最多回退到内置规则，不会使用半套数据。

## 远程更新流程

```
GET <base>/manifest.json
  ├─ 解析失败 / schema 不支持 ──> 失败，保留旧规则
  ├─ publishedAt <= 当前 ──────> 无更新
  └─ 更新
       ├─ 对每个 files.* 检查安全文件名
       ├─ GET <base>/<file>
       ├─ SHA-256 + 语义校验（RuleBundleLoader）
       ├─ effectiveFrom <= now ? active : pending
       └─ 重新计算并替换提醒计划
```

- 只允许 HTTPS；仅 `localhost` / `127.0.0.1` 允许 HTTP 开发。
- `URLSession` 使用 `reloadIgnoringLocalCacheData` 并发送 `Cache-Control: no-cache`。
- 无数字签名。SHA-256 只能防止传输损坏/意外编辑，不能防止控制更新源的人发布恶意规则。见 [ADR-0004](../adr/0004-rule-bundles.md)。
- 不跟随任何远程脚本；JSON 只被解码为有限结构。

## 失败模式

| 情况 | 结果 |
|---|---|
| 更新源未配置 | 使用内置/已安装规则；设置显示「未配置更新源」 |
| manifest 404/超时/坏 JSON | 保留旧规则；显示失败原因 |
| 校验和不匹配 | 整包拒绝；保留旧规则 |
| 文件名含路径 | 整包拒绝，不发起文件下载 |
| 未来 `effectiveFrom` | 安装到 pending；设置显示待启用版本 |
| 已安装规则损坏 | 回退内置；设置显示错误 |
| 日期覆盖过期 | 状态未知/切换未确认；暂停价格提醒 |
| 规则倍率不一致 | 不显示统一倍率，只显示峰/谷 |

## 维护与回滚

更新流程见 [`../ops/rule-update-runbook.md`](../ops/rule-update-runbook.md)。

本地回滚：

```bash
# 沙盒应用
rm -rf ~/Library/Containers/app.liangwen.mac/Data/Library/Application\ Support/LiangWen/Rules/active
# 非沙盒开发构建
rm -rf ~/Library/Application\ Support/LiangWen/Rules/active
```

删除后应用会回退到内置规则（可能是旧版本）。远程回滚的正确方式是发布一个 `publishedAt` 更新、内容修正的规则包，而不是让旧包“降级”。

## 托管建议

- 静态 HTTPS 目录，`manifest.json` 与三个文件同源同目录。
- 推荐把 `Rules/` 作为发布产物上传到带版本标签的静态路径（例如 GitHub Release 资产或 `raw.githubusercontent.com/<owner>/<repo>/rules-2026.10.23/`）。
- `manifest.json` 用短缓存或 `no-cache`；文件名带版本号时其余文件可长缓存。
- 发布前在测试设备上走一次「成功更新 + 坏包回退 + 未来生效」三条路径。
- 上线后保留上一版文件，避免客户端请求到半更新目录；规则包应整目录发布。
