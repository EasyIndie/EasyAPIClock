# 菜单栏与设置精确对齐验收

日期：2026-10-27，macOS27.0.1 arm64，2×实际屏幕截图。本目录延续2026-10-26验收，保留原目录日期以便追踪。最终运行PID2862，窗口334×322pt。

## 最终结果

- 菜单栏：图标与中文字「谷」的像素包围盒中线一致，差0px。
- 提醒强度：三段各50pt，可见右边缘与内容线一致，差0px。
- 展开外观后的显示模式：三段各50pt，可见右边缘同样一致，差0px，末端圆角完整，无裁切。
- 新适配器的target/action有效：真实点击浅色后，选中态与整个面板同步变为浅色，随后已恢复原系统外观。提醒强度、提前提醒等业务偏好未改；未触发预览、通知权限或规则更新。
- 最后已折叠外观并返回主面板，窗口仍为334×322pt。

最终截图：`delivery-settings.png`（默认）、`delivery-appearance.png`（展开外观）、`after-menubar.png`（菜单栏）、`callback-appearance.png`（临时浅色回调验证，非最终偏好）。

## 像素量测

`before-menubar.png`：绿色圆bbox y8…40，中线24；中文字「谷」y11…33，中线22，图标低2px（1pt）。只修改NSImage.alignmentRect没有生效。

`after-menubar.png`：保持原20pt画布、向上绘制1pt后，圆bbox y6…38、中线22；谷字仍中线22，差0px。箭头完整，没有纯圆回归。

最终设置内容线右边缘为x627（包围盒包含端点，截图宽668px）。默认提醒强度绿色bezel右边缘为627；展开态提醒仍为627，显示模式灰色bezel也为627。新NSSegmentedControl实际布局框150×24pt，fillEqually均分，AX各段均为50×24pt。

`measure.py`只读分析截图与AX，需要Pillow；`measurements.json`保存包围盒和差值，可执行脚本复核。菜单量测只比较圆和「谷」字，不将整段数字的升降部混入中文字中心。

## 失败方案与截图限制

`failed-natural-settings.png`记录此前SwiftUI Picker自然宽度方案：可见右边缘635，比内容线627多8px（4pt），AX布局129pt、三个原生段50/50/37pt。4pt补偿又曾在展开布局稳定为150pt后向内留4pt，因此最终没有保留这些偏移修补，而是采用系统NSSegmentedControl薄适配器。

`invalid-region-capture.png`为明确无效的区域合成/坐标错位帧，不是产品画面。区域截图也偶有原生控件条带错位，未以其判定通过。最终两张设置图改为同一JXA中读取本应用onscreen CGWindowID并执行screencapture -l -o，完整窗口捕获；文件写完并确认668×644像素后再检查。

中间状态JSON仍保留为几何记录，重复整窗PNG已清理；不是所有中间JSON都对应保留PNG。最终结论只对应delivery与after-menubar文件，不沿用失败或无效截图。

本轮仅在当前macOS27上验收新控件；macOS13的新UI运行与原生控件外观仍未复测，不能由部署目标13或当前系统截图推断已完成旧系统验收。
