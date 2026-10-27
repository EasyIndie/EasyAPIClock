# 安装版设置功能验收

2026-10-27，macOS27.0.1 arm64。实际应用路径为 `/Applications/谷蹬.app`，Developer ID签名，本地安装未公证。首轮PID8058，修复版PID9524，最后通过Finder重新打开后PID11347。未修改系统通知权限、Focus、系统音量、系统登录会话或规则数据；没有执行注销/重登录。

## 安装与图形启动：通过

- 在设置中正常点击“退出谷蹬”，确认9524进程退出。
- 仅用`open -R`让Finder选中`/Applications/谷蹬.app`，Finder前台窗口标题为“应用程序”；随后在Finder使用图形界面打开快捷键Command-O。
- 新进程为11347，实际执行路径`/Applications/谷蹬.app/Contents/MacOS/LiangWenMac`；仅一个实例，最终展开334×322pt主面板。不是从终端直接执行二进制，也没有给这次Finder启动注入诊断环境变量。
- 证据：`15-finder-launch.json`、`15-finder-launched-main.png`。未保留无关应用列表或桌面截图。

## 登录启动：注册/注销路径通过；实际重登录未验

- 首轮即使安装到Applications仍显示“当前应用无法注册登录启动，请检查安装位置。”，登录Toggle的AX enabled=false/value0。见`02-general-retry.json/png`。
- 修复版登录Toggle已enabled=true/value0。真实点击后变1，未出现审批或失败文案；再点击恢复0，仍可操作。见`07-login-roundtrip.json`、`07-login-enabled.png`、`08-login-restored.png`。
- 本轮证明应用的用户注册/注销路径可用，不等于已经验证系统重新登录后的自动启动。未替用户保留开启状态，最终恢复原先关闭。

## 提醒预览：实际系统返回有送达记录；可见横幅/声音仍未证实

- 原偏好为强提醒、提前提醒开启、系统外观、动效开启、自动更新开启，测试未改变这些偏好。
- 首轮与修复版均有UI响应：点击后变“立即停止预览”并显示最多三次/10秒说明，随后显示“预览已结束”。`10-fixed-preview-running.png`、`11-fixed-preview-ended.png`为修复版窗口截图。
- `preview-before-fix.jsonl`和`preview-fixed.jsonl`是实际系统返回的原始诊断。两轮均观察到预览ID的`.0`、`.2`送达记录；结束后预览pending/delivered均空，正式pending数量保持7。本轮没有证据宣称三条全部均送达。
- 修复版系统设置返回：authorization=authorized、alerts=enabled、notificationCenter=enabled、sound=enabled、style=banner。这些设置开启仍不能替代实际看到横幅或听到声音的证明。
- 同一JXA中点击后直接等待2秒，未先遍历AX，立即抓取主显示器右上`[1040,32,400,240]`区域；该区域截图全黑，没有有效屏幕像素，不能据此认定“没有通知”。黑图仅留临时目录，未提交无效图或无关桌面内容；未为截屏修改系统权限，也未继续无限重试。
- 本轮不能确认用户实际可见横幅、可听见声音或Focus对呈现的影响。源头排程/系统记录/结束清理已证实，呈现限制保持如实记录。

## 自动更新：真实尝试记录可见；手动查询链路通过

- 通用组读取到自动更新开启，实际显示“上次尝试：2026-10-27 07:40 · 北京时间”，并解释六小时最多一次。见`06-fixed-general.json`。
- 没有清空defaults、伪造记录、修改系统时间或缩短六小时间隔以人为触发自动检查。本轮未等待新的六小时自动窗口，不能把历史尝试记录当作本轮新自动HTTP请求。
- 只点击一次“检查规则更新”，真实结果为“已是最新规则包2026.10.23。”；见`12-manual-rule-check.json/png`。这是配置源查询的手动链路验证，不等同于自动触发或新包下载/替换验证。

## 页面切换动效：说明与原值已确认；动态时序未作视觉通过声明

- 实际外观组显示“页面切换动效”，说明“控制主面板与设置页切换的淡入淡出；系统减少动态效果优先。”，开关保持原值1。见`13-motion-and-main.json`、`13-motion-explanation.png`。
- 只读NSWorkspace返回reduceMotion=false、reduceTransparency=false，见`system-accessibility.json`；未修改系统偏好。
- 没有可靠的开/关对比录像，因此静态截图不用于声称动画时序视觉验收通过。本轮只确认实际可见说明、原偏好及主/设置导航正常。

## 最终状态

登录启动关闭；系统外观、动效开启、强提醒、提前提醒开启、自动更新开启均保持原偏好。预览已自动结束并清理，未改变正式通知计划数量。最终通过Finder普通打开安装版，只保留PID11347一个实例，并返回主面板。
