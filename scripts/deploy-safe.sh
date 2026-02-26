#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
DEPLOY_CMD="${DEPLOY_CMD:-make p15-all}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-5667549865}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-telegram}"
LOCK_FILE="${LOCK_FILE:-$REPO_ROOT/.deploy.lock}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/.deploy-logs}"
mkdir -p "$LOG_DIR"
RUN_TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/deploy-$RUN_TS.log"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "[deploy] another deployment is running" | tee -a "$LOG_FILE"
  exit 0
fi

notify() {
  local level="$1"
  local text="$2"
  local msg="[deploy:$level] $text"
  if command -v openclaw >/dev/null 2>&1; then
    openclaw message send \
      --channel "$NOTIFY_CHANNEL" \
      --target "$TELEGRAM_CHAT_ID" \
      --message "$msg" >/dev/null 2>&1 || true
  fi
}

run() {
  echo "+ $*" | tee -a "$LOG_FILE"
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

rollback() {
  local from="$1"
  local to="$2"
  echo "[deploy] rollback: $to -> $from" | tee -a "$LOG_FILE"
  git reset --hard "$from" 2>&1 | tee -a "$LOG_FILE"
}

main() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "$DEPLOY_BRANCH" ]]; then
    notify "skip" "当前分支 $branch，非部署分支 $DEPLOY_BRANCH，跳过。"
    exit 0
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    notify "blocked" "工作区有未提交改动，已阻止自动部署。"
    exit 1
  fi

  local pre_head post_head
  pre_head="$(git rev-parse HEAD)"

  run git fetch origin "$DEPLOY_BRANCH"
  run git pull --ff-only origin "$DEPLOY_BRANCH"
  post_head="$(git rev-parse HEAD)"

  if [[ "$pre_head" == "$post_head" ]]; then
    notify "ok" "无新提交，部署未执行。HEAD=$post_head"
    exit 0
  fi

  if ! bash -lc "$DEPLOY_CMD" 2>&1 | tee -a "$LOG_FILE"; then
    rollback "$pre_head" "$post_head"
    notify "failed" "部署失败，已回滚到 ${pre_head:0:8}。日志: $LOG_FILE"
    exit 1
  fi

  notify "ok" "部署成功 ${pre_head:0:8} -> ${post_head:0:8}，命令: $DEPLOY_CMD"
  echo "[deploy] success" | tee -a "$LOG_FILE"
}

main "$@"
