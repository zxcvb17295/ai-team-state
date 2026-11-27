#!/usr/bin/env bash
# bootstrap/install-agy-hook.sh — 註冊 bootstrap/agy-gate.py 為全域 agy PreToolUse hook
#
#   bash bootstrap/install-agy-hook.sh
#   AGY_HOOKS_FILE=/path/to/hooks.json bash bootstrap/install-agy-hook.sh
#
# agy 只讀專案 .agents/ 或全域 ~/.gemini/config/hooks.json；開發 agent 的 cwd 是業務專案，
# 框架不往業務專案放檔案，因此註冊在全域。agy-gate.py 只在 bin/_launch 設定 TEAM_AGY_POLICY=rd
# 時介入，不影響使用者自己的 agy 工作階段。
# 冪等：合併 "ai-team-state-gate" 到既有 hooks.json，保留其他既有 hook。

set -euo pipefail

TEAM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gate="$TEAM_ROOT/bootstrap/agy-gate.py"
dst="${AGY_HOOKS_FILE:-$HOME/.gemini/config/hooks.json}"

[ -f "$gate" ] || { echo "錯誤：找不到 $gate" >&2; exit 1; }
command -v python3 >/dev/null || { echo "錯誤：找不到 python3" >&2; exit 1; }
mkdir -p "$(dirname "$dst")"

python3 -I - "$dst" "$gate" <<'EOF'
import json
import os
import shlex
import sys

dst, gate = sys.argv[1], sys.argv[2]
cfg = {}
if os.path.exists(dst) and os.path.getsize(dst) > 0:
    with open(dst, encoding="utf-8") as f:
        cfg = json.load(f)
if not isinstance(cfg, dict):
    sys.stderr.write(f"錯誤：{dst} 頂層不是 JSON 物件\n")
    sys.exit(1)

cfg["ai-team-state-gate"] = {
    "PreToolUse": [
        {
            "matcher": "*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"python3 -I {shlex.quote(gate)}",
                    "timeout": 10,
                }
            ],
        }
    ]
}

tmp = dst + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write("\n")
os.replace(tmp, dst)
print(f"已註冊 ai-team-state-gate → {dst}")
EOF
