import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("official_pricing", ROOT / "Scripts/official_pricing.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
HTML = (Path(__file__).parent / "fixtures/official-pricing.html").read_text()


class FixedDate(datetime):
    @classmethod
    def now(cls, tz=None):
        return cls(2026, 10, 27, 0, 0, tzinfo=timezone.utc)


class OfficialPricingTests(unittest.TestCase):
    def setUp(self):
        clock = patch.object(m, "datetime", FixedDate)
        clock.start()
        self.addCleanup(clock.stop)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for path in ["Rules", "docs/ops", "docs/product", "Packages/Gudeng/Tests/GudengCoreTests"]:
            (self.root / path).mkdir(parents=True, exist_ok=True)
        for file in (ROOT / "Rules").glob("*.json"):
            shutil.copy(file, self.root / "Rules")
        for file in ["docs/product/requirements.md", "Packages/Gudeng/Tests/GudengCoreTests/RuleBundleTests.swift", "CHANGELOG.md"]:
            shutil.copy(ROOT / file, self.root / file)
        pricing_path = self.root / "Rules/pricing.json"
        pricing = json.loads(pricing_path.read_text())
        fixture_prices = m.extract(HTML)["prices"]
        for model in pricing["models"]:
            for tier in model["tiers"]:
                tier.update(fixture_prices[model["id"]][tier["id"]])
        pricing_path.write_text(json.dumps(pricing))
        manifest_path = self.root / "Rules/manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["publishedAt"] = "2026-10-23T10:00:00+08:00"
        manifest_path.write_text(json.dumps(manifest))
        baseline = {"policySHA256": m.extract(HTML)["policySHA256"], "ruleSemanticsSHA256": m.digest(m.rule_semantics(pricing))}
        (self.root / "docs/ops/official-pricing-baseline.json").write_text(json.dumps(baseline))

    def test_rows_and_scope(self):
        result = m.extract(HTML)
        self.assertEqual(result["prices"], m.expected_prices(json.loads((self.root / "Rules/pricing.json").read_text())))
        self.assertEqual(m.observe(HTML, self.root)["status"], "unchanged")
        self.assertEqual(m.observe(HTML.replace("<td>5元</td>", "<td>99元</td>"), self.root)["status"], "unchanged")

    def test_formatting_is_not_a_price_change(self):
        self.assertEqual(m.extract(HTML), m.extract(HTML.replace("9.0元", "9.00元").replace("北京时间", "北京 时间")))

    def test_semantics_and_models_require_review(self):
        self.assertEqual(m.observe(HTML.replace("测试时段", "新测试时段"), self.root)["status"], "review-required")
        self.assertEqual(m.observe(HTML.replace("deepseek-flash", "deepseek-new"), self.root)["status"], "review-required")
        self.assertEqual(m.observe(HTML.replace("0.02元", "0.03元"), self.root)["status"], "review-required")

    def test_repository_semantic_drift_requires_review(self):
        path = self.root / "Rules/pricing.json"
        pricing = json.loads(path.read_text())
        pricing["weeklyPeakWindows"][0]["start"] = "08:00"
        path.write_text(json.dumps(pricing))
        self.assertEqual(m.observe(HTML, self.root)["status"], "review-required")

    def test_broken_or_ambiguous_pages_fail_closed(self):
        for html in [HTML.replace("0.02元", "免费"), HTML.replace("8元", "8美元"), HTML.replace('rowspan="6"', 'rowspan="99"'), HTML + HTML, "<html>challenge</html>"]:
            with self.assertRaises((ValueError, IndexError)):
                m.extract(html)

    def changed_report(self):
        return m.observe(HTML.replace("0.02元", "0.03元").replace("0.04元", "0.06元"), self.root)

    def test_prepare_requires_verified_digest_and_effective_date(self):
        report = self.changed_report()
        before = (self.root / "Rules/pricing.json").read_bytes()
        for digest, effective in [("bad", "2026-10-28T09:00:00+08:00"), (report["digest"], "2026-10-28T09:00:00"), (report["digest"], "2027-01-01T09:00:00+08:00")]:
            with self.assertRaises(ValueError):
                m.prepare(report, self.root, digest, effective, m.SOURCE)
            self.assertEqual((self.root / "Rules/pricing.json").read_bytes(), before)

    def test_candidate_is_atomic_in_scope_and_updates_snapshot(self):
        report = self.changed_report()
        old_calendar = (self.root / "Rules/calendar-2026.json").read_bytes()
        old_policy = (self.root / "Rules/reminder-policy.json").read_bytes()
        with patch.object(m, "datetime", FixedDate):
            m.prepare(report, self.root, report["digest"], "2026-10-28T09:00:00+08:00", m.SOURCE)
        prices = json.loads((self.root / "Rules/pricing.json").read_text())
        self.assertEqual(prices["models"][0]["tiers"][0]["valley"], "0.03")
        self.assertEqual(prices["weeklyPeakWindows"], json.loads((ROOT / "Rules/pricing.json").read_text())["weeklyPeakWindows"])
        self.assertEqual((self.root / "Rules/calendar-2026.json").read_bytes(), old_calendar)
        self.assertEqual((self.root / "Rules/reminder-policy.json").read_bytes(), old_policy)
        manifest = json.loads((self.root / "Rules/manifest.json").read_text())
        for key, file in manifest["files"].items():
            self.assertEqual(manifest["sha256"][key], m.hashlib.sha256((self.root / "Rules" / file).read_bytes()).hexdigest())
        self.assertIn('cacheHit.valley.value == Decimal(string: "0.03")', (self.root / "Packages/Gudeng/Tests/GudengCoreTests/RuleBundleTests.swift").read_text())
        self.assertIn("| deepseek-flash | 输入（缓存命中） | 0.03 | 0.06 |", (self.root / "docs/product/requirements.md").read_text())

    def test_https_host_boundary(self):
        for url in ["http://api-docs.deepseek.com/", "https://evil.invalid/", "https://api-docs.deepseek.com@evil.invalid/", "https://api-docs.deepseek.com:444/"]:
            self.assertFalse(m.allowed_url(url))
        self.assertTrue(m.allowed_url(m.SOURCE))


class ActionsGlueTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("actions_glue", ROOT / "Scripts/official_pricing_actions.py")
        self.actions = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.actions)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.actions.REPORT = Path(self.tmp.name) / "report.json"
        self.actions.REPORT.with_suffix(".md").write_text("Synthetic report, no network.")

    def test_unchanged_does_not_notify_or_touch_human_issues(self):
        self.actions.REPORT.write_text(json.dumps({"status": "unchanged", "digest": "a" * 64}))
        human = {"number": 9, "body": self.actions.MARKER, "user": {"login": "maintainer"}}
        with patch.dict(self.actions.os.environ, {"GITHUB_REPOSITORY": "example/test"}), patch.object(self.actions.sys, "argv", ["tool", "notify"]), patch.object(self.actions, "api", return_value=[human]) as api:
            self.actions.main()
            self.assertEqual(api.call_count, 1)

    def test_same_drift_does_not_repeat_notifications(self):
        sha = "a" * 64
        self.actions.REPORT.write_text(json.dumps({"status": "prices-changed", "digest": sha}))
        issue = {"number": 1, "body": self.actions.MARKER + "<!-- observation-state:" + sha + ":prices-changed -->", "user": {"login": "github-actions[bot]"}}
        with patch.dict(self.actions.os.environ, {"GITHUB_REPOSITORY": "example/test"}), patch.object(self.actions.sys, "argv", ["tool", "notify"]), patch.object(self.actions, "api", return_value=[issue]) as api:
            self.actions.main()
            self.assertEqual(api.call_count, 1)
