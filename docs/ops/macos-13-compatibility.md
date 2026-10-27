# macOS 13 兼容准备

核对日期：2026-10-26。当前已推送基线：`da496a8`。该段为准备阶段历史；本轮正式代码已降至macOS13.0 / iOS17.0。


## 最新状态：代码适配完成，macOS13 Intel基础运行已验证

- 工程与SwiftPM最低目标均为macOS13.0，iOS仍为17.0。
- Kit的ClockModel改为ObservableObject/@Published，借入模型的视图显式@ObservedObject；LoginSettingsContent独立订阅登录控制器，避免嵌套更新遗漏。Runtime不依赖Combine，业务流程未随UI观察技术重写。
- make check通过73项测试、模块边界、规则校验、lint及双端构建。
- Release通用构建通过；Info.plist与arm64、x86_64的Mach-O最低系统均为13.0。verify-mac-build.py反向指定14.0时按预期拒绝，确认元数据断言生效；CI执行相同校验。
- 当前主机macOS27.0.1 arm64已启动新版；当前系统界面回归见macos13-adapter记录。现已通过SSH连接pro（macOS13.7.8 x86_64），通用Release已原生启动，菜单栏和设置基础路径可用；详细结果见macos13-intel记录。系统true和独立编译的x86_64小程序都返回Bad CPU type，且无Rosetta安装收据；本机未执行Intel启动；Intel原生启动改由pro真机验证，没有自动安装Rosetta。
- macOS13 Intel的菜单栏与设置已有基础证据；macOS13 arm64、登录启动和通知完整矩阵仍须实测，通用二进制编译通过不能替代这些证据。

构建证据：`docs/design/verification-2026-10-26/macos13-adapter/build-metadata.json`。当前工作完成代码及构建阶段，平台运行验收门槛继续保留。

## 已做的编译审计

在临时目录复制Packages/Gudeng（排除构建产物），仅把Package.swift的.macOS(.v14)改为.v13，运行：

```sh
swift build --package-path <临时包目录> --target GudengKit
```

编译命令确认目标为arm64-apple-macosx13.0。结果失败，去重后的关键诊断：

```text
'Observable()' is only available in macOS 14.0 or newer
'ObservationIgnored()' is only available in macOS 14.0 or newer
'ObservationRegistrar' is only available in macOS 14.0 or newer
'ObservationTracked()' is only available in macOS 14.0 or newer
```

涉及ClockModel.swift与LoginItemController.swift。随后仅在临时副本移除上述宏，把两个类声明为系统Combine ObservableObject，再编译GudengKit，结果成功（5.93秒）。该试验没有补@Published与视图订阅，因此只能用于暴露其他编译阻塞，**不是完整兼容实现**。正式源码和运行应用未因此改变。

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
| macOS13.7.8 x86_64（pro） | 本地交叉构建已验证；远端仅CLT | 原生启动、菜单栏刷新、设置AX和偏好跨重启已验；截图受限 | 临时安装禁用；重登录未验 | 完整矩阵待验 | 基础运行通过 |
| macOS27.0.1 arm64 | 13目标双端及通用构建通过 | 新版已启动；观察适配AX回归记录已保存 | 稳定安装待验 | 正式矩阵未完 | 基础回归通过 |
| iOS17最低目标 | 现有构建已通过 | 仍是只读外壳 | 不适用 | 未设计 | 保持现状 |

本地测试机器为macOS27；新增pro为macOS13.7.8 Intel，平台证据分别记录。没有下载系统镜像、创建VM或改变当前系统设置。

## ADR-0011分层后的增量验证

共享业务已迁入无Observation依赖的GudengRuntime，ClockModel变为Kit中的薄观察适配器。对本次工作区复制到独立临时目录，仅将Package.swift设为macOS13，再执行 `swift build --target GudengRuntime`，退出0。它证明共享Runtime在13部署目标下可编译，不代表整个Kit、应用启动、登录项或通知已完成macOS13验收。

后续ADR-0010迁移范围相应缩小：ClockModel只需替换值状态的观察桥接，LoginItemController及其视图订阅仍需处理；业务会话无需随UI观察技术重写。
