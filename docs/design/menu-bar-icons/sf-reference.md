# SF Symbols 原生参考 · 2026-10-26

来源：[Apple SF Symbols](https://developer.apple.com/sf-symbols/)、[HIG SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)。官方介绍确认可配置字重、大小和渲染模式。本机未安装独立SF Symbols应用；本次通过AppKit的NSImage(systemSymbolName:accessibilityDescription:)读取并原生渲染系统符号，不临摹Apple图形。

已验证本机系统提供mountain.2、mountain.2.fill、mountain.2.circle、mountain.2.circle.fill；CoreGlyphs的name_availability.plist记录为macOS13.0起，符合项目macOS14最低要求。上述名字未在本机symbol_restrictions.strings中找到条目，但这不能代替完整许可审核。系统元数据只用于调研，生产应仅使用公开系统符号API，不依赖这些元数据文件。

推荐mountain.2.fill、Semibold：原生圆润峰顶、肩峰和底角，实心面积较大。Black可对照重量，但21×16pt内细节更挤。圆形填充版本增加外围圆盘，与用户要求的直接山体意象相比优先级较低。

本轮检索mountain/valley/hill/terrain/landscape相关系统符号名与搜索词，未找到语义和形态匹配的实心山谷两态对。不能把自绘谷图标称作官方SF Symbol。下一步建议保留SF山峰的圆润比例、统一设计谷口凹弧与谷底重量；两态必须同框验证。

sf-reference.png为AppKit离屏原生符号渲染，包含放大对照和21×16pt框内等比例呈现，单色橙色模式；不是实机菜单栏截图，也没有改变用户设置或当前生产图标。参考只针对应用内菜单栏价格状态，不作为应用图标或商标设计授权。

复现：复制render-sf-reference.swift为/tmp/main.swift，使用swiftc -swift-version 6编译，执行时传入输出PNG绝对路径。
