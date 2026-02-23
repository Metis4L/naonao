#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source yunli-core/.venv/bin/activate
python - <<'PY'
from pathlib import Path
print('Python env OK')
print('Workspace:', Path('.').resolve())
try:
    import qwen_tts
    print('qwen_tts import OK')
except Exception as e:
    print('qwen_tts import FAILED:', e)
    raise
PY
