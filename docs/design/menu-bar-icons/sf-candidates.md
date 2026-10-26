# 扩展SF Symbols候选 · 2026-10-26

依据用户授权扩大到山峰／山谷之外，保持简洁、实心占比、原生圆润和菜单栏可读性。公开参考：[Apple SF Symbols](https://developer.apple.com/sf-symbols/)。本机AppKit NSImage公开系统符号接口确认所有候选可调用。

| 候选 | 峰 / 谷符号 | 本机元数据记录最低macOS | 设计判断 |
|---|---|---|---|
| A 半圆相位 | circle.tophalf.filled / circle.bottomhalf.filled | 12.0 | 推荐：上下半填充区分高低，安静、抽象，不暗示正在涨跌；需要峰谷文字辅助学习 |
| B 高低刻度 | gauge.with.dots.needle.67percent / gauge.with.dots.needle.33percent | 14.0 | 备选：原生仪表形象，但细节较多，易被理解为负载；指针角度只作状态映射，不代表真实利用率、价格比例或倒计时百分比 |
| C 上下箭头 | arrow.up.circle.fill / arrow.down.circle.fill | 10.15 | 识别强，容易误解为价格正在涨跌或上传下载 |
| D 加减 | plus.circle.fill / minus.circle.fill | 10.15 | 实心面积大，但像新增/删除操作，不优先推荐 |
| E 统一时钟 | clock.fill / clock.fill | 10.15 | 最贴合钟点提醒，价格状态由现有峰谷文字和颜色区分；图形本身不区分两态 |

预览为Semibold、单色橙/绿、等比例21×16pt占位及放大图；示例时间仅用于排版。半圆在离屏翻转画布中单独校正绘制方向，保持符号名称中的top/bottom语义；所有候选仍需在真正MenuBarExtra中验证。画板不是实机截图。

初步推荐A作为状态符号，E作为统一产品入口；不是Apple给出的价格状态标准映射。所有候选符合当前macOS14最低目标（依据本机CoreGlyphs元数据核对），B正好要求14，若之后降低目标到13需改用较早的gauge.high/gauge.low或回退。此次只做候选设计，不修改产品图标、业务规则或用户设置。
