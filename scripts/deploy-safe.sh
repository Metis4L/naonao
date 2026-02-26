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
MAX_TG_CHARS="${MAX_TG_CHARS:-3500}"
NOTIFY_RETRY_MAX="${NOTIFY_RETRY_MAX:-3}"
HOST_NAME="$(hostname)"

mkdir -p "$LOG_DIR" "$(dirname "$STATE_FILE")"
RUN_TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/deploy-$RUN_TS.log"

exec 9>"$LOCK_FILE"

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

send_with_retry() {
  local level="$1"
  local text="$2"
  local msg="[deploy:$level] $text"

  if ! command -v openclaw >/dev/null 2>&1; then
    return 0
  fi

  local attempt=1
  while (( attempt <= NOTIFY_RETRY_MAX )); do
    if openclaw message send \
      --channel "$NOTIFY_CHANNEL" \
      --target "$TELEGRAM_CHAT_ID" \
      --message "$msg" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  echo "[deploy] notify failed after retries" | tee -a "$LOG_FILE"
  return 1
}

build_commit_list() {
  local old="$1"
  local new="$2"
  local limit="$3"

  local all_count=0
  if [[ -n "$old" ]]; then
    all_count="$(git rev-list --count "${old}..${new}" 2>/dev/null || echo 0)"
  fi

  local summary=""
  local shown=0
  if [[ -n "$old" && "$all_count" -gt 0 ]]; then
    mapfile -t lines < <(git log --oneline "${old}..${new}")
    for l in "${lines[@]}"; do
      summary+="\n- $l"
      shown=$((shown + 1))
      if [[ "$shown" -ge "$limit" ]]; then
        break
      fi
    done
    if [[ "$all_count" -gt "$limit" ]]; then
      local more=$((all_count - limit))
      summary+="\n- ... +${more} more"
    fi
  else
    summary="\n- (no commits in range)"
  fi

  printf '%s' "$summary"
}

build_compare_link() {
  local old="$1"
  local new="$2"
  local remote
  remote="$(git remote get-url origin 2>/dev/null || true)"

  if [[ "$remote" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    printf 'https://github.com/%s/%s/compare/%s...%s' "$owner" "$repo" "$old" "$new"
    return
  fi

  printf ''
}

notify_deploy_result() {
  local level="$1"         # ok | failed
  local host_branch="$2"
  local old="$3"
  local new="$4"
  local rollback_to="$5"
  local all_count="$6"

  local compare_link
  compare_link="$(build_compare_link "$old" "$new")"

  local commit_list_20
  commit_list_20="$(build_commit_list "$old" "$new" "$MAX_COMMITS")"

  local base="Deploy 状态：$level | env=$host_branch | 范围：${old}..${new}"
  local extra=" | 日志：$LOG_FILE"
  local rollback_part=""
  if [[ -n "$rollback_to" ]]; then
    rollback_part=" | 回滚：$rollback_to"
  fi
  local compare_part=""
  if [[ -n "$compare_link" ]]; then
    compare_part=" | compare: $compare_link"
  fi

  # Level 0: full
  local msg0
  msg0="$base | commits:$commit_list_20$rollback_part$compare_part$extra"
  if (( ${#msg0} <= MAX_TG_CHARS )); then
    send_with_retry "$level" "$msg0"
    return
  fi

  # Level 1: truncate commit list to top 10
  local commit_list_10
  commit_list_10="$(build_commit_list "$old" "$new" 10)"
  local msg1
  msg1="$base | commits:$commit_list_10$rollback_part$compare_part$extra"
  if (( ${#msg1} <= MAX_TG_CHARS )); then
    send_with_retry "$level" "$msg1"
    return
  fi

  # Level 2: short fallback + local reproduce command
  local top3
  top3="$(build_commit_list "$old" "$new" 3)"
  local msg2
  msg2="$base | commits: $all_count | top commits:$top3$rollback_part | 复现: git -C $REPO_ROOT log --oneline ${old}..${new}$extra"
  send_with_retry "$level" "$msg2"
}

main() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "$DEPLOY_BRANCH" ]]; then
    send_with_retry "skip" "当前分支 $branch，非部署分支 $DEPLOY_BRANCH，跳过。"
    exit 0
  fi

  if ! flock -n 9; then
    send_with_retry "skip" "deploy skipped (locked) host=$HOST_NAME branch=$DEPLOY_BRANCH"
    echo "[deploy] skipped: lock held" | tee -a "$LOG_FILE"
    exit 0
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    if [[ "$DIRTY_MODE" == "block" ]]; then
      send_with_retry "blocked" "工作区有未提交改动，已阻止自动部署。"
      exit 1
    fi
    send_with_retry "warn" "工作区有未提交改动，按 DIRTY_MODE=warn 继续；构建在独立 worktree。"
  fi

  local pre_head post_head
  pre_head="$(git rev-parse HEAD)"

  run git fetch origin "$DEPLOY_BRANCH"
  run git pull --ff-only origin "$DEPLOY_BRANCH"
  post_head="$(git rev-parse HEAD)"

  if [[ "$pre_head" == "$post_head" ]]; then
    send_with_retry "ok" "Deploy 状态：success | env=${HOST_NAME}/${DEPLOY_BRANCH} | 范围：no-change | 日志：$LOG_FILE"
    exit 0
  fi

  ensure_worktree_at_head "$post_head"

  if ! (cd "$DEPLOY_WORKTREE" && bash -lc "$DEPLOY_CMD") 2>&1 | tee -a "$LOG_FILE"; then
    rollback "$pre_head" "$post_head"
    local fail_count
    fail_count="$(git rev-list --count "${pre_head}..${post_head}" 2>/dev/null || echo 0)"
    notify_deploy_result "failed" "${HOST_NAME}/${DEPLOY_BRANCH}" "$pre_head" "$post_head" "$pre_head" "$fail_count"
    exit 1
  fi

  local old_success=""
  if [[ -f "$STATE_FILE" ]]; then
    old_success="$(cat "$STATE_FILE" | tr -d '\n')"
  fi
  if [[ -z "$old_success" ]]; then
    old_success="$pre_head"
  fi

  local all_count
  all_count="$(git rev-list --count "${old_success}..${post_head}" 2>/dev/null || echo 0)"

  echo "$post_head" > "$STATE_FILE"

  notify_deploy_result "ok" "${HOST_NAME}/${DEPLOY_BRANCH}" "$old_success" "$post_head" "" "$all_count"
  echo "[deploy] success" | tee -a "$LOG_FILE"
}

main "$@"
