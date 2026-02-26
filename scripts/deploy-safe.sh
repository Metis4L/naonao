#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
DEPLOY_CMD="${DEPLOY_CMD:-make p15-all}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-5667549865}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-telegram}"
DIRTY_MODE="${DIRTY_MODE:-warn}"   # block | warn
LOCK_FILE="${LOCK_FILE:-/tmp/openclaw_deploy.lock}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/.deploy-logs}"
DEPLOY_WORKTREE="${DEPLOY_WORKTREE:-/home/metis/.openclaw/deploy-worktree}"
STATE_FILE="${STATE_FILE:-$REPO_ROOT/projects/naonao-content-ops/.deploy/last_success_head}"
MAX_COMMITS="${MAX_COMMITS:-20}"
HOST_NAME="$(hostname)"

mkdir -p "$LOG_DIR" "$(dirname "$STATE_FILE")"
RUN_TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/deploy-$RUN_TS.log"

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

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  notify "skip" "deploy skipped (locked) host=$HOST_NAME branch=$DEPLOY_BRANCH"
  echo "[deploy] skipped: lock held" | tee -a "$LOG_FILE"
  exit 0
fi

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

ensure_worktree_at_head() {
  local head="$1"

  if [[ ! -e "$DEPLOY_WORKTREE/.git" ]]; then
    mkdir -p "$(dirname "$DEPLOY_WORKTREE")"
    run git worktree add --force "$DEPLOY_WORKTREE" "$DEPLOY_BRANCH"
  fi

  run git -C "$DEPLOY_WORKTREE" fetch origin "$DEPLOY_BRANCH"
  run git -C "$DEPLOY_WORKTREE" checkout -B "$DEPLOY_BRANCH" "$head"
  run git -C "$DEPLOY_WORKTREE" reset --hard "$head"
  run git -C "$DEPLOY_WORKTREE" clean -fd
}

build_commit_summary() {
  local old="$1"
  local new="$2"

  local all_count=0
  if [[ -n "$old" ]]; then
    all_count="$(git rev-list --count "${old}..${new}" 2>/dev/null || echo 0)"
  fi

  local summary=""
  if [[ -n "$old" && "$all_count" -gt 0 ]]; then
    mapfile -t lines < <(git log --oneline "${old}..${new}")
    local shown=0
    for l in "${lines[@]}"; do
      summary+="\n- $l"
      shown=$((shown + 1))
      if [[ "$shown" -ge "$MAX_COMMITS" ]]; then
        break
      fi
    done
    if [[ "$all_count" -gt "$MAX_COMMITS" ]]; then
      local more=$((all_count - MAX_COMMITS))
      summary+="\n- ... +${more} more"
    fi
  else
    summary="\n- (no commits in range)"
  fi

  printf '%s' "$summary"
}

main() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "$DEPLOY_BRANCH" ]]; then
    notify "skip" "当前分支 $branch，非部署分支 $DEPLOY_BRANCH，跳过。"
    exit 0
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    if [[ "$DIRTY_MODE" == "block" ]]; then
      notify "blocked" "工作区有未提交改动，已阻止自动部署。"
      exit 1
    fi
    notify "warn" "工作区有未提交改动，按 DIRTY_MODE=warn 继续；构建在独立 worktree。"
  fi

  local pre_head post_head
  pre_head="$(git rev-parse HEAD)"

  run git fetch origin "$DEPLOY_BRANCH"
  run git pull --ff-only origin "$DEPLOY_BRANCH"
  post_head="$(git rev-parse HEAD)"

  if [[ "$pre_head" == "$post_head" ]]; then
    notify "ok" "Deploy 状态：success | env=${HOST_NAME}/${DEPLOY_BRANCH} | 范围：no-change | 日志：$LOG_FILE"
    exit 0
  fi

  ensure_worktree_at_head "$post_head"

  if ! (cd "$DEPLOY_WORKTREE" && bash -lc "$DEPLOY_CMD") 2>&1 | tee -a "$LOG_FILE"; then
    rollback "$pre_head" "$post_head"
    notify "failed" "Deploy 状态：fail | env=${HOST_NAME}/${DEPLOY_BRANCH} | 范围：${pre_head}..${post_head} | 回滚：${pre_head} | 日志：$LOG_FILE"
    exit 1
  fi

  local old_success=""
  if [[ -f "$STATE_FILE" ]]; then
    old_success="$(cat "$STATE_FILE" | tr -d '\n')"
  fi
  if [[ -z "$old_success" ]]; then
    old_success="$pre_head"
  fi

  local commit_summary
  commit_summary="$(build_commit_summary "$old_success" "$post_head")"

  echo "$post_head" > "$STATE_FILE"

  notify "ok" "Deploy 状态：success | env=${HOST_NAME}/${DEPLOY_BRANCH} | 范围：${old_success}..${post_head} | commits:${commit_summary} | 日志：$LOG_FILE"
  echo "[deploy] success" | tee -a "$LOG_FILE"
}

main "$@"
