#!/usr/bin/env python3
"""Maintenance-only official price observation and explicitly verified candidate preparation."""
import argparse
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urlsplit
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

SOURCE = "https://api-docs.deepseek.com/zh-cn/quick_start/pricing/"
UPDATES_SOURCE = "https://api-docs.deepseek.com/zh-cn/updates"
SITEMAP_SOURCE = "https://api-docs.deepseek.com/sitemap.xml"
HOST = "api-docs.deepseek.com"
PRICE_WORDS = ("价格", "计费", "峰谷", "生效", "调价", "降价", "优惠")
TIERS = {"百万tokens输入（缓存命中）": "inputCacheHit", "百万tokens输入（缓存未命中）": "inputCacheMiss", "百万tokens输出": "output"}
STATES = {"空闲时段": "valley", "高峰时段": "peak"}
ROOT = Path(__file__).resolve().parents[1]


def normalized(text):
    return re.sub(r"\s+", "", text).replace("\u200b", "")


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def money(text):
    if not re.fullmatch(r"[0-9]{1,8}(?:\.[0-9]{1,8})?元", text):
        raise ValueError("价格格式或人民币单位无法确认")
    value = Decimal(text[:-1])
    if not 0 < value <= 1000000:
        raise ValueError("价格不在允许的正数范围")
    return format(value.normalize(), "f")


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tables, self.paragraphs = [], []
        self.table = self.row = self.cell = self.paragraph = None
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("script", "style"):
            self.skip += 1
        if tag == "table":
            if self.table is not None:
                raise ValueError("不支持嵌套价格表")
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            r, c = int(attrs.get("rowspan", 1)), int(attrs.get("colspan", 1))
            if not (1 <= r <= 20 and 1 <= c <= 8):
                raise ValueError("表格跨度异常")
            self.cell = [[], r, c]
        if tag == "p":
            self.paragraph = []

    def handle_data(self, data):
        if self.skip:
            return
        if self.cell is not None:
            self.cell[0].append(data)
        if self.paragraph is not None:
            self.paragraph.append(data)

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip = max(0, self.skip - 1)
        if tag in ("td", "th") and self.cell is not None:
            self.row.append((normalized("".join(self.cell[0])), self.cell[1], self.cell[2]))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == "table" and self.table is not None:
            self.tables.append(self.table)
            self.table = None
        if tag == "p" and self.paragraph is not None:
            self.paragraphs.append(normalized("".join(self.paragraph)))
            self.paragraph = None


def grid(table):
    values = {}
    for y, row in enumerate(table):
        x = 0
        for text, rows, columns in row:
            while (y, x) in values:
                x += 1
            for dy in range(rows):
                for dx in range(columns):
                    if (y + dy, x + dx) in values:
                        raise ValueError("价格表格存在重叠单元格")
                    values[y + dy, x + dx] = text
            x += columns
    width = max((x for _, x in values), default=-1) + 1
    return [[values.get((y, x), "") for x in range(width)] for y in range(len(table))]


def extract(html):
    page = Page()
    page.feed(html)
    tables = [g for table in page.tables if (g := grid(table)) and g[0][0] == "模型"]
    if len(tables) != 1 or len(tables[0][0]) != 5:
        raise ValueError("模型价格表结构无法唯一确认")
    table = tables[0]
    models = [re.sub(r"\(\d+\)", "", cell) for cell in table[0][3:]]
    if len(set(models)) != 2 or any(not re.fullmatch(r"deepseek-[a-z0-9-]+", m) for m in models):
        raise ValueError("模型标识无法确认")
    prices = {model: {} for model in models}
    seen = set()
    for row in table[1:]:
        if re.sub(r"\(\d+\)", "", row[0]) != "价格":
            continue
        if row[1].lower() not in TIERS or row[2] not in STATES:
            raise ValueError("计费项或峰谷状态发生未知变化")
        tier, state = TIERS[row[1].lower()], STATES[row[2]]
        if (tier, state) in seen:
            raise ValueError("价格行重复")
        seen.add((tier, state))
        for model, value in zip(models, row[3:]):
            prices[model].setdefault(tier, {})[state] = money(value)
    if len(seen) != 6:
        raise ValueError("价格表不完整")
    policies = [p for p in page.paragraphs if "北京时间" in p and "时段" in p]
    if len(policies) != 1:
        raise ValueError("峰谷语义段落无法唯一确认")
    return {"prices": prices, "policySHA256": hashlib.sha256(policies[0].encode()).hexdigest()}


def rule_semantics(pricing):
    return {key: pricing.get(key) for key in ("timeZone", "currency", "unit", "weeklyPeakWindows")}


def expected_prices(pricing):
    return {m["id"]: {t["id"]: {s: format(Decimal(t[s]).normalize(), "f") for s in ("valley", "peak")} for t in m["tiers"]} for m in pricing["models"]}


def allowed_url(url):
    p = urlsplit(url)
    return p.scheme == "https" and p.hostname == HOST and p.port in (None, 443) and not p.username and not p.password


class OfficialRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not allowed_url(newurl):
            raise ValueError("拒绝跳转到非官方HTTPS来源")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_page(url, cache=None, content_types=("text/html", "application/xhtml+xml")):
    """Fetch an allow-listed official URL, using ETag/Last-Modified when cached."""
    if not allowed_url(url):
        raise ValueError("只允许读取官方HTTPS来源")
    headers = {"User-Agent": "GudengOfficialPricingMonitor/1.1"}
    cache = cache or {}
    if cache.get("etag"):
        headers["If-None-Match"] = cache["etag"]
    elif cache.get("lastModified"):
        headers["If-Modified-Since"] = cache["lastModified"]
    req = Request(url, headers=headers)
    try:
        with build_opener(OfficialRedirect()).open(req, timeout=30) as response:
            if not allowed_url(response.url) or response.headers.get_content_type() not in content_types:
                raise ValueError("官方响应地址或内容类型异常")
            data = response.read(2_000_001)
            if len(data) > 2_000_000:
                raise ValueError("官方页面超过允许大小")
            return {
                "notModified": False,
                "body": data.decode("utf-8"),
                "etag": response.headers.get("ETag"),
                "lastModified": response.headers.get("Last-Modified"),
            }
    except HTTPError as error:
        if error.code == 304:
            return {
                "notModified": True,
                "body": "",
                "etag": error.headers.get("ETag") if error.headers else cache.get("etag"),
                "lastModified": error.headers.get("Last-Modified") if error.headers else cache.get("lastModified"),
            }
        raise


def fetch():
    result = fetch_page(SOURCE)
    if result["notModified"]:
        raise ValueError("全新请求不应返回304")
    return result["body"]


def status_from_observation(observation, root=ROOT):
    pricing_bytes = (root / "Rules/pricing.json").read_bytes()
    baseline = json.loads((root / "docs/ops/official-pricing-baseline.json").read_text())
    status = "unchanged"
    if (observation["policySHA256"] != baseline["policySHA256"]
            or digest(rule_semantics(json.loads(pricing_bytes))) != baseline["ruleSemanticsSHA256"]):
        status = "review-required"
    elif observation["prices"] != expected_prices(json.loads(pricing_bytes)):
        status = "prices-changed"
    if status == "prices-changed":
        if observation["prices"].keys() != expected_prices(json.loads(pricing_bytes)).keys():
            status = "review-required"
        elif any(Decimal(t["peak"]) != 2 * Decimal(t["valley"]) for m in observation["prices"].values() for t in m.values()):
            status = "review-required"
    return status


def observe(html, root=ROOT):
    pricing_bytes = (root / "Rules/pricing.json").read_bytes()
    observation = extract(html)
    return {"schemaVersion": 1, "sourceURL": SOURCE, "checkedAt": datetime.now(timezone.utc).isoformat(),
            "status": status_from_observation(observation, root), "observation": observation,
            "digest": digest(observation), "pricingSHA256": hashlib.sha256(pricing_bytes).hexdigest()}


CHINESE_EFFECTIVE_TIME = re.compile(
    r"北京时间\s*(20\d{2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*(\d{1,2})\s*[时点]"
)
ISO_EFFECTIVE_TIME = re.compile(r"\b(20\d{2})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})\b")


def page_texts(html):
    page = Page()
    page.feed(html)
    return [text for text in page.paragraphs if len(text) >= 8]


def effective_times(text):
    found = []
    for match in CHINESE_EFFECTIVE_TIME.finditer(text):
        year, month, day, hour = match.groups()
        found.append(f"北京时间 {int(year):04d}-{int(month):02d}-{int(day):02d} {int(hour):02d}:00+08:00")
    for match in ISO_EFFECTIVE_TIME.finditer(text):
        year, month, day, hour, minute = match.groups()
        found.append(f"北京时间 {year}-{month}-{day} {hour}:{minute}+08:00")
    return list(dict.fromkeys(found))


def price_snippets(texts, limit=8):
    snippets = []
    for text in texts:
        if not any(word in text for word in PRICE_WORDS):
            continue
        snippet = text[:600]
        if snippet not in snippets:
            snippets.append(snippet)
    return snippets[:limit]


def parse_updates(html):
    texts = page_texts(html)
    snippets = price_snippets(texts)
    times = []
    for snippet in snippets:
        for value in effective_times(snippet):
            if value not in times:
                times.append(value)
    return {"sha256": hashlib.sha256("\n".join(texts).encode()).hexdigest(),
            "snippets": snippets, "effectiveTimes": times}


def parse_sitemap(xml):
    urls = re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", xml)
    news = []
    for url in urls:
        if allowed_url(url) and re.search(r"/news/news\d+$", url) and url not in news:
            news.append(url)
    return news


def scan_news(html):
    texts = page_texts(html)
    snippets = price_snippets(texts)
    times = []
    for snippet in snippets:
        for value in effective_times(snippet):
            if value not in times:
                times.append(value)
    return {"snippets": snippets, "effectiveTimes": times}


def collect_context(state):
    context = {
        "updates": {"changed": False, "snippets": [], "effectiveTimes": [], "url": UPDATES_SOURCE},
        "news": [],
        "errors": [],
        "notModified": {},
    }
    try:
        result = fetch_page(UPDATES_SOURCE, state.get("updates"))
        if result["notModified"]:
            context["notModified"]["updates"] = True
            cached = state.get("updatesInfo", {})
            context["updates"].update(cached)
        else:
            info = parse_updates(result["body"])
            previous = state.get("updatesInfo", {})
            context["updates"].update(info)
            # The first observation establishes a baseline; existing historical
            # entries must not look like a fresh policy change.
            context["updates"]["changed"] = bool(previous) and info["snippets"] != previous.get("snippets")
            state["updates"] = {"etag": result["etag"], "lastModified": result["lastModified"]}
            state["updatesInfo"] = info
    except Exception as error:
        context["errors"].append("updates: " + str(error)[:300])

    try:
        first_sitemap = "newsURLs" not in state
        result = fetch_page(SITEMAP_SOURCE, state.get("sitemap"), content_types=("application/xml", "text/xml"))
        if result["notModified"]:
            context["notModified"]["sitemap"] = True
            urls = state.get("newsURLs", [])
        else:
            urls = parse_sitemap(result["body"])
            state["sitemap"] = {"etag": result["etag"], "lastModified": result["lastModified"]}
            state["newsURLs"] = urls
        seen = set(state.get("seenNews", []))
        unseen = [url for url in urls if url not in seen]
        if first_sitemap:
            # Baseline all existing announcements instead of notifying for old releases.
            seen.update(unseen)
            unseen = []
        else:
            unseen = sorted(unseen, key=lambda url: re.search(r"news(\d+)$", url).group(1), reverse=True)[:5]
        for url in unseen:
            try:
                page = fetch_page(url)
                item = scan_news(page["body"])
                context["news"].append({"url": url, **item})
                seen.add(url)
            except Exception as error:
                context["errors"].append(url + ": " + str(error)[:300])
        state["seenNews"] = list(seen)[-100:]
    except Exception as error:
        context["errors"].append("sitemap: " + str(error)[:300])
    return context


def compose_report(price_report, context):
    context_changed = context["updates"]["changed"] or any(item["snippets"] for item in context["news"])
    report = dict(price_report)
    report["context"] = context
    if context_changed and report["status"] == "unchanged":
        report["status"] = "review-required"
        report["reason"] = "官方更新日志或公告包含价格/计费变化"
    report["notificationDigest"] = digest({
        "observation": report.get("observation"),
        "updates": context["updates"],
        "news": context["news"],
    })
    return report


def prepare(report, root, expected_digest, effective_from, evidence):
    if report["status"] != "prices-changed" or report["digest"] != expected_digest or digest(report["observation"]) != expected_digest:
        raise ValueError("只接受维护者明确确认摘要的已知单价变化")
    if not allowed_url(evidence):
        raise ValueError("生效依据必须为官方HTTPS文档链接")
    effective = datetime.fromisoformat(effective_from.replace("Z", "+00:00"))
    if effective.utcoffset() != timedelta(hours=8):
        raise ValueError("生效时间必须显式使用北京时间+08:00")
    pricing_path = root / "Rules/pricing.json"
    if hashlib.sha256(pricing_path.read_bytes()).hexdigest() != report["pricingSHA256"]:
        raise ValueError("仓库单价已变更，必须重新观察")
    baseline = json.loads((root / "docs/ops/official-pricing-baseline.json").read_text())
    observation = report["observation"]
    pricing = json.loads(pricing_path.read_text())
    if (observation["policySHA256"] != baseline["policySHA256"]
            or digest(rule_semantics(pricing)) != baseline["ruleSemanticsSHA256"]
            or observation["prices"].keys() != expected_prices(pricing).keys()):
        raise ValueError("时段语义或模型变化必须人工处理")
    for model in observation["prices"].values():
        if set(model) != set(TIERS.values()):
            raise ValueError("计费项不完整")
        for tier in model.values():
            if set(tier) != {"peak", "valley"} or any(money(v + "元") != v for v in tier.values()) or Decimal(tier["peak"]) != 2 * Decimal(tier["valley"]):
                raise ValueError("候选单价或倍率不符合已确认语义")
    calendar = json.loads((root / "Rules/calendar-2026.json").read_text())
    if not calendar["coverage"]["from"] <= effective.date().isoformat() <= calendar["coverage"]["through"]:
        raise ValueError("生效日超出当前日历覆盖，不自动生成规则")
    now = datetime.now(timezone.utc)
    manifest_path = root / "Rules/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    if now <= datetime.fromisoformat(manifest["publishedAt"].replace("Z", "+00:00")):
        raise ValueError("发布时间必须严格递增")
    version = "official-" + now.strftime("%Y%m%dT%H%M%SZ")
    pricing.update(version=version, effectiveFrom=effective_from)
    pricing["source"]["checkedAt"] = report["checkedAt"]
    pricing.setdefault("notes", []).append("维护者已核实生效依据：" + evidence)
    for model in pricing["models"]:
        for tier in model["tiers"]:
            tier.update(observation["prices"][model["id"]][tier["id"]])
    # Keep the independent hard-coded snapshot and product table synchronized, never relax validation.
    tests_path = root / "Packages/Gudeng/Tests/GudengCoreTests/RuleBundleTests.swift"
    tests = tests_path.read_text()
    values = observation["prices"]
    block = tests[tests.index("    func pricesMatchSnapshot()"):tests.index('    @Test("校验和错误')]
    old_block = block
    for name, model, tier in [("cacheHit", "deepseek-flash", "inputCacheHit"), ("output", "deepseek-v4-pro", "output")]:
        for state in ("valley", "peak"):
            pattern = rf'(\#expect\({name}\.{state}\.value == Decimal\(string: ")[^"]+("\)\))'
            block, count = re.subn(pattern, lambda m: m[1] + values[model][tier][state] + m[2], block)
            if count != 1:
                raise ValueError("快照测试结构变化，必须人工更新")
    tests = tests.replace(old_block, block)
    tests, count = re.subn(r'(\#expect\(bundle.manifest.bundleVersion == ")[^"]+("\))', lambda m: m[1] + version + m[2], tests)
    if count != 1:
        raise ValueError("独立版本快照结构变化，必须人工更新")
    changelog = root / "CHANGELOG.md"
    if "### Changed\n" not in changelog.read_text():
        raise ValueError("Changelog结构变化，必须人工更新")
    docs_path = root / "docs/product/requirements.md"
    docs = docs_path.read_text()
    labels = {"inputCacheHit": "输入（缓存命中）", "inputCacheMiss": "输入（缓存未命中）", "output": "输出"}
    rows = [f"| {m['id']} | {labels[t['id']]} | {t['valley']} | {t['peak']} |" for m in pricing["models"] for t in m["tiers"]]
    docs, count = re.subn(r"(?:\| deepseek-(?:flash|v4-pro) \|[^\n]+\n){6}", "\n".join(rows) + "\n", docs)
    if count != 1:
        raise ValueError("产品快照结构变化，必须人工更新")
    docs, count = re.subn(r"核对日期：\*\*[^\n]+", "核对日期：**" + now.astimezone(timezone(timedelta(hours=8))).date().isoformat() + "**（官方页面复核；生效时间由维护者确认）。", docs, count=1)
    if count != 1:
        raise ValueError("未找到产品核对日期")
    pricing_path.write_text(json.dumps(pricing, ensure_ascii=False, indent=2) + "\n")
    tests_path.write_text(tests)
    docs_path.write_text(docs)
    manifest.update(bundleVersion=version, publishedAt=now.isoformat(), effectiveFrom=effective_from,
                    notes="官方单价候选；语义指纹未变，生效时间由维护者确认。")
    for key, filename in manifest["files"].items():
        manifest["sha256"][key] = hashlib.sha256((root / "Rules" / filename).read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    changelog = root / "CHANGELOG.md"
    changelog.write_text(changelog.read_text().replace("### Changed\n", "### Changed\n\n- 官方单价候选 " + version + "；生效依据：" + evidence + "，需审阅后合并。\n", 1))


def load_state(path):
    try:
        state = json.loads(path.read_text())
    except (FileNotFoundError, ValueError):
        return {}
    return state if state.get("schemaVersion") == 1 else {}


def report_from_cached_observation(state, root=ROOT):
    info = state.get("pricingInfo")
    if not info or "observation" not in info:
        raise ValueError("缺少可复用的价格观察缓存")
    observation = info["observation"]
    return {
        "schemaVersion": 1,
        "sourceURL": SOURCE,
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "status": status_from_observation(observation, root),
        "observation": observation,
        "digest": digest(observation),
        "pricingSHA256": hashlib.sha256((root / "Rules/pricing.json").read_bytes()).hexdigest(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["observe", "prepare"])
    parser.add_argument("--html", type=Path, help="本地测试输入；CI默认读取官方HTTPS页面")
    parser.add_argument("--output", type=Path, default=Path(".build/official-pricing"))
    parser.add_argument("--state", type=Path, help="条件请求缓存；默认 <output>/state.json")
    parser.add_argument("--expected-digest", default="")
    parser.add_argument("--effective-from", default="")
    parser.add_argument("--evidence", default=SOURCE)
    args = parser.parse_args()
    if args.mode == "prepare" and args.html:
        parser.error("prepare必须重新抓取官方HTTPS，不接受本地HTML")
    args.output.mkdir(parents=True, exist_ok=True)
    state_path = args.state or (args.output / "state.json")
    state = load_state(state_path)
    state["schemaVersion"] = 1
    try:
        if args.html:
            report = observe(args.html.read_text())
            report["context"] = {"updates": {"changed": False, "snippets": [], "effectiveTimes": []}, "news": [], "errors": [], "notModified": {}}
            report["notificationDigest"] = digest({"observation": report["observation"], "updates": report["context"]["updates"], "news": []})
        else:
            pricing_result = fetch_page(SOURCE, state.get("pricing"))
            if pricing_result["notModified"]:
                price_report = report_from_cached_observation(state)
                price_report["notModified"] = True
            else:
                price_report = observe(pricing_result["body"])
                state["pricing"] = {"etag": pricing_result["etag"], "lastModified": pricing_result["lastModified"]}
                state["pricingInfo"] = {"observation": price_report["observation"], "digest": price_report["digest"]}
            context = collect_context(state)
            report = compose_report(price_report, context)
            save_state(state_path, state)
    except Exception as error:
        if args.mode == "prepare":
            raise
        report = {"status": "unrecognized", "reason": str(error)[:500], "sourceURL": SOURCE,
                  "checkedAt": datetime.now(timezone.utc).isoformat(), "digest": digest(str(error)[:500]),
                  "notificationDigest": digest(str(error)[:500]),
                  "context": {"updates": {"changed": False, "snippets": [], "effectiveTimes": []}, "news": [], "errors": [str(error)[:300]], "notModified": {}}}
    (args.output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    context = report.get("context") or {}
    extra = []
    updates = context.get("updates") or {}
    if updates.get("snippets"):
        extra.append("## 官方更新日志摘录\n\n" + "\n\n".join("- " + s for s in updates["snippets"]))
    if updates.get("effectiveTimes"):
        extra.append("检测到的生效时间（仍需维护者确认）：\n\n" + "\n".join("- " + t for t in updates["effectiveTimes"]))
    if context.get("news"):
        lines = []
        for item in context["news"]:
            lines.append("- " + item["url"])
            for snippet in item.get("snippets", [])[:3]:
                lines.append("  - " + snippet)
        extra.append("## 新公告\n\n" + "\n".join(lines))
    if context.get("errors"):
        extra.append("## 上下文读取提示\n\n" + "\n".join("- " + e for e in context["errors"]))
    (args.output / "report.md").write_text(
        "# DeepSeek 官方单价观察\n\n状态：" + report["status"] + "\n\n来源：" + SOURCE + "\n\n摘要：`" + report["digest"] + "`\n\n"
        + "生效时间不能由抓取时间推断；时段/结构变化须人工处理。\n\n"
        + ("\n\n".join(extra) + "\n\n" if extra else "")
        + "```json\n" + json.dumps(report, ensure_ascii=False, indent=2) + "\n```\n")
    if args.mode == "prepare":
        prepare(report, ROOT, args.expected_digest, args.effective_from, args.evidence)
    print(json.dumps({"status": report["status"], "digest": report["digest"],
                      "notificationDigest": report.get("notificationDigest", report["digest"])}, ensure_ascii=False))


def save_state(path, state):
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
