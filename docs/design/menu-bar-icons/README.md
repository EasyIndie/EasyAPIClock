# 菜单栏峰谷图标 · 2026-10-26

项目决策：用户选定SF Symbols候选C。峰期 `arrow.up.circle.fill`，谷期 `arrow.down.circle.fill`。使用公开AppKit系统符号API、Semibold字重、单色渲染，保留系统橙／绿；符号在21×16pt占位内等比例居中，避免圆形被拉伸。图标表示当前高低价状态，不表示持续涨跌。状态文字和未知问号保留。

两张着色NSImage静态复用。SF符号内的箭头镂空随背景透出。应用图标、规则数据和用户设置未改变。

`preview.png`由生产MenuBarStatusIcon绘制代码经AppKit离屏生成；每行上方为实际21×16pt、下方为2倍放大，画板导出2×像素。深浅底色只是对照背景，并非菜单栏真实截图；样例时间用于排版，不修改价格状态。没有更改应用图标或规则数据。

生产系统符号绘制：`Packages/LiangWen/Sources/LiangWenKit/Views/MenuBarStatusIcon.swift`。两张NSImage静态复用，避免每分钟重新创建。

复现预览（仓库根目录）：

```sh
cp docs/design/menu-bar-icons/render-preview.swift /tmp/main.swift
swiftc -swift-version 6 Packages/LiangWen/Sources/LiangWenKit/Views/MenuBarStatusIcon.swift /tmp/main.swift -o /tmp/gudeng-icon-preview
/tmp/gudeng-icon-preview docs/design/menu-bar-icons/preview.png
```

设计参考：[Apple HIG菜单栏](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)；2026-10-26官方HTML返回JavaScript占位，Markdown读取未成功，未据此声称已核验最新全文。价格状态映射是项目设计选择，不是Apple规范要求。

`exploration.png`、`phase-preview.png`和`exploration.md`保留上一轮未采用的设计探索，不代表当前生产版本。

2026-10-26最终选定C；山水、相位环及第三方图标仅为历史参考。
