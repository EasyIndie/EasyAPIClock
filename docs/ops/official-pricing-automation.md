# 官方价格观察与候选更新操作

## 两条独立链路

客户端：已开启自动更新时，每6小时最多一次拉取仓库已发布JSON包，失败继续用有效旧包。

维护者CI：Official pricing工作流每小时观察DeepSeek官方页，比较当前Rules及已核对的语义指纹。当前分支仅实现配置；**合并默认分支后定时任务才生效**，不是本轮已启动的远程监控。GitHub调度不保证准点，审核前客户端仍使用原有效包。

## 日常观察

```sh
python3 Scripts/official_pricing.py observe
make test-source-monitor
```

报告位于.build/official-pricing/report.json及report.md，包含真实观察时间、价格事实、摘要、当前pricing指纹和状态：

| 状态 | 行为 |
|---|---|
| unchanged | 不生成规则，不重复通知；可关闭已恢复的bot复核issue |
| prices-changed | 已知模型/计费项/语义下的单价差异，可进一步确认 |
| review-required | 时段、模型、倍率或仓库语义有变化；不自动生成 |
| unrecognized | 网络/结构/币种/缺失数据异常；保留旧规则并复核 |

语义基线在official-pricing-baseline.json，仅维护者核对官方策略后修改。不得为“消除告警”直接改hash。Search/Fetch独立按次收费，不纳入模型峰谷包；日历也不从价格页面推测。

## 生成价格候选

1. 打开报告与官方原文，确认金额、人民币/百万Tokens、所有计费项以及时段仍相同。
2. 核实官方生效时间。页面抓取时间、HTTP日期、模型版本日期都不能代替生效时间；官方未明确时，先复核，不填猜测值。
3. 从Actions手动运行Official pricing，mode=prepare，提供报告精确digest、官方生效时间（带+08:00）与api-docs.deepseek.com官方依据链接。
4. 工作流重新抓取；如果来源已再次变更、当前Rules已不同或语义无法确认则停止。成功后生成完整候选、通过验证和测试再创建草稿PR。
5. 审核规则、独立快照/产品价格表、有效期、checksum和风险。没有自动合并；合并main后既有Rules工作流发布。

本地同等命令（需要先完成上述核实，不应直接照填示例时间）：

```sh
python3 Scripts/official_pricing.py prepare \
  --expected-digest "$VERIFIED_OBSERVATION_DIGEST" \
  --effective-from "$VERIFIED_OFFICIAL_EFFECTIVE_TIME" \
  --evidence "$VERIFIED_OFFICIAL_EVIDENCE_URL"
```

prepare不接受--html，避免把本地测试夹具当官方来源。不会更新周历、日历或提醒偏好。超出2026日历覆盖需先完成官方日历维护；未知策略需独立需求/ADR。

## GitHub权限

观察job只读contents并写一个bot issue；相同摘要/状态不重复更新，不触碰人工issue或PR。候选job需要contents/pull-requests写权限，仍由有权限的维护者明确调度。仓库须允许GitHub Actions创建PR；若403则保留报告并明确失败，不自动换高权限PAT或调整保护规则。禁止直接写rules分支、自动合并、自动批准或发布Release。

## 本轮核验

2026-10-27官方HTML实际观察结果unchanged，与当前内置价格一致，所以**真实Rules未修改**。另在隔离临时仓库用明确标记的合成0.03/0.06价格演练prepare，规则完整性与77项Swift测试通过；这些数值仅是测试，绝非官方新价。10项Python离线测试不联网。来源页面与GitHub调度依据见ADR-0012。
