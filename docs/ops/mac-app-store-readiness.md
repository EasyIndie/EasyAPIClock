# Mac App Store 上架要求初查

核对：2026-10-26。范围：谷蹬的原生macOS应用；本轮仅调研，没有上传、申请证书、签名公证或修改部署目标。结论是准备清单，不是审核通过保证。

## 版本与构建

支持macOS13是项目覆盖目标，不是本次查到的上架强制门槛。[App Store Connect构建元数据](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata/)从构建读取最低系统版本；构建SDK和最低运行版本需要分别配置与验证。

[上传构建支持表](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)当前单列macOS：构建Xcode6起、经Xcode上传为14起。项目仍应保持自己的Swift6工具链要求；[2026年4月SDK公告](https://developer.apple.com/news/?id=ueeok6yw)列出的26SDK要求针对iOS/iPadOS/tvOS/visionOS/watchOS，不能据此认定Mac应用最低运行系统要26。本地Xcode27并不自动证明兼容macOS13。

## 分发路径

需要Apple Developer Program团队、注册Bundle ID、App Store Connect记录及相应分发签名／描述文件。[Xcode分发方式](https://help.apple.com/xcode/mac/current/en.lproj/dev31de635e5.html)区分App Store Connect与Developer ID；现有Developer ID／公证／DMG路径用于站外分发，不是商店提交流程。应新增Archive、Validate、App Store Connect导出／上传配置，保留现有本地打包用途。

## 项目逐项对照

| 项目 | 当前证据与差距 | 下一步 |
|---|---|---|
| 沙盒与网络 | project.yml和Apps/Mac/GudengMac.entitlements已配置app-sandbox、network.client | 用最终商店签名构建检查实际权限及容器内读写 |
| 菜单栏入口 | MenuBarExtra原生实现；所查规则未发现单独禁止菜单栏形态 | 审核备注明确无常驻主窗口、点击状态项进入、设置及退出位置 |
| 持续实用性 | 本地价格状态、倒计时、日历语义、提醒与离线回退 | 将这些实际能力演示给审核员；不以新增范围外功能应对假想拒绝 |
| 启动与退出 | SMAppService开关、预览退出清理已实现；实际重新登录待验 | 验证用户主动开启、关闭与退出行为，说明正式通知的系统排程语义 |
| 更新 | 只下载有限JSON规则包，整包校验，无远程脚本 | 说明这是价格／日历内容更新；客户端程序更新经商店。审核仍可能要求解释其边界 |
| 通知 | 本地UN通知；预览已有本机记录 | 完成正式切换、拒绝授权、强提醒停止、Focus／静音／睡眠等矩阵；拒绝授权时仍可看状态 |
| 隐私 | 未发现隐私政策页面及应用内入口；无账号／统计SDK；存在GitHub规则请求 | 提供公开隐私政策与应用内链接，核对第三方网络数据处理后填写App Privacy，不能仅凭无账号就声称零数据 |
| 商品材料 | 有应用图标与面板截图，尚无商店提交材料包 | 准备说明、支持URL、联系方式、版权、年龄分级、审核备注、出口合规回答及销售地区声明 |

依据：[审核指南](https://developer.apple.com/app-store/review/guidelines/)2.4.5要求沙盒、用户同意登录启动和商店程序更新；2.5.2约束下载代码／改变功能；4.2关注持续实用性；5.1.1要求商店元数据和应用内隐私政策。上述“规则JSON可作为内容更新解释”“菜单栏产品形态可行”是针对当前实现的判断，不是苹果对本项目的预批准。自定义规则不得承载新功能或可执行逻辑。

## 隐私申报的两个层次

[App Privacy](https://developer.apple.com/app-store/app-privacy-details/)与[隐私政策URL](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)仍需准备，即使最终核对结果是不收集用户数据。[隐私清单文档](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)区分全平台数据收集说明与required-reason API适用平台；后者列iOS/iPadOS/tvOS/visionOS/watchOS，没有列macOS。不能只因Mac使用UserDefaults，就直接断言缺PrivacyInfo.xcprivacy一定导致拒绝。仓库当前没有该文件，后续应按真实数据行为及最终上传验证结果处理；iOS若正式上架则需另核对UserDefaults原因声明。

## 截图

[Mac截图要求](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)：16:10，接受1280×800、1440×900、2560×1600、2880×1800，至少1张、至多10张，不含alpha。[版本信息](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)还包括支持URL、版权及审核说明等字段。现有334×322pt面板裁图不能直接当作合规格商店截图；需要在合适画布中展示真实菜单栏与面板，不伪造功能。

## 建议优先级

1. 补公开隐私政策／支持页面、应用内政策入口及真实数据流清单。
2. 建商店Archive／签名／Validate流程，与站外公证打包区分。
3. 完成通知和登录项真实验证，准备可复现审核步骤及规则更新说明。
4. macOS13兼容迁移可并行，但正式宣称支持前必须完成旧系统与双架构验证。
5. 最后完成截图与商店元数据，在明确授权后才上传或送审。
