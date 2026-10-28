# ADR-0012：官方价格观察与经确认的候选规则

- 状态：已接受
- 日期：2026-10-27
- 依据：用户要求及时获取DeepSeek官方策略并评估CI自动更新。

## 决策

维护者侧GitHub Actions每小时第17分钟观察官方HTTPS价格页。客户端继续只下载已校验JSON规则，不抓HTML，不改变六小时客户端节流。

解析器仅认识已确认的两模型、三计费项、人民币/百万Tokens表格；展开rowspan/colspan，校验正数、完整性、峰谷标签、模型集合及当前2倍关系。规范化文本指纹约束官方时段说明；仓库时区/单位/时段也有独立语义指纹。样式或小数显示变化不当作改价，Search/Fetch不属于模型价格范围。页面未知、网络失败、模型/时段语义变化只要求复核，不写规则。

发现差异时维护一个可去重的bot issue和报告artifact，不反复通知相同状态。观察时间不等于生效时间。维护者必须通过workflow_dispatch明确提供已核实的观察摘要、官方生效时刻（+08:00）及官方依据，prepare重新抓取同一HTTPS来源，拒绝本地HTML输入。

仅在已知单价变动且语义未变时生成候选：更新pricing、递增manifest发布记录、三文件checksum、独立金额/版本快照、产品价格表和Changelog；保留日历、时段及提醒策略。校验、测试、lint通过后建立草稿PR，不自动合并或绕过保护。合并后仍由既有Rules工作流发布，不直接编辑rules分支。

## 边界与验证

- HTTPS官方主机白名单、响应体上限、无脚本执行或远程表达式；GITHUB_TOKEN仅在需要的GitHub步骤提供，观察job只有读源码/写issue，候选job仅受维护者显式调度。
- 生效日超出日历覆盖、摘要不符、基线已变、时段语义未知、任何校验失败均停止候选。不能只改指纹让错误通过；语义变化需单独复核需求/引擎/日历。
- 14项标准库离线测试覆盖提取、去重、格式、失败、语义漂移、时间/摘要门槛、候选文件范围，以及更新日志/公告上下文与首轮基线；隔离临时仓库的合成单价变更已通过完整Swift规则校验和77项测试，未写真实Rules。
- GitHub定时任务只在默认分支生效，可能延迟或被平台停用；客户端还有节流与离线因素，不承诺实时同步。私有仓库套餐、Actions的PR创建权限及branch protection需维护者配置，不自动提升权限。

来源：DeepSeek https://api-docs.deepseek.com/zh-cn/quick_start/pricing/ （2026-10-27核对）；GitHub https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onschedule 。
