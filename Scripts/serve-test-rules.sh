#!/bin/bash
#
# Creates a temporary rule bundle with a peak window starting soon, so the
# notification paths can be exercised without waiting for 09:00 / 14:00.
#
# The bundle is written to .build/test-rules and served over localhost. It is
# never committed or published.
#
# Test-only: LIANGWEN_TEST_NOW=2026-10-26T09:00:00+08:00 overrides the clock so
# the generator can be validated on a weekend. Do not use it for notification
# testing; the app still runs on the real clock. The test bundle's publishedAt is intentionally
# newer than the production bundle, so it will be installed by the app; remove
# the app's active rules afterwards to fall back to the bundled rules.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LEAD_MINUTES=3
PORT=8765
SERVE=1
INSTALL_ONLY=0

usage() {
  cat <<'EOF'
用法：
  Scripts/serve-test-rules.sh [--lead-minutes N] [--port N] [--no-serve]

  --lead-minutes N  距离峰期开始还有几分钟（默认 3；测试提前提醒建议 7）
  --port N          本地 HTTP 端口（默认 8765）
  --install-only    只更新版本/发布时间，不修改价格时段（任意一天可用）
  --no-serve        只生成测试规则包，不启动服务器
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lead-minutes)
      LEAD_MINUTES="${2:?--lead-minutes 需要数值}"
      shift 2
      ;;
    --port)
      PORT="${2:?--port 需要数值}"
      shift 2
      ;;
    --install-only)
      INSTALL_ONLY=1
      shift
      ;;
    --no-serve)
      SERVE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! [[ "$LEAD_MINUTES" =~ ^[0-9]+$ ]] || (( LEAD_MINUTES < 1 || LEAD_MINUTES > 30 )); then
  echo "--lead-minutes 需要 1–30 的整数。" >&2
  exit 2
fi
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo "--port 需要 1024–65535 的整数。" >&2
  exit 2
fi

for cmd in python3 swift; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "缺少命令：$cmd" >&2
    exit 1
  fi
done

DIR="$ROOT/.build/test-rules"
rm -rf "$DIR"
mkdir -p "$DIR"
cp "$ROOT"/Rules/*.json "$DIR/"

LEAD_MINUTES="$LEAD_MINUTES" DIR="$DIR" INSTALL_ONLY="$INSTALL_ONLY" python3 - <<'PY'
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

lead = int(os.environ["LEAD_MINUTES"])
install_only = os.environ.get("INSTALL_ONLY") == "1"
root = Path(os.environ["DIR"])
tz = timezone(timedelta(hours=8))
override = os.environ.get("LIANGWEN_TEST_NOW", "")
if override:
    now = datetime.fromisoformat(override.replace("Z", "+00:00"))
    if now.tzinfo is None:
        now = now.replace(tzinfo=tz)
    now = now.astimezone(tz)
    print(f"使用 LIANGWEN_TEST_NOW={override} 生成（仅用于验证脚本逻辑）。")
else:
    now = datetime.now(tz)
today = now.date()

if not install_only and now.weekday() >= 5:
    sys.exit("今天是周末；周末恒为谷，无法用本地规则制造峰切换。请在工作日运行，或使用 --install-only 只测试安装。")
if not install_only and now.hour == 23 and now.minute >= 45:
    sys.exit("已接近北京时间午夜；请改在工作日白天运行，避免窗口跨日。")

manifest_path = root / "manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

if install_only:
    print("install-only：不修改价格时段，只更新版本与发布时间。")
else:
    start = (now + timedelta(minutes=lead)).replace(second=0, microsecond=0)
    end = start + timedelta(minutes=2)
    if start <= now:
        start += timedelta(minutes=1)
        end = start + timedelta(minutes=2)
    if end.date() != today:
        sys.exit("测试窗口会跨午夜；请减小 --lead-minutes 或改天运行。")

    weekday = today.isoweekday()
    pricing_path = root / "pricing.json"
    pricing = json.loads(pricing_path.read_text(encoding="utf-8"))
    windows = [w for w in pricing["weeklyPeakWindows"] if w["weekday"] != weekday]
    windows.append(
        {
            "weekday": weekday,
            "start": start.strftime("%H:%M"),
            "end": end.strftime("%H:%M"),
        }
    )
    windows.sort(key=lambda w: (w["weekday"], w["start"]))
    pricing["weeklyPeakWindows"] = windows
    pricing_path.write_text(
        json.dumps(pricing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    calendar_name = manifest["files"]["calendar"]
    calendar_path = root / calendar_name
    calendar = json.loads(calendar_path.read_text(encoding="utf-8"))
    before = len(calendar["holidays"])
    calendar["holidays"] = [
        h
        for h in calendar["holidays"]
        if not (h["from"] <= today.isoformat() <= h["through"])
    ]
    if len(calendar["holidays"]) != before:
        print(
            f"已从测试日历移除覆盖今天的 {before - len(calendar['holidays'])} 条假期（仅测试包）。"
        )
    calendar_path.write_text(
        json.dumps(calendar, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

current_published = datetime.fromisoformat(
    manifest["publishedAt"].replace("Z", "+00:00")
)
published = max(now, current_published) + timedelta(minutes=1)
base_version = manifest["bundleVersion"].split("-test-")[0]
manifest["bundleVersion"] = f"{base_version}-test-{now:%H%M%S}"
manifest["publishedAt"] = published.isoformat(timespec="seconds")
manifest["effectiveFrom"] = (now - timedelta(minutes=1)).isoformat(timespec="seconds")
manifest["notes"] = "本地测试规则包，仅用于平台验证；不要发布。"
manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)

print(f"publishedAt：{manifest['publishedAt']}")
if install_only:
    print("只验证规则安装/更新路径，不产生价格切换。")
else:
    advance = start - timedelta(minutes=5)
    print(f"测试窗口：{today.isoformat()} {start:%H:%M}–{end:%H:%M}（北京时间）")
    if lead >= 5:
        print(f"提前提醒将在 {advance:%H:%M} 触发（需在设置中开启）。")
    else:
        print("lead-minutes < 5：本次不会触发提前提醒；如需测试请用 --lead-minutes 7。")
PY

echo "重新计算 manifest 校验和…"
swift run --package-path Packages/LiangWen liangwen-rules manifest "$DIR"
echo "校验测试规则包…"
swift run --package-path Packages/LiangWen liangwen-rules validate "$DIR"

APP="${LIANGWEN_APP:-$ROOT/.build/DerivedDataAdhoc/Build/Products/Debug/LiangWenMac.app}"
echo
echo "规则包：$DIR"
echo "先退出正在运行的谷蹬，然后构建并带环境变量启动："
echo "  make build-mac-adhoc"
echo "  LIANGWEN_RULE_SOURCE=http://127.0.0.1:$PORT \"$APP/Contents/MacOS/LiangWenMac\""
echo "在设置中点击「检查更新」，安装测试包后等待窗口切换。"
echo
echo "测试结束后清理本地规则，回退内置规则："
echo "  rm -rf ~/Library/Containers/com.easyindie.easyapiclock/Data/Library/Application\\ Support/LiangWen/Rules/active"

if [[ "$SERVE" == "0" ]]; then
  exit 0
fi

echo
echo "启动本地规则服务器：http://127.0.0.1:$PORT"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$DIR"
