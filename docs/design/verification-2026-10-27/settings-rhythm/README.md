# 设置行距与热区验收（Build1间距版）

2026-10-27，实际安装路径`/Applications/谷蹬.app`，开始PID18152。该记录对应本轮间距/热区修改；后续Build2视觉迭代另见visual-refresh目录，不将旧图冒充新版本。

- 主面板gear/power各32×36pt，同一y，间隔8pt。真实点击power退出18152，Finder选中安装应用后Command-O重新打开；新PID21238，执行路径/Applications/谷蹬.app/Contents/MacOS/LiangWenMac，单实例，最终返回主面板。
- 三组header实际AX仍为DisclosureTriangle，SwiftUI保留展开语义；但各行完整294×32pt，折叠时y196/228/260，中心步长均32pt。对每组分别点击标题文字区域展开，再点距右端6pt区域折叠，三组均true→false。规则右端为版本区域，同样响应。没有改业务偏好。
- 一次真实规则检查返回已是最新。按钮86×20pt在y313，短结果192×28pt在y309，中心同为323pt，行底337低于滚动视口底354，默认核心与结果均首屏可见。
- 点击短结果显示完整“已是最新规则包2026.10.23。”popover。鼠标移到标题后popover仍存在，排除只是hover tooltip；点击标题后popover关闭、设置面板保留。未伪造错误或更改真实URL，本轮未产生错误结果，因此没有宣称真实错误popover已验。
- 仅捕获应用窗口ID，未保留无关桌面/应用列表。原始AX与几何汇总见geometry.json及各json。

保留截图：01主面板、03外观展开、06更新同行、08移开鼠标后仍存在的详情、11 Finder重开主面板。其余重复PNG已删除，AX保留。未修改系统权限、用户业务偏好或源码；未提交。
