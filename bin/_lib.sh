# bin/_lib.sh — 所有腳本共用。由各腳本 source，不直接執行。
# 相容 macOS 內建 bash 3.2：不用關聯陣列、mapfile、${var,,}。

set -euo pipefail

TEAM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${TEAM_ENV:-$TEAM_ROOT/team.env}"

die()  { echo "錯誤：$*" >&2; exit 1; }
warn() { echo "警告：$*" >&2; }

[ -f "$ENV_FILE" ] || die "找不到 ${ENV_FILE}。請先 cp $TEAM_ROOT/team.env.example $TEAM_ROOT/team.env 並填寫。"
# shellcheck source=/dev/null
. "$ENV_FILE"

: "${TEAM_STATE:?team.env 未設定 TEAM_STATE}"
case "$TEAM_STATE" in "~"*) TEAM_STATE="$HOME${TEAM_STATE:1}" ;; esac
case "$TEAM_STATE" in /*) ;; *) die "TEAM_STATE 必須是絕對路徑：$TEAM_STATE" ;; esac

PROJ_ROOT="${PROJ_ROOT:-}"
TMUX_SESSION="${TMUX_SESSION:-team}"
DEFAULT_MODEL="${DEFAULT_MODEL:-}"
CODEX_APPROVAL="${CODEX_APPROVAL:-on-request}"
# 預設值不能直接寫在 ${:-} 裡：bash 3.2 會把其中的 ' 當成引號
DEFAULT_APPROVAL_PATTERN="Would you like to|Yes, proceed|don't ask again|Allow command"
APPROVAL_PATTERN="${APPROVAL_PATTERN:-$DEFAULT_APPROVAL_PATTERN}"
WORKING_PATTERN="${WORKING_PATTERN:-Working|esc to interrupt}"
TMUX_SOCKET="${TMUX_SOCKET:-}"
CODEX_BIN="${CODEX_BIN:-codex}"
TRUST_PATTERN="Trust this folder"

# 所有腳本的 tmux 都經過這裡：設了 TMUX_SOCKET 就用獨立的 tmux server（-L），
# 不會碰到使用者自己的 tmux。使用者要看畫面：tmux -L <TMUX_SOCKET> attach -t <session>
tmux() {
  if [ -n "$TMUX_SOCKET" ]; then command tmux -L "$TMUX_SOCKET" "$@"; else command tmux "$@"; fi
}
EVENTS="$TEAM_STATE/EVENTS.log"

# 子行程（tmux window 裡的 codex、agent 呼叫的 bin/event）要讀同一份設定
TEAM_ENV="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
export TEAM_ROOT TEAM_STATE PROJ_ROOT TMUX_SESSION TEAM_ENV

need_proj_root() {
  [ -n "$PROJ_ROOT" ] || die "team.env 未設定 PROJ_ROOT"
  [ -d "$PROJ_ROOT" ] || die "PROJ_ROOT 不存在：$PROJ_ROOT"
}

need_state() {
  [ -d "$TEAM_STATE" ] || die "TEAM_STATE 不存在：${TEAM_STATE}（先跑 bin/init-state）"
}

# 抓 window 目前畫面（只抓可見區，避免舊捲動內容誤判）
pane() { tmux capture-pane -p -t "$TMUX_SESSION:$1" 2>/dev/null; }

# agent window 的前景程式是不是 shell（= codex 已退出）。
# 前提：bin/_codex-tui 用 exec 啟動 codex，否則前景會是 bash 腳本而誤判。
pane_is_shell() {
  case "$(tmux display-message -p -t "$TMUX_SESSION:$1" '#{pane_current_command}')" in
    zsh|bash|sh|fish|-zsh|-bash|-sh) return 0 ;;
    *) return 1 ;;
  esac
}

# 畫面底部（最後 15 個非空行）是否「正停在」某提示：
# 提示字樣必須出現，且出現在最後一個 WORKING_PATTERN 之後（舊提示留在畫面上不算）。
pane_waiting_on() {
  pane "$1" | grep -v '^[[:space:]]*$' | tail -15 | awk -v p="$2" -v w="$WORKING_PATTERN" '
    $0 ~ p { lp = NR } $0 ~ w { lw = NR }
    END { exit !(lp > 0 && lp > lw) }'
}

window_exists() {
  tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$1"
}

# render <範本> <目的地> [KEY=VALUE ...]：替換 {{KEY}}，目的地已存在就拒絕（不覆蓋）
render() {
  local src="$1" dest="$2"; shift 2
  [ -f "$src" ] || die "找不到範本：$src"
  [ ! -e "$dest" ] || die "已存在，不覆蓋：$dest"
  local script="s|{{TEAM_ROOT}}|$TEAM_ROOT|g;s|{{TEAM_STATE}}|$TEAM_STATE|g;s|{{PROJ_ROOT}}|$PROJ_ROOT|g"
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    script="$script;s|{{$key}}|$val|g"
  done
  mkdir -p "$(dirname "$dest")"
  sed "$script" "$src" > "$dest"
}

# ---- 任務書欄位、工作區指紋（bin/event、bin/review、bin/verify、bin/fingerprint 共用）----

task_file() { echo "$TEAM_STATE/tasks/$1-$2.md"; }   # <proj> <slug>

# 從任務書讀專案 cwd（「| 專案 cwd | `路徑` |」那一列）
task_cwd() {
  sed -n 's/^| 專案 cwd | `\([^`]*\)`.*/\1/p' "$1" | head -1
}

# 從任務書讀派工基準的 base commit（「- base commit：`sha`」）
task_base() {
  sed -n 's/^- base commit：`\([0-9a-f]\{7,40\}\)`.*/\1/p' "$1" | head -1
}

sha256() { if command -v shasum >/dev/null; then shasum -a 256; else sha256sum; fi | cut -c1-64; }

# 工作區指紋：HEAD + 相對 base 的 diff（含二進位）+ 未追蹤檔案的路徑與內容 hash。
# 只讀不寫（--no-optional-locks、hash-object 不帶 -w），唯讀沙箱內也能算。
# 用法：work_fp <cwd> <base>  → 印出 12 碼 hex
work_fp() {
  local cwd="$1" base="$2"
  {
    git -C "$cwd" rev-parse HEAD
    git -C "$cwd" --no-optional-locks diff --binary "$base"
    git -C "$cwd" --no-optional-locks ls-files -o --exclude-standard -z |
      while IFS= read -r -d '' f; do
        printf '%s %s\n' "$f" "$(git -C "$cwd" hash-object -- "$f")"
      done
  } | sha256 | cut -c1-12
}

# 某任務最後一筆「<TYPE> <agent> <proj> <slug>」事件裡的 fp=（沒有就印空字串）
last_event_fp() {   # <TYPE> <agent> <proj> <slug>
  [ -f "$EVENTS" ] || return 0
  grep -E "^[0-9-]+ [0-9:]+ $1 $2 $3 $4 " "$EVENTS" | tail -1 |
    sed -n 's/.* fp=\([0-9a-f]\{12\}\).*/\1/p'
}
