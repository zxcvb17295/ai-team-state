#!/usr/bin/env python3
"""agy PreToolUse hook: ai-team-state generic deny list & path boundaries for agy dev agents.

Registered globally in ~/.gemini/config/hooks.json (or AGY_HOOKS_FILE) via
bootstrap/install-agy-hook.sh under the key "ai-team-state-gate".
Only enforces rules when bin/_launch sets TEAM_AGY_POLICY=rd; the user's own
agy sessions are untouched.

Hook protocol:
- "deny": hard-blocks the tool call; the agent sees "tool call denied by pre-tool hook: <reason>".
- "ask" : defers to the session's mode (--mode auto still auto-approves safe commands/edits).
- Never return {} (treated as deny by agy): every path prints an explicit decision.
- Only inspect toolCall.args (never lastUserInput, which carries the prompt text).
"""
import json
import os
import re
import sys

SELFTEST = "TEAM_AGY_GATE_SELFTEST"

# 每段都寫成「一個字只有一種解析方式」：macOS 的 Python 3.9 沒有 atomic group，
# 有歧義的樣式在不匹配時會指數回溯。字元類別一律排除 ; & |，讓每個起點只掃到下一個分隔符。
# 命令位置：開頭、; & | ( 換行 ` $( 之後，或 sh -c '…'／eval "…"／find -exec 之後。
CMD = r"(?:^|[;&|(\n`]|\$\(|-[A-Za-z]*c\s+[\"']|\beval\s+[\"']?|-exec(?:dir)?\s+)\s*"
# 一個 shell 字（不含分隔符；引號可嵌在字中，如 user.name="a b"）
WORD = r"(?:[^\s\"';&|]|\"[^\"]*\"|'[^']*')"
# 開頭的 VAR=value 指派
ASSIGN = r"(?:[A-Za-z_][A-Za-z0-9_]*=" + WORD + r"*\s+)*"
# 一個包裝指令；其後所有字（選項、巢狀包裝、VAR=）保守略過直到 git
WRAPPER = r"(?:(?:env|command|exec|builtin|sudo|doas|nice|nohup|time|timeout|stdbuf|xargs)\s+(?:[^\s;&|]+\s+)*?)?"
# git 本身：可帶路徑（/usr/bin/git）、前置 \、收尾引號；不分大小寫（macOS 檔案系統不分）
GIT_WORD = r"\\?(?:[^\s;&|'\"`]*/)?(?i:git)[\"']?\s+"
# 全域選項：-C／-c／--git-dir… 一律吃掉下一個字當值（含 - 開頭的值，如 -C -repo）；其他 -x／--xxx[=v] 直接略過。
# 兩個分支互斥：通用分支用 lookahead 排除「帶值選項＋空白」，-C 不能回溯成不帶值，
# 否則 git -C commit status 會把值 commit 當成子命令而誤擋。
GIT_VAL_OPT = r"(?:-C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix|--attr-source)"
GIT_OPT = (
    r"(?:" + GIT_VAL_OPT + r"\s+" + WORD + r"+"
    r"|(?!" + GIT_VAL_OPT + r"\s)-[^\s;&|]+)\s+"
)
GIT_WRITE = (
    CMD + ASSIGN + WRAPPER + GIT_WORD
    + r"(?:" + GIT_OPT + r")*"
    + r"(?:add|checkout|commit|stash|push|merge|switch|reset|restore|rm|clean|rebase|cherry-pick|revert)\b"
)

RD_CMD_DENY = [
    (GIT_WRITE, "git 寫入操作由使用者執行（只改工作區，不 commit／checkout／push）"),
    (r"autocrlf", "不可修改 autocrlf 設定"),
]

WRITE_TOOL = re.compile(
    r"write|edit|replace|delete|remove|move|rename|create|patch", re.I
)
PATH_KEY = re.compile(r"path|file", re.I)


def out(decision, reason=""):
    print(json.dumps({"decision": decision, "reason": reason}, ensure_ascii=False))
    sys.exit(0)


def path_args(args):
    if not isinstance(args, dict):
        return
    for k, v in args.items():
        if not PATH_KEY.search(k):
            continue
        if isinstance(v, str):
            yield v
        elif isinstance(v, list):
            for x in v:
                if isinstance(x, str):
                    yield x


def norm_path(p, base_cwd=""):
    p = p.replace("\\", "/")
    p = os.path.expanduser(p)
    if not os.path.isabs(p) and base_cwd:
        p = os.path.join(base_cwd, p)
    return os.path.realpath(p)


def is_within(path, root):
    if not root:
        return False
    root_clean = root.rstrip(os.sep)
    if not root_clean:
        return path.startswith(os.sep)
    return path == root_clean or path.startswith(root_clean + os.sep)


def main():
    policy = os.environ.get("TEAM_AGY_POLICY", "")
    if policy != "rd":
        out("ask")

    try:
        payload = json.load(sys.stdin)
    except Exception:
        out("deny", "ai-team-state agy-gate：讀不到 hook 輸入，保守拒絕")

    if not isinstance(payload, dict):
        out("deny", "ai-team-state agy-gate：hook 輸入格式不正確，保守拒絕")

    call = payload.get("toolCall") or {}
    if not isinstance(call, dict):
        out("deny", "ai-team-state agy-gate：toolCall 格式不正確，保守拒絕")

    name = call.get("name", "")
    if not isinstance(name, str):
        name = ""
    args = call.get("args") or {}
    if not isinstance(args, dict):
        args = {}

    if name == "run_command":
        cmd = args.get("CommandLine", "")
        if not isinstance(cmd, str):
            cmd = str(cmd)
        if SELFTEST in cmd:
            out("deny", "ai-team-state agy-gate 自我測試：hook 已生效")
        for pat, why in RD_CMD_DENY:
            if re.search(pat, cmd):
                out("deny", "ai-team-state：" + why + "。改寫進 handoff，由使用者執行")
        out("ask")

    if WRITE_TOOL.search(name):
        env_team_root = os.environ.get("TEAM_ROOT", "")
        env_team_state = os.environ.get("TEAM_STATE", "")
        env_proj_root = os.environ.get("PROJ_ROOT", "")
        env_agent_cwd = os.environ.get("TEAM_AGENT_CWD", "")

        team_root = norm_path(env_team_root) if env_team_root else ""
        team_state = norm_path(env_team_state) if env_team_state else ""
        proj_root = norm_path(env_proj_root) if env_proj_root else ""
        agent_cwd = norm_path(env_agent_cwd) if env_agent_cwd else ""
        # 安全控制檔（verify-approved、claude-rd.settings.json…）所在目錄
        local_dir = norm_path(os.path.join(team_root, ".local")) if team_root else ""

        # 危險配置：TEAM_STATE 與 .local 互相包含，或包住整個 TEAM_ROOT／PROJ_ROOT。
        # 此時「放行 TEAM_STATE」會開放安全控制檔或其他專案，一律拒絕寫入。
        if team_state and (
            (local_dir and (is_within(local_dir, team_state) or is_within(team_state, local_dir)))
            or (team_root and is_within(team_root, team_state))
            or (proj_root and is_within(proj_root, team_state))
        ):
            out(
                "deny",
                "ai-team-state：TEAM_STATE 設定過寬（等於或包含 TEAM_ROOT、PROJ_ROOT 或 $TEAM_ROOT/.local），"
                "拒絕所有寫入；請 lead 修正 team.env",
            )

        for raw in path_args(args):
            if not raw:
                continue
            p = norm_path(raw, agent_cwd)

            # 敏感路徑優先於 TEAM_STATE 放行
            if local_dir and is_within(p, local_dir):
                out("deny", "ai-team-state：開發 agent 不可寫入 $TEAM_ROOT/.local（安全控制檔）")

            # 放行 TEAM_STATE 底下（特別是 handoff/），即便 TEAM_STATE 放在 TEAM_ROOT 內忽略目錄
            if team_state and is_within(p, team_state):
                continue

            if team_root and is_within(p, team_root):
                out(
                    "deny",
                    "ai-team-state：開發 agent 不可寫入框架目錄 TEAM_ROOT（含 .local/verify-approved）",
                )

            if proj_root and agent_cwd and is_within(p, proj_root) and not is_within(p, agent_cwd):
                out(
                    "deny",
                    "ai-team-state：不可跨專案修改其他專案目錄；需要配合請寫進 handoff「跨專案需求」",
                )

    out("ask")


if __name__ == "__main__":
    main()
