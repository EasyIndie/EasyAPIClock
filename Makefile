SHELL := /bin/bash

PACKAGE := Packages/LiangWen
PROJECT := LiangWenClock.xcodeproj
DERIVED := .build/DerivedData
DERIVED_ADHOC := .build/DerivedDataAdhoc
DERIVED_IOS := .build/DerivedData-iOS
XCODEGEN := .build/tools/xcodegen/bin/xcodegen
XCODEBUILD := xcodebuild -project $(PROJECT)

.DEFAULT_GOAL := help
.PHONY: help bootstrap doctor tool generate test validate-rules rules-manifest rules-publish rules-publish-dry-run build-mac build-mac-universal build-mac-adhoc build-ios run-mac package-mac package-mac-notarized serve-test-rules test-rules icon format lint check-layers check preview clean

help:
	@printf '%s\n' \
		'谷蹬 · 常用命令' \
		'' \
		'  make bootstrap       安装固定版本 XcodeGen 并生成工程' \
		'  make doctor          检查 macOS / Xcode / Swift / XcodeGen 版本' \
		'  make generate        重新生成 Xcode 工程（源：project.yml）' \
		'  make test            运行 SwiftPM 单元测试' \
		'  make validate-rules  校验 Rules/ 规则包' \
		'  make rules-manifest  重新计算 manifest 校验和' \
		'  make rules-publish   校验并发布到 rules 分支（需要推送权限）' \
		'  make rules-publish-dry-run  只校验发布条件，不推送' \
		'  make build-mac       构建 macOS 应用（不签名）' \
		'  make build-ios       构建 iOS 模拟器应用（不签名）' \
		'  make build-mac-adhoc 构建 ad-hoc 签名的 macOS 应用（不启动）' \
		'  make run-mac         ad-hoc 签名并启动 macOS 应用' \
		'  make package-mac     Release 通用二进制 + zip/dmg（ad-hoc）' \
		'  make package-mac-notarized  使用 Developer ID 公证并打包' \
		'  make serve-test-rules  生成近期切换测试规则并启动本地服务器' \
		'  make test-rules      只生成测试规则包，不启动服务器' \
		'  make icon            重新生成 macOS AppIcon 全套尺寸' \
		'  make format          格式化 Swift 源码' \
		'  make lint            检查 Swift 格式' \
		'  make check-layers    检查业务模块依赖边界' \
		'  make check           分层 + 规则 + 测试 + 格式 + 双端构建' \
		'  make preview         在浏览器打开设计基准' \
		'  make clean           清理生成物（不会删除源码）'

bootstrap:
	@Scripts/install-xcodegen.sh
	@$(XCODEGEN) generate
	@Scripts/doctor.sh

doctor:
	@Scripts/doctor.sh

tool:
	@Scripts/install-xcodegen.sh

generate: tool
	$(XCODEGEN) generate

test:
	swift test --package-path $(PACKAGE)

validate-rules:
	swift run --package-path $(PACKAGE) liangwen-rules validate Rules

rules-manifest:
	swift run --package-path $(PACKAGE) liangwen-rules manifest Rules

rules-publish:
	@Scripts/publish-rules.sh

rules-publish-dry-run:
	@Scripts/publish-rules.sh --dry-run

build-mac: generate
	$(XCODEBUILD) -scheme LiangWenMac -configuration Debug \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO build

build-mac-adhoc: generate
	$(XCODEBUILD) -scheme LiangWenMac -configuration Debug \
		-derivedDataPath $(DERIVED_ADHOC) \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" build

build-mac-universal: generate
	$(XCODEBUILD) -scheme LiangWenMac -configuration Release \
		-destination 'generic/platform=macOS' -derivedDataPath .build/DerivedData-Release \
		ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
	python3 Scripts/verify-mac-build.py .build/DerivedData-Release/Build/Products/Release/LiangWenMac.app

build-ios: generate
	$(XCODEBUILD) -scheme LiangWeniOS -configuration Debug -sdk iphonesimulator \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(DERIVED_IOS) CODE_SIGNING_ALLOWED=NO build

run-mac: build-mac-adhoc
	bash Scripts/run-mac.sh "$(DERIVED_ADHOC)/Build/Products/Debug/LiangWenMac.app"

package-mac: generate
	@Scripts/package-mac.sh

package-mac-notarized: generate
	@Scripts/package-mac.sh --notarize

serve-test-rules:
	@Scripts/serve-test-rules.sh

test-rules:
	@Scripts/serve-test-rules.sh --no-serve

icon:
	@Scripts/generate-icon.sh

format:
	swift format format --in-place --recursive Packages Apps

lint:
	swift format lint --recursive Packages Apps

check-layers:
	python3 Scripts/check-module-boundaries.py

check: check-layers validate-rules test lint generate build-mac build-ios

preview:
	open docs/handoff/design-preview.html

clean:
	rm -rf .build Build/Generated $(PROJECT)
