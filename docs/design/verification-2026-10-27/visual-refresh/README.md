# Build2 视觉与维护流程验收

2026-10-27，macOS 27.0.1 arm64，正常启动的 `/Applications/谷蹬.app`，Developer ID 本地签名。最终安装包含日期完整显示与折叠标题不缩放修正。

- `root-light-main.png`、`root-dark-main.png`：真实峰期，334×322pt；DeepSeek API / 北京时间标识、带单位时长及设置/退出入口完整。
- `root-light-settings.png`：浅色设置与外观选项。
- `root-dark-all-top/middle/bottom.png`：三个分组全部展开，分段/开关靠右，解释靠左，最近自动检查时间居中；详情可滚动。
- `root-dark-rule-card.png`：整张规则卡，标题/来源/社区声明居中，版本/日期键值左右对齐，两侧核对日期分列。覆盖日期完整，没有省略号。
- `root-restored-settings/main.png`：结束时恢复系统外观、收拢分组并返回主面板。业务开关未改动；动效维持开启。

早期自动脚本误把滚动后屏幕外控件当作可见点击目标，浮层收起；后改用可访问性控件点击并先归零滚动完成复测。`limitations.json` 保留早期失败记录，不代表最终验收状态。

## 验证范围

`make check` 通过：77 项 Swift Testing、10 项离线来源监测测试、规则校验、分层、格式及 macOS/iOS 构建。Release arm64/x86_64 均通过最低 macOS 13.0 元数据检查。临时隔离仓库中的合成价格候选成套校验和 77 项测试通过，未修改真实 Rules。

`official-observation.json` 为实际 HTTPS 观察，官方当前价格未变化。CI 在合并到默认分支后才启用定时任务，本轮没有触发线上规则发布。

有限入场、数值切换、页面过渡、折叠与预览反馈由动效偏好/系统减少动态效果共同控制；本轮静态截图不证明逐帧动画或减少动态效果系统路径。当前真实状态为峰期，未伪造谷期截图；macOS 13 本轮未做新版动态效果真机复测。
