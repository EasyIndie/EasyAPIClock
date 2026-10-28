# 发布手册（macOS）

GitHub Release 由 EasyIndie 组织的 [EasyRelease](https://github.com/EasyIndie/EasyRelease) reusable workflow 处理 Developer ID 签名、公证、staple、校验、manifest 与资产发布。应用构建仍由本仓库完成；组织共享凭据通过 `secrets: inherit` 传入，不在仓库保存密钥值。

## 1. 发布前检查

- [ ] `make doctor` 通过（macOS / Xcode / Swift / 固定版本 XcodeGen）。
- [ ] `make check` 通过（规则、测试、格式、双端构建）。
- [ ] `git status` 干净；版本号与 `CHANGELOG.md` 一致。
- [ ] 2026/当前年份规则包已按官方来源复核；覆盖范围足够。
- [ ] 通知真实设备验证（A15）已有记录。
- [ ] 隐私说明：不收集数据；唯一网络请求是用户主动检查规则更新。
- [ ] 确认目标仓库为 `EasyIndie/EasyAPIClock`，页面和规则源均使用该归属。
- [ ] `project.yml` 的 `GudengRuleSourceBaseURL` 指向仓库 `rules` 分支（fork 需改成自己的地址）；`Rules` workflow 最近一次发布成功。
- [ ] 用 raw URL 验证 manifest 与三个文件的 SHA-256；注意 CDN 可能有数分钟缓存。

## 2. Bundle ID 与团队

当前为 EasyIndie/EasyAPIClock 选择的 Bundle ID：

- macOS：`com.easyindie.easyapiclock`
- iOS：`com.easyindie.easyapiclock.ios`

品牌显示名为「谷蹬」，副标题为「DeepSeek API 峰谷钟点提醒」。Bundle ID 不需要与显示名或仓库名完全相同；提交 App Store Connect 前，须确认 EasyIndie 的 Apple 开发团队可注册这些唯一标识。

正式发布前改为你拥有控制权的反向域名，并同步：

- `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`
- 通知授权/沙盒容器路径文档
- 截图、README 与 issue 模板中的路径
- 规则更新源（`project.yml` 的 `GudengRuleSourceBaseURL`；fork 必须改）

0.1.1 起 Bundle ID 使用 EasyIndie 前缀（v0.1.0 为 `app.liangwen.mac`）；MVP 定为 1.0.0。`v1.0.0` 已于 2026-10-28 发布；v0.1.0 旧 Release 已删除，v0.1.1 仅有 tag。偏好、通知授权及沙盒容器不跨 Bundle ID 迁移。未来若提交 App Store Connect 构建，Bundle ID 上传后不可再改。在 Xcode 中设置 `DEVELOPMENT_TEAM`，或写入本地未提交的 `project.yml` 覆盖文件。不要把团队 ID 或证书提交到仓库。

## 3. 图标与资源

- 已提供 `Apps/Mac/Sources/Assets.xcassets/AppIcon.appiconset`（16–1024pt，10 个尺寸），由 `make icon` 重建。
- 图标为深色圆角底、左橙右绿（峰/谷）、指针 09:00；不含文字，避免小尺寸不可读。
- `project.yml` 已设置 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`；发布前确认 `Assets.car` 与 `CFBundleIconName`。
- 菜单栏使用 SF Symbols，当前不需要独立模板图；若后续改为自定义图标，需提供 template image 并验证深浅色。
- README 使用真实截图，不使用设计稿冒充成品。

## 4. 版本号

```yaml
MARKETING_VERSION: "1.0.0"   # 用户可见版本
CURRENT_PROJECT_VERSION: "4" # 构建号，每次上传递增
```

规则包版本（`bundleVersion`）独立于应用版本；发布说明中同时列出两者。

## 5. 签名与 Hardened Runtime

`project.yml` 已启用 `ENABLE_HARDENED_RUNTIME` 与 App Sandbox（含网络客户端）。

### 5.1 快速打包（推荐先跑）

```bash
# ad-hoc：可用于公开测试分发，但首次打开可能被 Gatekeeper 拦截，产物在 dist/
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

脚本会构建未签名的 `arm64 + x86_64` 产物，再手动签名（Developer ID + `--timestamp`；ad-hoc 不带时间戳），校验签名、检查包内规则与 Info.plist，生成 `dist/Gudeng-<版本>.dmg`、`.zip` 与 `SHA256SUMS`。校验：`cd dist && shasum -a 256 -c SHA256SUMS`。ad-hoc 包可以通过 GitHub Release 分发，但不包含 Developer ID 身份，也未经过 Apple 公证；macOS 可能拦截首次启动，Release 说明必须明确提示用户仅在信任来源时手动确认打开。公证会提交到 Apple 服务；没有明确授权不要执行 `make package-mac-notarized`。

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
  codesign -dv --verbose=4 dist/.../GudengMac.app
  ```
- 签名后、公证前 `spctl -a -vv` 仍可能拒绝，这是预期；公证并 staple 后再检查。

### 5.2 手动 archive（需要 Xcode 归档时）

使用 Developer ID Application 证书：

```bash
xcodebuild -project GudengClock.xcodeproj \
  -scheme GudengMac \
  -configuration Release \
  -archivePath .build/GudengClock.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath .build/GudengClock.xcarchive \
  -exportPath .build/export \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` 使用 `method = developer-id`，并指定团队。检查：

```bash
codesign -dv --verbose=4 .build/export/GudengMac.app
codesign --verify --deep --strict --verbose=2 .build/export/GudengMac.app
spctl -a -vv .build/export/GudengMac.app
```

## 6. 公证

优先使用 `make package-mac-notarized`。推荐把凭据存入钥匙串：

```bash
xcrun notarytool store-credentials "gudeng-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
DEVELOPER_TEAM="TEAMID" \
NOTARY_KEYCHAIN_PROFILE="gudeng-notary" \
make package-mac-notarized
```

也可以直接使用 `APPLE_ID` / `APPLE_TEAM_ID` / `APPLE_APP_PASSWORD` 环境变量；不要把这些值写入仓库或日志。

手动流程如下：

```bash
ditto -c -k --keepParent .build/export/GudengMac.app .build/GudengMac.zip
xcrun notarytool submit .build/GudengMac.zip \
  --keychain-profile "gudeng-notary" --wait
xcrun stapler staple .build/export/GudengMac.app
spctl -a -vv .build/export/GudengMac.app
```

凭据放在钥匙串，不写入仓库或 CI 日志。公证通过后重新打包 DMG/zip。

## 7. 打包与校验

`make package-mac` 已生成 zip、dmg 与 `SHA256SUMS`。手动方式：

```bash
hdiutil create -volname "谷蹬" -srcfolder .build/export/GudengMac.app \
  -ov -format UDZO .build/Gudeng-0.1.0.dmg
shasum -a 256 .build/Gudeng-0.1.0.dmg
```

同时发布：

- `.dmg`（或 zip）
- SHA-256 校验文件
- `Rules/manifest.json` 的 `bundleVersion` 与来源链接
- 已知限制（通知、强提醒、iOS 外壳）

## 8. 预览公证（不创建 Release）

正式发布前用 `Notarize preview` workflow 产出签名、公证并 staple 的 app，供本机验收：

```sh
gh workflow run notarize-preview.yml --ref main -f ref=main
gh run download <run-id> -n easyrelease-EasyAPIClock -D /tmp/preview
```

产物是 `GudengMac.app` 与 `apple-manifest.json`，仅作为 Actions artifact，不创建 tag 或公开 Release。它复用同一组织共享凭据与 EasyRelease 固定提交；验收通过后再执行下面的公开 Release 流程。预览不会写入 Release，也不能替代 `spctl`/`stapler validate` 本地复核。

## 9. GitHub Release

公开 Release 入口为 `.github/workflows/publish-release.yml`，只允许在 `main` 手动运行并勾选确认。该 workflow 核对版本并创建不可移动的版本 tag，再调用 EasyRelease reusable workflow（固定到 commit `1b2ccaec5bec0a557e86e11e28c9459a0b7c5633`）；EasyRelease 检出该 tag，运行 `make check` 与构建打包，然后使用应用 entitlements 进行 Developer ID 签名、提交 app ZIP 公证并 staple app，生成包含应用版本/build 的 manifest 与 SHA-256 后上传 GitHub Release。下载 ZIP 后解压，将「谷蹬」拖到「应用程序」文件夹。SHA-256 sidecar 使用产物文件名，可在下载目录直接校验。通过 `secrets: inherit` 传递 EasyIndie 组织共享凭据；本项目不重复实现签名/校验/资产发布流程。版本 tag 与 Release 均不可覆盖；构建失败后可在同一 tag 重试，已存在 Release 时必须递增 `MARKETING_VERSION`。

当前版本发布的是包含已签名、公证并 staple 的 app 的 ZIP。发布前确认 `CHANGELOG.md`、规则来源/覆盖日期、支持系统版本与通知限制准确。Release 文案会说明安装方式、签名、公证和 manifest 校验状态。

`.github/workflows/release.yml` 保留为短期的本地构建候选 artifact，不创建公开 Release。

## 9. GitHub Pages 产品页

产品页源文件位于 `site/`，由 `.github/workflows/pages.yml` 在 `main` 更新时部署到 GitHub Pages。仓库迁入 `EasyIndie/EasyAPIClock` 后，需在仓库 **Settings → Pages → Build and deployment** 将 Source 设为 **GitHub Actions**；首页链接使用 `https://easyindie.github.io/EasyAPIClock/`。上线以首次 Pages workflow 成功为准。

页面只使用仓库内图片和静态 HTML/CSS，不依赖第三方字体、分析脚本或外部构建服务。下载按钮指向 GitHub 最新 Release。

## 9.1 v1.0.0 发布记录（2026-10-28）

- 入口：`Publish macOS Release`（run 40646031872，`main` `02cc18e`）。
- 产物：`EasyAPIClock-v1.0.0.zip`、`EasyAPIClock-v1.0.0-manifest.json` 及各自 `.sha256`；tag `v1.0.0` 不可移动。
- 校验：1.0.0 (4)、universal arm64+x86_64、Developer ID `2N62934Y28`、公证 Accepted、staple、`spctl=Notarized Developer ID`、SHA-256 全部通过。
- 已用正式包替换本机与 `pro` 的 `/Applications/谷蹬.app` 并启动复核。
- `release-notes` job 首次因 Release API 404 失败（Release 已创建、资产完整），已手动补齐说明；workflow 已加入 5 次重试，后续发布仍应检查 Release body。

## 10. 发布后

- [ ] 在干净的用户账户或另一台 Mac 上安装并启动。
- [ ] 验证 Gatekeeper、公证、菜单栏、通知权限。
- [ ] 验证规则更新成功与坏包回退。
- [ ] 更新 README 状态表与 `CHANGELOG.md`。
- [ ] 监控 issue 中的安装/通知问题。

## 11. 回滚

- **应用**：撤回 Release / 标记为 pre-release；发布修复版本，不覆盖同一 tag。
- **规则**：发布 `publishedAt` 更新、内容修正的新规则包；不要指望客户端降级旧包。
- **紧急**：删除远端规则目录会让客户端保留本地有效版本；不要让目录处于半更新状态。

## macOS13兼容构建检查

`make build-mac-universal`生成未签名Release通用产物，并由`Scripts/verify-mac-build.py`核验arm64/x86_64与Info.plist及两种Mach-O最低系统均为13.0；CI同样执行。该检查不启动应用，不代替macOS13运行验证。开发主机仍须满足Xcode要求。

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

## 本机应用程序入口（2026-10-27）

用户要求的本地安装为`/Applications/谷蹬.app`；使用已存在Developer ID对本地Debug包签名并验证后复制，未公证、未上传、未创建Release。Finder→应用程序→双击谷蹬是日常图形启动入口，LSUIElement应用不创建常驻主窗口。源码修改不会自动更新安装副本。

本地更新应先完整构建与检查，在临时位置对副本签名并codesign验证，再退出安装路径对应的旧进程、保留旧包备份，替换应用程序包并从同一路径启动。不要直接覆盖运行中的包，也不要用不同签名身份覆盖而不说明权限影响；make run-mac仍只是独立开发构建启动命令。签名和本机安装不等于公证或对外分发。

官方单价CI观察及候选流程见official-pricing-automation.md：仅维护者明确确认后生成草稿，不能自动合并、发布Release或绕过Rules校验。Build2更新图标/视觉，安装签名仍按本地既有流程，不等同公证分发。
