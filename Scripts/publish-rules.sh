#!/bin/bash
#
# Publishes Rules/ to the generated `rules` branch.
#
# - Validates the bundle before publishing.
# - Requires a strictly newer publishedAt than the currently published branch,
#   and treats an identical bundle as already published (idempotent).
# - Builds an orphan snapshot with the rule files at the branch root, so the
#   client base URL is https://raw.githubusercontent.com/<owner>/<repo>/rules
# - Never edits the rules branch by hand; this script (or the Rules workflow)
#   owns it.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BRANCH="${RULES_BRANCH:-rules}"
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

for cmd in git python3 swift; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "缺少命令：$cmd" >&2
    exit 1
  fi
done

echo "校验规则包…"
swift run --package-path Packages/Gudeng gudeng-rules validate Rules

NEW_VERSION="$(python3 -c 'import json; print(json.load(open("Rules/manifest.json"))["bundleVersion"])')"
NEW_PUBLISHED="$(python3 -c 'import json; print(json.load(open("Rules/manifest.json"))["publishedAt"])')"

HAS_BRANCH=0
if git fetch -q origin "$BRANCH" 2>/dev/null; then
  HAS_BRANCH=1
fi

if [[ "$HAS_BRANCH" == "1" ]]; then
  if ! git cat-file -e "origin/$BRANCH:manifest.json" 2>/dev/null; then
    echo "origin/$BRANCH 存在但缺少 manifest.json。" >&2
    exit 1
  fi
  CURRENT_MANIFEST="$(git show "origin/$BRANCH:manifest.json")"
  DECISION="$(
    CURRENT_MANIFEST="$CURRENT_MANIFEST" python3 - <<'PY'
import json
import os
import sys
from datetime import datetime

def parse(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))

current = json.loads(os.environ["CURRENT_MANIFEST"])
new = json.load(open("Rules/manifest.json"))
if current["bundleVersion"] == new["bundleVersion"] and parse(current["publishedAt"]) == parse(new["publishedAt"]):
    print("same")
elif parse(new["publishedAt"]) > parse(current["publishedAt"]):
    print("newer")
else:
    print(
        f"新的 publishedAt ({new['publishedAt']}) 必须晚于已发布版本 ({current['publishedAt']})。",
        file=sys.stderr,
    )
    sys.exit(1)
PY
  )"
  if [[ "$DECISION" == "same" ]]; then
    echo "rules 分支已是 ${NEW_VERSION}（${NEW_PUBLISHED}），无需发布。"
    exit 0
  fi
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry-run：将发布 ${NEW_VERSION}（${NEW_PUBLISHED}）到 ${BRANCH}。"
  exit 0
fi

WORKTREE="$(mktemp -d "${TMPDIR:-/tmp}/gudeng-rules.XXXXXX")"
cleanup() {
  git -C "$ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git -C "$ROOT" worktree add --detach "$WORKTREE" HEAD >/dev/null
git -C "$WORKTREE" checkout --orphan rules-publish >/dev/null 2>&1
git -C "$WORKTREE" rm -rf . >/dev/null 2>&1 || true
cp -R "$ROOT/Rules/." "$WORKTREE/"
find "$WORKTREE" -name .DS_Store -delete

git -C "$WORKTREE" add -A
git -C "$WORKTREE" \
  -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "rules: publish $NEW_VERSION" >/dev/null
git -C "$WORKTREE" push --force origin "HEAD:$BRANCH"

git fetch -q origin "$BRANCH"
REMOTE_VERSION="$(git show "origin/$BRANCH:manifest.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["bundleVersion"])')"
if [[ "$REMOTE_VERSION" != "$NEW_VERSION" ]]; then
  echo "发布校验失败：rules 分支版本为 ${REMOTE_VERSION}，期望 ${NEW_VERSION}。" >&2
  exit 1
fi
echo "已发布 ${NEW_VERSION}（${NEW_PUBLISHED}）到 ${BRANCH}。"
