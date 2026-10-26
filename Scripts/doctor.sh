#!/bin/bash
#
# Prints the local toolchain and checks the requirements for building this repo.
# This script never downloads anything; use `make bootstrap` to install XcodeGen.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAILED=0

ok() { printf '  ✅ %s\n' "$1"; }
bad() { printf '  ❌ %s\n' "$1"; FAILED=1; }
info() { printf '  • %s\n' "$1"; }

printf '谷蹬 · 开发环境检查\n\n'

printf '系统\n'
OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 0)"
info "macOS $OS_VERSION ($(uname -m))"
if [[ "${OS_VERSION%%.*}" -ge 14 ]]; then
  ok "macOS 14+"
else
  bad "需要 macOS 14+"
fi

printf '\nXcode / Swift\n'
if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VERSION="$(xcodebuild -version | head -1 | awk '{print $2}')"
  info "Xcode $XCODE_VERSION"
  if [[ "${XCODE_VERSION%%.*}" -ge 16 ]]; then
    ok "Xcode 16+"
  else
    bad "需要 Xcode 16+（Swift 6）"
  fi
  info "Developer dir: $(xcode-select -p)"
else
  bad "未找到 xcodebuild，请安装 Xcode 16+"
fi

if command -v swift >/dev/null 2>&1; then
  SWIFT_VERSION="$(swift --version 2>/dev/null | head -1 | sed -E 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/')"
  info "Swift $SWIFT_VERSION"
  if [[ "${SWIFT_VERSION%%.*}" -ge 6 ]]; then
    ok "Swift 6+（严格并发）"
  else
    bad "需要 Swift 6+"
  fi
else
  bad "未找到 swift"
fi

printf '\nXcodeGen（固定版本）\n'
if Scripts/install-xcodegen.sh --check >/dev/null 2>&1; then
  ok "$(Scripts/install-xcodegen.sh --check 2>/dev/null)"
else
  bad "未找到 .xcodegen-version 指定的版本；运行 make bootstrap"
fi

printf '\n仓库文件\n'
for path in project.yml .xcodegen-version Packages/LiangWen/Package.swift Rules/manifest.json Rules/pricing.json Rules/calendar-2026.json Rules/reminder-policy.json; do
  if [[ -e "$path" ]]; then
    ok "$path"
  else
    bad "缺少 $path"
  fi
done

printf '\n下一步\n'
if [[ "$FAILED" == "0" ]]; then
  printf '  make test        运行 56 个单元测试\n'
  printf '  make run-mac     构建并启动 macOS 应用\n'
  printf '  make check       完整检查（规则 + 测试 + 格式 + 双端构建）\n'
else
  printf '  修复上面的问题后再运行 make bootstrap。\n'
fi

exit "$FAILED"
