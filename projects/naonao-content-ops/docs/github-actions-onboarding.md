# GitHub Actions 接入（P1）

## 已添加
- Workflow: `.github/workflows/p0-guard.yml`
- 作用：在 PR / push(main) / 手动触发时执行 `make p15-all`，并做 baseline guard 检查（含顾问层产物）。

## 触发后做什么
1. advisor plan compile（生成 work-order/plan/decision）
2. preflight root check
3. JSON batch validate
4. shadow monitoring snapshot
5. baseline guard: `current_baseline.iter_id` 必须保持 `iter6`

## 你需要做的 GitHub 配置

### 1) 连接远程仓库并推送
```bash
cd /home/metis/.openclaw/workspace

git remote -v
# 若还没有 origin：
# git remote add origin <YOUR_GITHUB_REPO_URL>

git checkout -b chore/ide-migration-p1

git add .github/workflows/p0-guard.yml \
  projects/naonao-content-ops/docs/github-actions-onboarding.md \
  projects/naonao-content-ops/docs/advisor-ide-p15.md \
  projects/naonao-content-ops/tools/advisor-compile-plan.py \
  projects/naonao-content-ops/handovers/brief.template.md \
  Makefile .vscode/tasks.json

git commit -m "ci: add p0 guard workflow for IDE+OpenClaw auto pipeline"

git push -u origin chore/ide-migration-p1
```

### 2) 发起 Pull Request
- 从 `chore/ide-migration-p1` -> `main`
- 确认 `P0 Guard (IDE + OpenClaw)` 通过

### 3) 设置受保护分支（推荐）
GitHub 仓库：
- Settings -> Branches -> Branch protection rules -> Add rule
- Branch name pattern: `main`
- 勾选：
  - Require a pull request before merging
  - Require status checks to pass before merging
- 在状态检查中选择：`P0 Guard (IDE + OpenClaw) / p0-guard`

完成后，未通过 guard 的 PR 不能合并。
