#!/usr/bin/env python3
"""GitHub Actions glue. Called only by scheduled/maintainer-dispatched workflows."""
import json
import os
from pathlib import Path
import subprocess
import sys

REPORT = Path('.build/official-pricing/report.json')
MARKER = '<!-- gudeng-official-pricing-monitor -->'


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def api(endpoint, payload=None, method=None):
    args = ['gh', 'api', endpoint]
    if payload is not None:
        file = REPORT.parent / 'github-payload.json'
        file.write_text(json.dumps(payload, ensure_ascii=False))
        args += ['--method', method or 'POST', '--input', str(file)]
    return json.loads(run(*args))


def main():
    report = json.loads(REPORT.read_text())
    repo = os.environ['GITHUB_REPOSITORY']
    if sys.argv[1] == 'notify':
        issues = api(f'repos/{repo}/issues?state=open&per_page=100')
        existing = next((i for i in issues if 'pull_request' not in i and MARKER in (i.get('body') or '') and i['user']['login'] == 'github-actions[bot]'), None)
        if report['status'] == 'unchanged':
            if existing:
                api(f"repos/{repo}/issues/{existing['number']}", {'state': 'closed'}, 'PATCH')
            return
        notify_digest = report.get('notificationDigest') or report['digest']
        state_marker = f"<!-- observation-state:{notify_digest}:{report['status']} -->"
        if existing and state_marker in (existing.get('body') or ''):
            return
        body = MARKER + '\n' + state_marker + '\n' + (REPORT.parent / 'report.md').read_text() + '\n\n请核对官方生效时间；不要把观察时间当生效时间。已知单价变化可用Official pricing workflow的prepare模式生成草稿PR；语义/结构变化须人工处理。'
        payload = {'title': 'DeepSeek 官方计价需要复核', 'body': body}
        if existing:
            api(f"repos/{repo}/issues/{existing['number']}", payload, 'PATCH')
        else:
            api(f'repos/{repo}/issues', payload)
    elif sys.argv[1] == 'pull-request':
        prefix = 'codex/official-pricing-' + report['digest'][:12]
        prs = json.loads(run('gh', 'pr', 'list', '--repo', repo, '--state', 'open', '--limit', '100', '--json', 'url,headRefName'))
        existing = next((p for p in prs if p['headRefName'].startswith(prefix)), None)
        if existing:
            print('已有同摘要候选，未覆盖；如需更正生效时间请审阅现有PR：' + existing['url'])
            return
        suffix = ''.join(c for c in report['checkedAt'][:19] if c.isdigit())
        branch = prefix + '-' + suffix
        run('git', 'switch', '-c', branch)
        run('git', 'config', 'user.name', 'github-actions[bot]')
        run('git', 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
        run('git', 'add', 'Rules/pricing.json', 'Rules/manifest.json', 'Packages/Gudeng/Tests/GudengCoreTests/RuleBundleTests.swift', 'docs/product/requirements.md', 'CHANGELOG.md')
        run('git', 'commit', '-m', 'rules: prepare verified official price update')
        run('gh', 'auth', 'setup-git')
        run('git', 'push', '--set-upstream', 'origin', branch)
        body = REPORT.parent / 'pull-request.md'
        body.write_text('## 改了什么\n\n官方单价候选；仅更新已知模型计费值、来源核对时间、manifest/校验和、独立快照与产品文档。\n\n## 为什么\n\n维护者已确认观察摘要与官方生效依据，时段语义指纹未变。\n\n## 如何验证\n\n规则完整性、测试和lint已通过；人工仍需复核实际生效时刻与风险。\n\n## 平台与限制\n\n草稿不会自动合并或发布；合并后沿用Rules工作流发布。未更改日历、提醒策略或用户偏好。\n\n' + (REPORT.parent / 'report.md').read_text())
        print(run('gh', 'pr', 'create', '--repo', repo, '--base', os.environ.get('DEFAULT_BRANCH', 'main'), '--head', branch, '--draft', '--title', 'rules: verified DeepSeek official price candidate', '--body-file', str(body)))
    else:
        raise SystemExit('unknown mode')


if __name__ == '__main__':
    main()
