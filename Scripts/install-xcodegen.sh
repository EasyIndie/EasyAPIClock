#!/bin/bash
#
# Installs the XcodeGen version pinned in .xcodegen-version.
#
# - Downloads the official universal release and verifies SHA-256.
# - Installs the full distribution, including share/xcodegen/SettingPresets.
# - Never installs an unpinned "latest" version or a bare binary.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/.xcodegen-version"
TOOLS_DIR="$ROOT/.build/tools"
DEST_ROOT="$TOOLS_DIR/xcodegen"
DEST_BIN="$DEST_ROOT/bin/xcodegen"
CHECK_ONLY=0

# Keep these in sync when bumping .xcodegen-version.
DOWNLOAD_URL_TEMPLATE="https://github.com/yonaskolb/XcodeGen/releases/download/%s/xcodegen.zip"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "缺少 $VERSION_FILE" >&2
  exit 1
fi
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

version_of() {
  "$1" --version 2>/dev/null | awk '{print $2}'
}

if [[ -x "$DEST_BIN" ]] \
  && [[ -d "$DEST_ROOT/share/xcodegen/SettingPresets" ]] \
  && [[ "$(version_of "$DEST_BIN")" == "$VERSION" ]]; then
  if [[ "$CHECK_ONLY" == "1" ]]; then
    echo "xcodegen ${VERSION} ($DEST_BIN)"
    exit 0
  fi
  echo "$DEST_BIN"
  exit 0
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo "未找到固定版本 xcodegen ${VERSION}。运行 make bootstrap 安装。" >&2
  exit 1
fi

for cmd in curl unzip shasum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "缺少命令：$cmd" >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gudeng-xcodegen.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

URL="$(printf "$DOWNLOAD_URL_TEMPLATE" "$VERSION")"
echo "下载 XcodeGen ${VERSION}：$URL" >&2
curl -fsSL --retry 3 --retry-delay 1 "$URL" -o "$TMP_DIR/xcodegen.zip"
if ! echo "$SHA256  $TMP_DIR/xcodegen.zip" | shasum -a 256 -c - >/dev/null 2>&1; then
  echo "XcodeGen 下载校验失败（SHA-256 不匹配）。" >&2
  exit 1
fi
unzip -q "$TMP_DIR/xcodegen.zip" -d "$TMP_DIR/unpacked"

if [[ ! -x "$TMP_DIR/unpacked/xcodegen/bin/xcodegen" ]] \
  || [[ ! -d "$TMP_DIR/unpacked/xcodegen/share/xcodegen/SettingPresets" ]]; then
  echo "XcodeGen 压缩包结构不符合预期（缺少 bin 或 SettingPresets）。" >&2
  exit 1
fi

mkdir -p "$TOOLS_DIR"
rm -rf "$DEST_ROOT"
mkdir -p "$DEST_ROOT"
cp -R "$TMP_DIR/unpacked/xcodegen/." "$DEST_ROOT/"
chmod +x "$DEST_BIN"

INSTALLED="$(version_of "$DEST_BIN")"
if [[ "$INSTALLED" != "${VERSION}" ]]; then
  echo "XcodeGen 版本不匹配：期望 ${VERSION}，实际 ${INSTALLED}" >&2
  exit 1
fi

echo "$DEST_BIN"
