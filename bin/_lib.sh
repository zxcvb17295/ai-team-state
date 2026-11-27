# bin/_lib.sh — 所有腳本共用。由各腳本 source，不直接執行。
# 相容 macOS 內建 bash 3.2：不用關聯陣列、mapfile、${var,,}。

set -euo pipefail

TEAM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${TEAM_ENV:-$TEAM_ROOT/team.env}"

die()  { echo "錯誤：$*" >&2; exit 1; }
warn() { echo "警告：$*" >&2; }

[ -f "$ENV_FILE" ] || die "找不到 ${ENV_FILE}。請先 cp $TEAM_ROOT/team.env.example $TEAM_ROOT/team.env 並填寫。"
# 未設 TEAM_WS 時保留外層 TMUX_SESSION（供 team.env 未宣告或使用 ${TMUX_SESSION:-...} 時覆寫，與舊版相容）；
# 設了 TEAM_WS（或承接自上層工作線派生的 TMUX_SESSION）時，先清掉再讀 team.env，確保以 team.env 基底重算不疊加。
if [ -n "${TEAM_WS:-}" ]; then
  unset TMUX_SESSION
elif [ -n "${_AITS_WS_DERIVED:-}" ] && [ "${TMUX_SESSION:-}" = "$_AITS_WS_DERIVED" ]; then
  unset TMUX_SESSION
fi
unset TMUX_SESSION_BASE _AITS_WS_DERIVED
# shellcheck source=/dev/null
. "$ENV_FILE"

: "${TEAM_STATE:?team.env 未設定 TEAM_STATE}"
case "$TEAM_STATE" in "~"*) TEAM_STATE="$HOME${TEAM_STATE:1}" ;; esac
case "$TEAM_STATE" in /*) ;; *) die "TEAM_STATE 必須是絕對路徑：$TEAM_STATE" ;; esac

PROJ_ROOT="${PROJ_ROOT:-}"
TMUX_SESSION_BASE="${TMUX_SESSION:-team}"
TEAM_WS="${TEAM_WS:-}"
if [ -n "$TEAM_WS" ]; then
  case "$TEAM_WS" in
    -*|*[!a-z0-9-]*) die "TEAM_WS 必須以小寫英數開頭，且只能含小寫英數與 -：$TEAM_WS" ;;
  esac
  TMUX_SESSION="${TMUX_SESSION_BASE}-${TEAM_WS}"
  _AITS_WS_DERIVED="$TMUX_SESSION"
  LOGS="$TEAM_STATE/.logs/ws/$TEAM_WS"
else
  TMUX_SESSION="$TMUX_SESSION_BASE"
  LOGS="$TEAM_STATE/.logs"
fi
AGENTS_WIN="agents"
# agents window 的 pane 排列方式（tmux select-layout）：even-vertical（預設）／tiled／main-vertical…
TEAM_LAYOUT="${TEAM_LAYOUT:-even-vertical}"
DEFAULT_MODEL="${DEFAULT_MODEL:-}"
CODEX_APPROVAL="${CODEX_APPROVAL:-on-request}"
# 預設值不能直接寫在 ${:-} 裡：bash 3.2 會把其中的 ' 當成引號
DEFAULT_APPROVAL_PATTERN="Would you like to|Yes, proceed|don't ask again|Allow command"
APPROVAL_PATTERN="${APPROVAL_PATTERN:-$DEFAULT_APPROVAL_PATTERN}"
WORKING_PATTERN="${WORKING_PATTERN:-Working|esc to interrupt}"
TMUX_SOCKET="${TMUX_SOCKET:-}"
CODEX_BIN="${CODEX_BIN:-codex}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
AGY_BIN="${AGY_BIN:-agy}"
AGY_HOOKS_FILE="${AGY_HOOKS_FILE:-$HOME/.gemini/config/hooks.json}"
DEFAULT_TRUST_PATTERN="Trust this folder|Is this a project you created or one you trust|Do you trust the contents of this project"
TRUST_PATTERN="${TRUST_PATTERN:-$DEFAULT_TRUST_PATTERN}"
AGY_FALLBACK_PATTERN='conflicts with --effort|is not supported for model'
ADDDIR_PATTERN='Adding a new directory'

# 所有腳本的 tmux 都經過這裡：設了 TMUX_SOCKET 就用獨立的 tmux server（-L），
# 不會碰到使用者自己的 tmux。使用者要看畫面：tmux -L <TMUX_SOCKET> attach -t <session>
tmux() {
  if [ -n "$TMUX_SOCKET" ]; then command tmux -L "$TMUX_SOCKET" "$@"; else command tmux "$@"; fi
}
EVENTS="$TEAM_STATE/EVENTS.log"

# 子行程（tmux pane 裡的引擎、agent 呼叫的 bin/event）要讀同一份設定與工作線
TEAM_ENV="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
export TEAM_ROOT TEAM_STATE PROJ_ROOT TMUX_SESSION TMUX_SESSION_BASE TEAM_WS LOGS TEAM_ENV AGY_HOOKS_FILE
if [ -n "${_AITS_WS_DERIVED:-}" ]; then export _AITS_WS_DERIVED; fi

need_proj_root() {
  [ -n "$PROJ_ROOT" ] || die "team.env 未設定 PROJ_ROOT"
  [ -d "$PROJ_ROOT" ] || die "PROJ_ROOT 不存在：$PROJ_ROOT"
}

need_state() {
  [ -d "$TEAM_STATE" ] || die "TEAM_STATE 不存在：${TEAM_STATE}（先跑 bin/init-state）"
}

# ---- agent → tmux 目標（支援新式 @role pane 與舊式同名 window）----
# 新式：在 =$TMUX_SESSION 的 pane 中依 pane 選項 @role=<agent> 找回 pane_id（%N）。
# 舊式退路（相容升級前以角色命名的 window）：若找不到 @role pane，退回檢查同名 window，回傳 =session:=window。
# session／window 一律用 = 精確比對：避免預設前綴比對誤中（例：team 誤中 team-x、a-rd 誤中 a-rd2）。
agent_target() {
  local id
  id="$({ tmux list-panes -s -t "=$TMUX_SESSION" -F '#{pane_id}|#{@role}' 2>/dev/null || true; } |
    awk -F'|' -v r="$1" '$2 == r { print $1; exit }')"
  if [ -n "$id" ]; then
    echo "$id"
    return 0
  fi
  if { tmux list-windows -t "=$TMUX_SESSION" -F '#{window_name}' 2>/dev/null || true; } | grep -qxF -- "$1"; then
    echo "=$TMUX_SESSION:=$1"
    return 0
  fi
  return 1
}

agent_exists() { agent_target "$1" >/dev/null; }
tgt() { agent_target "$1" || echo "=$TMUX_SESSION:=__none__"; }

# 本 session 的所有 agent（新式 pane 的 @role ＋ 舊式 *-rd window，去重）
session_agents() {
  {
    tmux list-panes -s -t "=$TMUX_SESSION" -F '#{@role}' 2>/dev/null | awk 'NF' || true
    tmux list-windows -t "=$TMUX_SESSION" -F '#{window_name}' 2>/dev/null | grep -- '-rd$' || true
  } | sort -u
}

# 檢查同 tmux server 上屬於同一 TMUX_SESSION_BASE 的其他工作線，是否有同角色的非 shell 程式正在跑；
# 有就印出該 session 名。
role_live_elsewhere() {
  { tmux list-panes -a -F '#{session_name}|#{window_name}|#{@role}|#{pane_current_command}' 2>/dev/null || true; } |
    awk -F'|' -v r="$1" -v me="$TMUX_SESSION" -v base="$TMUX_SESSION_BASE" '
      ($1 == base || substr($1, 1, length(base) + 1) == base "-") &&
      $1 != me &&
      ($3 == r || ($3 == "" && $2 == r)) &&
      $4 !~ /^-?(zsh|bash|sh|fish)$/ { print $1; exit }'
}

# 引擎查詢：讀 pane 選項 @engine；空值時退回讀 window 選項 @engine（相容舊式 window）；仍空預設 codex
pane_engine() {
  local t v
  t="$(tgt "$1")"
  v="$(tmux show-options -pqv -t "$t" @engine 2>/dev/null || true)"
  [ -n "$v" ] || v="$(tmux show-options -wqv -t "$t" @engine 2>/dev/null || true)"
  echo "${v:-codex}"
}

# 各引擎畫面字樣（codex 保留 team.env 自訂的 WORKING_PATTERN / APPROVAL_PATTERN）
working_pat() {
  case "$1" in
    claude) echo 'esc to interrupt' ;;
    # agy：工作中時行首是點字 spinner；不可用 esc to cancel（停在核准畫面時它也在最底行）
    agy)    echo '⣾|⣽|⣻|⢿|⡿|⣟|⣯|⣷' ;;
    *)      printf '%s\n' "$WORKING_PATTERN" ;;
  esac
}

approval_pat() {
  case "$1" in
    claude) echo 'Do you want to proceed|This command requires approval' ;;
    # [?] 不用 \?：pane_waiting_on 經 awk -v 傳入，\? 會出警告
    agy)    echo 'Requesting permission for|Run this command[?]|Allow access to this file[?]' ;;
    *)      printf '%s\n' "$APPROVAL_PATTERN" ;;
  esac
}

# 抓 agent 目前畫面（只抓可見區，避免舊捲動內容誤判）
pane() { tmux capture-pane -p -t "$(tgt "$1")" 2>/dev/null; }
pane_tail() { { pane "$1" || true; } | { grep -v '^[[:space:]]*$' || true; } | tail -n "${2:-15}"; }

# agent pane 的前景程式是不是 shell（= 引擎已退出）。
# 前提：bin/_launch 用 exec 啟動引擎，否則前景會是 bash 腳本而誤判。
pane_is_shell() {
  local cmd
  cmd="$(tmux display-message -p -t "$(tgt "$1")" '#{pane_current_command}' 2>/dev/null || true)"
  case "$cmd" in
    zsh|bash|sh|fish|-zsh|-bash|-sh|-fish) return 0 ;;
    *) return 1 ;;
  esac
}

# 畫面底部（最後 15 個非空行）是否「正停在」某提示：
# 提示字樣必須出現，且出現在最後一個該引擎的工作中字樣之後（舊提示留在畫面上不算）。
pane_waiting_on() {
  local w
  w="$(working_pat "$(pane_engine "$1")")"
  pane_tail "$1" 15 | awk -v p="$2" -v w="$w" '
    $0 ~ p { lp = NR } $0 ~ w { lw = NR }
    END { exit !(lp > 0 && lp > lw) }'
}

# 畫面底部（最後 8 個非空行）是否出現該引擎的工作中字樣
pane_working() {
  local w
  w="$(working_pat "$(pane_engine "$1")")"
  pane_tail "$1" 8 | grep -Eq -- "$w"
}

# agy 的 ai-team-state hook 是否已註冊：解析 $AGY_HOOKS_FILE 的 "ai-team-state-gate" 項目，
# 其中某個 command hook 的參數（shlex 拆解後）指向本框架的 bootstrap/agy-gate.py 才算。
# 不比對 JSON 原文：install-agy-hook.sh 以 shlex.quote 寫入，路徑含單引號時原文不連續。
# 未註冊就 die（bin/spawn-agent、bin/_launch 共用）。
need_agy_hook() {
  local gate="$TEAM_ROOT/bootstrap/agy-gate.py"
  command -v python3 >/dev/null || die "找不到 python3（agy 的 hook 需要）"
  python3 -I - "$AGY_HOOKS_FILE" "$gate" <<'EOF' ||
import json, os, shlex, sys
dst, gate = sys.argv[1], os.path.realpath(sys.argv[2])
try:
    with open(dst, encoding="utf-8") as f:
        cfg = json.load(f)
    for entry in cfg["ai-team-state-gate"]["PreToolUse"]:
        for h in entry.get("hooks", []):
            if h.get("type") == "command" and any(
                os.path.realpath(a) == gate for a in shlex.split(h.get("command", ""))
            ):
                sys.exit(0)
except Exception:
    pass
sys.exit(1)
EOF
    die "agy 的 ai-team-state hook 尚未註冊於 ${AGY_HOOKS_FILE}。請先執行：bash \"$TEAM_ROOT/bootstrap/install-agy-hook.sh\""
}

# 事件 agent 欄：有 TEAM_WS 時回傳 <role>@<TEAM_WS>，沒有時回傳 <role>
ws_agent() {
  if [ -n "$TEAM_WS" ]; then echo "${1}@${TEAM_WS}"; else echo "$1"; fi
}

# 檢查 effort 參數：
#   check_effort <effort>           等同 codex（非空且只允許英數與 - _，不寫死白名單）
#   check_effort <engine> <effort>  claude／agy 僅允許 low|medium|high|xhigh|max；codex 同上
check_effort() {
  local engine effort
  if [ $# -ge 2 ]; then
    engine="$1"
    effort="$2"
  else
    engine="codex"
    effort="${1:-}"
  fi
  [ -n "$effort" ] || die "未指定 effort（必須先問使用者，不可省略）"
  case "$engine" in
    claude|agy)
      case "$effort" in
        low|medium|high|xhigh|max) ;;
        *) die "$engine 的 effort 只能是 low/medium/high/xhigh/max：$effort" ;;
      esac
      ;;
    codex)
      case "$effort" in
        *[!A-Za-z0-9_-]*) die "effort 只能含英數、-、_：$effort" ;;
      esac
      ;;
    *) die "引擎只能是 codex、claude 或 agy：$engine" ;;
  esac
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

# 某任務最後一筆符合工作線規則的「<TYPE> <role> <proj> <slug>」事件行（沒有就印空字串）：
# - 未設 TEAM_WS：只比對裸 <role>（不匹配其他工作線的 <role>@ws）
# - 設了 TEAM_WS：比對 <role>@<TEAM_WS> 與裸 <role>（agent 忘了加 @ws 時的退路，絕不匹配 <role>@其他ws）
last_event_line() {   # <TYPE> <role> <proj> <slug>
  [ -f "$EVENTS" ] || return 0
  awk -v t="$1" -v r="$2" -v p="$3" -v s="$4" -v ws="$TEAM_WS" '
    $1 ~ /^[0-9-]+$/ && $2 ~ /^[0-9:]+$/ && $3 == t && $5 == p && $6 == s &&
    ($4 == r || (ws != "" && $4 == r "@" ws)) { line = $0 }
    END { if (line != "") print line }
  ' "$EVENTS"
}

# 某任務最後一筆「<TYPE> <role> <proj> <slug>」事件裡的 fp=（沒有就印空字串）
last_event_fp() {   # <TYPE> <role> <proj> <slug>
  last_event_line "$@" | sed -n 's/.* fp=\([0-9a-f]\{12\}\).*/\1/p'
}
