#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PY="python3"
$PY -m venv yunli-core/.venv
source yunli-core/.venv/bin/activate

pip install -U pip setuptools wheel
pip install -U qwen-tts soundfile

echo "[OK] qwen-tts installed in yunli-core/.venv"
