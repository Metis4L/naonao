# 最小安全部署流（本地 WSL）

## 已配置参数
- repo: `https://github.com/Metis4L/naonao.git`
- branch: `main`
- deploy dir: `/home/metis/.openclaw/workspace`
- deploy cmd: `make p15-all`
- notify: `telegram -> 5667549865`
- rollback: `enabled`
- trigger: `B (git pull/merge 后自动触发)`

## 流程
1. `post-merge` hook 触发 `scripts/deploy-safe.sh`
2. 预检：仅 `main` 分支（工作区脏改动按 `DIRTY_MODE` 处理）
3. `git fetch + git pull --ff-only origin main`
4. 在独立 worktree（默认 `/home/metis/.openclaw/deploy-worktree`）执行 `make p15-all`
5. 失败则 `git reset --hard <pre_head>` 自动回滚
6. 生成可追溯通知（状态/env/范围/commit列表/回滚/日志）并发 Telegram
7. 成功后写入 `projects/naonao-content-ops/.deploy/last_success_head`

## 手动执行
```bash
bash scripts/deploy-safe.sh
```

## 日志
- 目录：`.deploy-logs/`
- 文件：`deploy-YYYYmmdd-HHMMSS.log`

## 注意
- 工作区脏改动策略由 `DIRTY_MODE` 控制：
  - `warn`（默认）：仅告警，不阻断部署
  - `block`：阻断部署
- 可临时切换：`DIRTY_MODE=block bash scripts/deploy-safe.sh`
- 部署锁默认：`/tmp/openclaw_deploy.lock`，拿不到锁会通知 `deploy skipped (locked)`。
- Telegram 消息长度保险丝：`MAX_TG_CHARS=3500`（默认）。
  - Level 0：完整消息（最多 20 条 commit）
  - Level 1：降级为最多 10 条 commit + `+N more`
  - Level 2：短消息（状态/env/range/commit数/top3/本地复现命令）
- 本地复现命令模板：`git -C <repo> log --oneline <old>..<new>`
- 通知发送失败自动重试最多 3 次（`NOTIFY_RETRY_MAX=3`）。
- 依赖 `openclaw message send` 可用；若通知最终失败，不影响回滚与主流程。
