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
2. 预检：仅 `main` 分支、工作区必须干净
3. `git fetch + git pull --ff-only origin main`
4. 执行 `make p15-all`
5. 失败则 `git reset --hard <pre_head>` 自动回滚
6. 通过 `openclaw message send` 发 Telegram 通知

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
- 依赖 `openclaw message send` 可用；若通知发送失败，不影响回滚与主流程。
