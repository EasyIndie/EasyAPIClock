# macOS 13 兼容准备

核对日期：2026-10-26。当前已推送基线：`da496a8`。正式代码仍要求macOS14 / iOS17，本阶段没有降低部署目标。

## 已做的编译审计

在临时目录复制Packages/LiangWen（排除构建产物），仅把Package.swift的.macOS(.v14)改为.v13，运行：

```sh
swift build --package-path <临时包目录> --target LiangWenKit
```

编译命令确认目标为arm64-apple-macosx13.0。结果失败，去重后的关键诊断：

```text
'Observable()' is only available in macOS 14.0 or newer
'ObservationIgnored()' is only available in macOS 14.0 or newer
'ObservationRegistrar' is only available in macOS 14.0 or newer
'ObservationTracked()' is only available in macOS 14.0 or newer
```

涉及ClockModel.swift与LoginItemController.swift。随后仅在临时副本移除上述宏，把两个类声明为系统Combine ObservableObject，再编译LiangWenKit，结果成功（5.93秒）。该试验没有补@Published与视图订阅，因此只能用于暴露其他编译阻塞，**不是完整兼容实现**。正式源码和运行应用未因此改变。

本机Xcode SDK可用性声明还确认MenuBarExtra、scrollIndicators可用于macOS13。菜单栏选定的arrow.up.circle.fill / arrow.down.circle.fill在本机符号元数据中记录最低macOS10.15，当前图标方案无需替换。此审计只涵盖本机SDK下的共享包编译；应用入口、打包元数据、旧系统运行及Intel仍待下一阶段验证。

## 实施顺序

1. 接受并实施[ADR-0010](../adr/0010-macos-13-observation-compatibility.md)：迁移两个模型至ObservableObject/@Published，保持主线程隔离和服务生命周期。
2. 逐个修正ClockPanelView、MainPanelContent、MenuBarStatusLabel、SettingsPanelContent、ReminderSettingsSection、GeneralSettingsSection、SettingsRuleInfoView的订阅；单独处理嵌套LoginItemController。
3. 先补观察更新回归，再同时调整project.yml与Package.swift最低macOS至13.0，iOS17不变。
4. 跑make check，构建Release通用二进制并用lipo和vtool检查架构、部署元数据；保持CI和package-mac的架构断言，调试构建仍为当前架构。
5. 在macOS13完成运行验收，更新README、架构文档、平台矩阵与CHANGELOG后，才宣称支持。

## 运行验收矩阵

| 平台 | 构建 | 启动／菜单栏／设置 | 登录启动 | 通知 | 状态 |
|---|---|---|---|---|---|
| macOS13 arm64 | 待验证 | 待验证 | 待验证 | 待验证 | 未开始 |
| macOS13 x86_64 | 待验证 | 待验证 | 待验证 | 待验证 | 未开始 |
| 当前macOS arm64 | 现有14目标已通过 | 现有界面已有记录，迁移后需复测 | 稳定安装待验 | 预览已验，正式矩阵未完 | 兼容迁移后重验 |
| iOS17最低目标 | 现有构建已通过 | 仍是只读外壳 | 不适用 | 未设计 | 保持现状 |

测试机器当前为macOS27，不能证明macOS13上的启动、通知或登录项行为。没有下载系统镜像、创建VM或改变当前系统设置。
