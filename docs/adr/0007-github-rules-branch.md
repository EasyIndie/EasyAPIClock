# ADR-0007：用 GitHub `rules` 分支托管规则包

- 状态：已接受
- 日期：2026-10-23
- 决策者：项目维护者

## 背景

规则包需要稳定的 HTTPS 地址。项目已经开源并托管在 GitHub，不想再引入对象存储、CDN 或独立规则服务。

直接让客户端读取 `main/Rules` 最简单，但会绕过发布门禁：主分支可能包含未通过校验的规则、文档改动或未完成的实验；客户端不应该读到这些内容。需要一个“只有校验通过才对外”的稳定地址。

## 决策

1. `Rules/` 在主分支上是规则数据的唯一源。
2. `.github/workflows/rules.yml`：
   - PR / 主分支上涉及 `Rules/**`、`LiangWenCore` 或发布脚本的改动，先执行 `make validate-rules` 与 `make test`；
   - 主分支校验通过后，运行 `Scripts/publish-rules.sh`。
3. `Scripts/publish-rules.sh`：
   - 再次校验规则包；
   - 要求 `publishedAt` **严格晚于** `rules` 分支当前版本；完全相同视为已发布（幂等），更旧则失败；
   - 把 `Rules/` 内容做成 **orphan 快照**（规则文件位于分支根目录），强制推送到 `rules` 分支；
   - 不保留 `rules` 分支历史；主分支保留完整规则变更历史。
4. 应用默认规则源：
   ```
   https://raw.githubusercontent.com/wangzhizhou/liangwen-clock/rules
   ```
   配置在 `project.yml` 的 `LiangWenRuleSourceBaseURL`。
5. `rules` 分支是生成物，**禁止手工编辑**；只能由发布脚本或 Rules workflow 写入。
6. 仍然只做 SHA-256 完整性校验，没有数字签名。信任根是 HTTPS、仓库控制权与 GitHub Actions 权限。

## 后果

正面：

- 不增加托管设施；公开仓库的标准 GitHub Actions 免费。
- 客户端只看到已通过校验和测试的规则快照。
- 地址稳定，manifest 与三个文件同源同目录，原子替换语义不变。
- 主分支可以包含进行中的规则改动，而不会立即影响用户。
- 发布可重复：同一提交重跑 workflow 不会产生重复版本。

代价：

- 依赖 GitHub 与 `raw.githubusercontent.com` 的可用性。
- raw CDN 可能缓存数分钟；发布后客户端不一定立刻看到新版本。
- 没有灰度/金丝雀；`rules` 分支一次只有最新版本。
- 强制推送使 `rules` 分支没有可审计的逐步历史（主分支有）。
- 私有仓库的 raw 地址需要认证，当前客户端不支持 token；此方案要求仓库公开。
- 发布 job 需要 `contents: write`；必须保持最小权限（只有 publish job 获得写权限）。

## 备选方案

- **直接读 main**：最简单，但没有发布门禁，且地址包含 `Rules/` 路径；客户端可能读到未验证内容。
- **GitHub Pages**：同样依赖仓库，但需要额外 Pages 配置；CDN 缓存行为类似。
- **GitHub Release 资产**：可以带版本与签名，但稳定地址需要移动 tag 或每次改客户端 URL；运维成本更高。
- **独立规则仓库**：隔离性更好，但多一套权限、CI 与同步流程。
- **对象存储/CDN**：可控缓存与灰度，但引入账号、费用和部署脚本。

## 后续

1. 为 manifest 增加 Ed25519 签名（见 ADR-0004），解决“源被控制”时 SHA-256 无法证明发布者的问题。
2. 实测 raw CDN 的传播时延，并在设置中明确“检查更新可能延迟数分钟”。
3. 评估 `rules-next` 金丝雀分支：先发布到下一分支，验证后再提升；首版不做。
4. 评估 GitHub Rulesets，限制只有 Actions bot 能写 `rules` 分支（需确认不会阻塞发布 job）。
5. 若仓库转私有，需要为客户端增加带认证的规则获取方式，或改用公开的独立规则仓库。
