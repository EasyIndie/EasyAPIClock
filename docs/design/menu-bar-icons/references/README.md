# 专业山峰图标调研 · 2026-10-26

用户目标：山峰／山谷意象、简洁、实心面积较大、角度柔和。

`comparison.png`使用官方SVG原始轮廓渲染，未改路径；展示放大轮廓和16pt正方形图标框。该尺寸包含库自带留白，并非已完成21×16pt菜单栏光学校正。不是实机菜单栏截图。

| 来源 | 参考价值 | 取舍 | 许可 |
|---|---|---|---|
| [Google Material Landscape Round](https://github.com/google/material-design-icons/blob/master/src/image/landscape/materialiconsround/24px.svg) | 圆润峰顶、凹口与底角；单色大面积填充 | 最适合本项目，采用其圆角语言定制成对山峰与山谷 | Apache-2.0，见material-LICENSE |
| [Phosphor Mountains Fill](https://github.com/phosphor-icons/core/blob/main/assets/fill/mountains-fill.svg) | 饱满填充与双峰分层 | 日点、雪峰切口对菜单栏较复杂，适合比例参考 | MIT，Copyright (c) 2023 Phosphor Icons；见phosphor-LICENSE |
| [Tabler Mountain Filled](https://github.com/tabler/tabler-icons/blob/main/icons/filled/mountain.svg) | 圆钝峰顶与底角 | 内部雪线缩小后较细，适合圆角参考 | MIT，Copyright (c) 2020-2026 Paweł Kuna；见tabler-LICENSE |

已保存原始SVG、对应许可和转换预览，校验和与URL见sources.json。Material terrain round与landscape round在本次下载中为同一轮廓，未当作独立方案。

## 设计建议

借鉴Material Rounded的软化方式，保留山势转折，把尖锐顶点改成短弧过渡；不是整块变成圆团。峰的顶部收圆，谷的中央改用连续凹弧，底部圆角，保证大块实体和充分负空间。在现有21×16pt内做光学放大、统一基线与两态重量。颜色和文字保持既有语义。

这些参考没有提供已经核验的峰／谷状态成套符号，谷状态需要配套定制。可以引用所选库的静态矢量，采用时保留对应版权／许可证并标注修改；不需要引入第三方运行时或SwiftPM依赖。本轮只调研归档，没有修改生产图标或重启应用。
