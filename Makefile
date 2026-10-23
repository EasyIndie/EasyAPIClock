SHELL := /bin/bash

PACKAGE := Packages/LiangWen
PROJECT := LiangWenClock.xcodeproj
DERIVED := .build/DerivedData
DERIVED_IOS := .build/DerivedData-iOS
XCODEGEN := .build/tools/xcodegen/bin/xcodegen
XCODEBUILD := xcodebuild -project $(PROJECT)

.DEFAULT_GOAL := help
.PHONY: help bootstrap doctor tool generate test validate-rules rules-manifest rules-publish rules-publish-dry-run build-mac build-ios run-mac format lint check preview clean

help:
	@printf '%s\n' \
		'梁文钟 · 常用命令' \
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
		'  make run-mac         ad-hoc 签名并启动 macOS 应用' \
		'  make format          格式化 Swift 源码' \
		'  make lint            检查 Swift 格式' \
		'  make check           规则 + 测试 + 格式 + 双端构建' \
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

build-ios: generate
	$(XCODEBUILD) -scheme LiangWeniOS -configuration Debug -sdk iphonesimulator \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(DERIVED_IOS) CODE_SIGNING_ALLOWED=NO build

run-mac: generate
	$(XCODEBUILD) -scheme LiangWenMac -configuration Debug \
		-derivedDataPath $(DERIVED) \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" build
	open "$(DERIVED)/Build/Products/Debug/LiangWenMac.app"

format:
	swift format format --in-place --recursive Packages Apps

lint:
	swift format lint --recursive Packages Apps

check: validate-rules test lint generate build-mac build-ios

preview:
	open docs/handoff/design-preview.html

clean:
	rm -rf .build Build/Generated $(PROJECT)
