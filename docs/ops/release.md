# 发布手册（macOS）

当前仓库 **没有** 生成签名发布物的自动化流程。以下步骤需要 Apple Developer 账号、证书与明确的发布授权。不要在未授权的情况下上传、公证或创建 Release。

## 1. 发布前检查

- [ ] `make doctor` 通过（macOS / Xcode / Swift / 固定版本 XcodeGen）。
- [ ] `make check` 通过（规则、测试、格式、双端构建）。
- [ ] `git status` 干净；版本号与 `CHANGELOG.md` 一致。
- [ ] 2026/当前年份规则包已按官方来源复核；覆盖范围足够。
- [ ] 通知真实设备验证（A15）已有记录。
- [ ] 隐私说明：不收集数据；唯一网络请求是用户主动检查规则更新。
- [ ] 确定分发渠道与 Bundle ID。
- [ ] `project.yml` 的 `LiangWenRuleSourceBaseURL` 指向仓库 `rules` 分支（fork 需改成自己的地址）；`Rules` workflow 最近一次发布成功。
- [ ] 用 raw URL 验证 manifest 与三个文件的 SHA-256；注意 CDN 可能有数分钟缓存。

## 2. Bundle ID 与团队

仓库默认使用占位 Bundle ID：

- macOS：`app.liangwen.mac`
- iOS：`app.liangwen.ios`

正式发布前改为你拥有控制权的反向域名，并同步：

- `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`
- 通知授权/沙盒容器路径文档
- 截图、README 与 issue 模板中的路径
- 规则更新源（`project.yml` 的 `LiangWenRuleSourceBaseURL`；fork 必须改）

在 Xcode 中设置 `DEVELOPMENT_TEAM`，或写入本地未提交的 `project.yml` 覆盖文件。不要把团队 ID 证书提交到仓库。

## 3. 图标与资源

- 已提供 `Apps/Mac/Sources/Assets.xcassets/AppIcon.appiconset`（16–1024pt，10 个尺寸），由 `make icon` 重建。
- 图标为深色圆角底、左橙右绿（峰/谷）、指针 09:00；不含文字，避免小尺寸不可读。
- `project.yml` 已设置 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`；发布前确认 `Assets.car` 与 `CFBundleIconName`。
- 菜单栏使用 SF Symbols，当前不需要独立模板图；若后续改为自定义图标，需提供 template image 并验证深浅色。
- README 使用真实截图，不使用设计稿冒充成品。

## 4. 版本号

```yaml
MARKETING_VERSION: "0.1.0"   # 用户可见版本
CURRENT_PROJECT_VERSION: "1" # 构建号，每次上传递增
```

规则包版本（`bundleVersion`）独立于应用版本；发布说明中同时列出两者。

## 5. 签名与 Hardened Runtime

`project.yml` 已启用 `ENABLE_HARDENED_RUNTIME` 与 App Sandbox（含网络客户端）。

### 5.1 快速打包（推荐先跑）

```bash
# ad-hoc：仅本地验证，产物在 dist/
make package-mac

# Developer ID 签名（不公证）
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
DEVELOPER_TEAM="TEAMID" \
make package-mac

# Developer ID + 公证；需要 Apple 账号与 app-specific password
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
DEVELOPER_TEAM="TEAMID" \
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
make package-mac-notarized
```

脚本会构建未签名的 `arm64 + x86_64` 产物，再手动签名（Developer ID + `--timestamp`；ad-hoc 不带时间戳），校验签名、检查包内规则与 Info.plist，生成 `dist/LiangWenClock-<版本>.dmg`、`.zip` 与 `SHA256SUMS`。校验：`cd dist && shasum -a 256 -c SHA256SUMS`。**ad-hoc 产物不可分发。** 公证会提交到 Apple 服务；没有明确授权不要执行 `make package-mac-notarized`。

签名失败排查：

- `errSecInternalComponent` 或 `User interaction is not allowed`：login keychain 被锁定，或当前进程无法访问私钥。先解锁 Keychain Access 的 login 钥匙串，或在自己的终端执行 `security unlock-keychain ~/Library/Keychains/login.keychain-db`。
- **SSH 会话即使钥匙串已解锁也可能无法访问**；请在本机图形界面的 Terminal 中运行签名/公证（`open -a Terminal` 打开脚本即可）。
- 仍失败时，可在自己的终端执行一次（会要求钥匙串密码；不要把密码写进仓库、CI 或聊天）：
  ```bash
  security set-key-partition-list -S apple-tool:,apple: -s \
    -k <login-keychain-password> ~/Library/Keychains/login.keychain-db
  ```
- 确认签名身份：
  ```bash
  security find-identity -v -p codesigning
  codesign -dv --verbose=4 dist/.../LiangWenMac.app
  ```
- 签名后、公证前 `spctl -a -vv` 仍可能拒绝，这是预期；公证并 staple 后再检查。

### 5.2 手动 archive（需要 Xcode 归档时）

使用 Developer ID Application 证书：

```bash
xcodebuild -project LiangWenClock.xcodeproj \
  -scheme LiangWenMac \
  -configuration Release \
  -archivePath .build/LiangWenClock.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath .build/LiangWenClock.xcarchive \
  -exportPath .build/export \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` 使用 `method = developer-id`，并指定团队。检查：

```bash
codesign -dv --verbose=4 .build/export/LiangWenMac.app
codesign --verify --deep --strict --verbose=2 .build/export/LiangWenMac.app
spctl -a -vv .build/export/LiangWenMac.app
```

## 6. 公证

优先使用 `make package-mac-notarized`。推荐把凭据存入钥匙串：

```bash
xcrun notarytool store-credentials "liangwen-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
DEVELOPER_TEAM="TEAMID" \
NOTARY_KEYCHAIN_PROFILE="liangwen-notary" \
make package-mac-notarized
```

也可以直接使用 `APPLE_ID` / `APPLE_TEAM_ID` / `APPLE_APP_PASSWORD` 环境变量；不要把这些值写入仓库或日志。

手动流程如下：

```bash
ditto -c -k --keepParent .build/export/LiangWenMac.app .build/LiangWenMac.zip
xcrun notarytool submit .build/LiangWenMac.zip \
  --keychain-profile "liangwen-notary" --wait
xcrun stapler staple .build/export/LiangWenMac.app
spctl -a -vv .build/export/LiangWenMac.app
```

凭据放在钥匙串，不写入仓库或 CI 日志。公证通过后重新打包 DMG/zip。

## 7. 打包与校验

`make package-mac` 已生成 zip、dmg 与 `SHA256SUMS`。手动方式：

```bash
hdiutil create -volname "LiangWen Clock" -srcfolder .build/export/LiangWenMac.app \
  -ov -format UDZO .build/LiangWenClock-0.1.0.dmg
shasum -a 256 .build/LiangWenClock-0.1.0.dmg
```

同时发布：

- `.dmg`（或 zip）
- SHA-256 校验文件
- `Rules/manifest.json` 的 `bundleVersion` 与来源链接
- 已知限制（通知、强提醒、iOS 外壳）

## 8. GitHub Release

`.github/workflows/release.yml` 只能手动触发，产出 **workflow artifact**（zip/dmg/SHA256SUMS），不会创建 GitHub Release，也不会上传到公开服务器。正式发布仍需下面的命令与明确授权。

```bash
git tag -a v0.1.0 -m "LiangWen Clock 0.1.0"
git push origin v0.1.0
gh release create v0.1.0 .build/LiangWenClock-0.1.0.dmg \
  --notes-file RELEASE_NOTES.md
```

Release notes 必须包含：

- 应用版本与规则包版本；
- 支持的系统版本；
- 已验证的平台与通知限制；
- 价格/节假日数据核对日期；
- 未完成项（iOS、强提醒浮层等）；
- 安全/隐私说明。

## 9. 发布后

- [ ] 在干净的用户账户或另一台 Mac 上安装并启动。
- [ ] 验证 Gatekeeper、公证、菜单栏、通知权限。
- [ ] 验证规则更新成功与坏包回退。
- [ ] 更新 README 状态表与 `CHANGELOG.md`。
- [ ] 监控 issue 中的安装/通知问题。

## 10. 回滚

- **应用**：撤回 Release / 标记为 pre-release；发布修复版本，不覆盖同一 tag。
- **规则**：发布 `publishedAt` 更新、内容修正的新规则包；不要指望客户端降级旧包。
- **紧急**：删除远端规则目录会让客户端保留本地有效版本；不要让目录处于半更新状态。

## App Store 备注

若考虑 Mac App Store：

- 沙盒与网络客户端已启用；不请求私有 API。
- 规则数据更新需要符合审核对“下载内容”的要求；不得下载可执行代码。
- 通知权限说明、隐私政策、支持链接必须准备好。
- 上架不是当前承诺；需单独评估与授权。

## 未授权事项

没有维护者明确授权时，不要：

- 创建公开 Release 或上传二进制；
- 公证、签名分发；
- 购买开发者账号、域名或托管服务；
- 将规则源指向非项目控制的地址。
