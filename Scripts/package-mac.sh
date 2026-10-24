#!/bin/bash
#
# Builds a distributable macOS app and packages it as zip + dmg.
#
# Default: ad-hoc signing, for local verification only.
# Distribution: set DEVELOPER_ID_APPLICATION and DEVELOPER_TEAM.
# Notarization: pass --notarize and set APPLE_ID / APPLE_TEAM_ID /
# APPLE_APP_PASSWORD (app-specific password). Nothing is uploaded anywhere
# except Apple's notary service when --notarize is explicitly used.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTARIZE=0
if [[ "${1:-}" == "--notarize" ]]; then
  NOTARIZE=1
fi

PROJECT="LiangWenClock.xcodeproj"
SCHEME="LiangWenMac"
DERIVED="$ROOT/.build/ReleaseDerivedData"
APP="$DERIVED/Build/Products/Release/LiangWenMac.app"
DIST="$ROOT/dist"

if [[ ! -d "$PROJECT" ]]; then
  echo "缺少 $PROJECT，请先运行 make generate。" >&2
  exit 1
fi

SIGN_ID="${DEVELOPER_ID_APPLICATION:-}"
SIGN_ARGS=(CODE_SIGN_STYLE=Manual)
if [[ -n "$SIGN_ID" ]]; then
  if [[ -z "${DEVELOPER_TEAM:-}" ]]; then
    echo "设置 DEVELOPER_ID_APPLICATION 时也必须设置 DEVELOPER_TEAM。" >&2
    exit 1
  fi
  echo "使用 Developer ID 签名：$SIGN_ID"
  SIGN_ARGS+=(CODE_SIGN_IDENTITY="$SIGN_ID" DEVELOPMENT_TEAM="$DEVELOPER_TEAM" PROVISIONING_PROFILE_SPECIFIER="")
else
  echo "未设置 DEVELOPER_ID_APPLICATION，使用 ad-hoc 签名（仅本地验证，不可分发）。"
  SIGN_ARGS+=(CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="")
fi

echo "构建 Release（arm64 + x86_64）…"
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  "${SIGN_ARGS[@]}" \
  build

if [[ ! -d "$APP" ]]; then
  echo "未找到构建产物：$APP" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
SOURCE_URL="$(/usr/libexec/PlistBuddy -c 'Print :LiangWenRuleSourceBaseURL' "$APP/Contents/Info.plist" 2>/dev/null || true)"
BINARY="$APP/Contents/MacOS/LiangWenMac"

echo "Bundle：$BUNDLE_ID $VERSION ($BUILD_NUMBER)，最低系统 $MIN_OS"
if [[ -n "$SOURCE_URL" ]]; then
  echo "规则源：$SOURCE_URL"
else
  echo "警告：未配置 LiangWenRuleSourceBaseURL。" >&2
fi

ARCH_INFO="$(lipo -archs "$BINARY")"
echo "架构：$ARCH_INFO"
if [[ "$ARCH_INFO" != *arm64* || "$ARCH_INFO" != *x86_64* ]]; then
  echo "Release 产物不是通用二进制：$ARCH_INFO" >&2
  exit 1
fi

if [[ ! -f "$APP/Contents/Resources/Rules/manifest.json" ]]; then
  echo "应用包内缺少 Rules/manifest.json。" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP"

if [[ -n "$SIGN_ID" ]]; then
  if ! codesign -dv --verbose=4 "$APP" 2>&1 | grep -q "Authority=Developer ID Application"; then
    echo "签名不是 Developer ID Application，无法用于分发。" >&2
    exit 1
  fi
fi

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$SIGN_ID" ]]; then
    echo "公证需要 Developer ID 签名；请设置 DEVELOPER_ID_APPLICATION 与 DEVELOPER_TEAM。" >&2
    exit 1
  fi
  : "${APPLE_ID:?公证需要 APPLE_ID}"
  : "${APPLE_TEAM_ID:?公证需要 APPLE_TEAM_ID}"
  : "${APPLE_APP_PASSWORD:?公证需要 APPLE_APP_PASSWORD（app-specific password）}"

  mkdir -p "$DIST"
  NOTARY_ZIP="$DIST/notarize-upload.zip"
  rm -f "$NOTARY_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$NOTARY_ZIP"

  echo "提交 Apple 公证…"
  xcrun notarytool submit "$NOTARY_ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  rm -f "$NOTARY_ZIP"

  echo "staple 并验证…"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl -a -vv "$APP"
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/liangwen-stage.XXXXXX")"
cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$DIST"
DMG="$DIST/LiangWenClock-$VERSION.dmg"
ZIP="$DIST/LiangWenClock-$VERSION.zip"
rm -f "$DMG" "$ZIP"

echo "生成 DMG 与 zip…"
hdiutil create -volname "LiangWenClock" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

(
  cd "$DIST"
  shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > SHA256SUMS
)

echo
echo "已生成："
echo "  $DMG"
echo "  $ZIP"
echo "  $DIST/SHA256SUMS"
echo
echo "校验：cd dist && shasum -a 256 -c SHA256SUMS"
if [[ -z "$SIGN_ID" ]]; then
  echo
  echo "注意：当前为 ad-hoc 签名，只能本地验证；正式分发需要 Developer ID 与公证。"
fi
if [[ "$NOTARIZE" == "0" && -n "$SIGN_ID" ]]; then
  echo
  echo "注意：已用 Developer ID 签名，但未公证；Gatekeeper 仍可能拦截。"
fi
