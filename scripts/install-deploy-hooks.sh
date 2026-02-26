#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

chmod +x scripts/deploy-safe.sh scripts/install-deploy-hooks.sh .githooks/post-merge

git config core.hooksPath .githooks

echo "Installed hooksPath=.githooks"
echo "post-merge hook -> scripts/deploy-safe.sh"
