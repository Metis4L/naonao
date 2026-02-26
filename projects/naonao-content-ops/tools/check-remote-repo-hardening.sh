#!/usr/bin/env bash
set -euo pipefail

# Local hardening checks that can run without remote admin privileges.
# Usage: bash tools/check-remote-repo-hardening.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/3] Secret pattern grep in tracked files"
git grep -nE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----)' -- . || true

echo "[2/3] Tracked .env files"
git ls-files | grep -E '(^|/)\.env(\.|$)' || true

echo "[3/3] Workflow permissions declarations"
if [ -d .github/workflows ]; then
  grep -R "permissions:" -n .github/workflows || true
else
  echo "(skip) .github/workflows not found in current repo root"
fi

echo "Local checks finished. For remote protection checks, follow docs/remote-repo-hardening-playbook.md"
