# 时长表达、菜单栏对齐与紧凑设置验收

2026-10-26，macOS 27.0.1 arm64，本地 ad-hoc Debug。最终实例 PID 22782。本轮依据 device-interaction 技能，以真实 System Events AX 元素和 CGEvent 交互；未修改系统权限或用户偏好。

## 最终通过

- `06-main-final.png`：真实主面板 334×322pt。倒计时明确显示“11小时6分”，数字与小单位共同表达持续时长，下方“后进入峰期”；没有数字或单位截断、重叠。
- `07-menubar-final.png`：真实菜单栏项目。绿色实心圆及向下箭头完整，圆形视觉中线与“谷”和时长文字一致；保留原生 SF Symbol 的 alignmentRect，未使用自定义画布或经验像素偏移。
- `08-settings-collapsed.png`：默认设置完整显示提醒强度、提前提醒、预览三行，外观／通用／规则均折叠，检查更新与退出同一行在 275pt 滚动区内可见，不需滚动。
- `09-appearance-expanded.png`、`11-general-expanded.png`：真实分组可展开，外观／动效、登录项状态／自动更新控件保留；展开内容过长时使用原有滚动区。
- `13-rules-expanded.png`、`14-rules-bottom.png`：规则说明、来源链接和底部检查更新／退出可滚动访问。
- `16-all-collapsed.json` 确认恢复三个折叠组；`17-final-main.json/png` 确认返回主面板，334×322pt。未点击提醒预览、更新、退出或偏好开关。

## 验收中发现并已修复

首次使用单色 palette 配置时，箭头也被涂实，实际菜单栏变为纯绿圆（`05-menubar-palette-regression.png`）。独立 AppKit 探针确认：先应用 palette，再应用 preferringMonochrome 可以保留挖空箭头和原生对齐元数据。应用修复后重建，`07-menubar-final.png` 是最终通过证据。

`probe-palette-invalid.png`、`probe-palette-monochrome.png` 和 `symbol-configuration-probe.swift` 是独立原生绘制探针，**不是运行应用截图**。01–04记录首次构建：01刚展开时内容AX尚未稳定，02工具切换后面板收起；03起在同一JXA内展开、读取AX并截图取得有效运行内容。最终结论以06–17为准。

## 截图方式与边界

跨工具调用可能使菜单栏面板收起，单独 screencapture 会拍到下层应用。最终截图在同一 JXA 交互中按即时 AX 窗口／状态项坐标调用 screencapture，避免把下层界面当作产品截图。

本轮是当前系统、深色实际界面的视觉与交互验收；没有额外声称 macOS13、通知投递、登录启动、VoiceOver或所有外观状态通过。单元测试与双端构建结果由主任务另行记录。
