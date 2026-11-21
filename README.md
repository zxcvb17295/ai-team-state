# README — ai-team-state

多專案 codex agent 協作框架：一個 team lead 帶多個開發 agent ＋ 唯讀審查 agent，分工開發各自負責的專案。
lead 不寫專案的程式，只派工與彙整。

## 框架與資料分開

| 位置 | 內容 | 版控 |
|------|------|------|
| `TEAM_ROOT`（本 repo） | 流程文件、範本、`bin/` 腳本 | ✅ |
| `TEAM_STATE`（自訂路徑） | 你的專案組資料：PROJECTS、各專案 role、任務書、handoff、EVENTS.log | ❌ |

`TEAM_STATE` 在 `team.env` 裡設定，可以放在任何地方（建議放在 git repo 之外）。
同一份框架可以帶多個 team：每個 team 一份 env 檔，用 `TEAM_ENV=<路徑> bin/...` 切換。

## 誰該讀什麼

| 角色 | 入口 |
|------|------|
| team lead | [AGENT.md](./AGENT.md)（流程）、`$TEAM_STATE/PROJECTS.md`（專案組設定） |
| `<proj>-rd`（開發 agent） | `$TEAM_STATE/roles/<proj>-rd.md` |
| `review-rd` | [roles/review-rd.md](./roles/review-rd.md)（由 `bin/review` 帶入） |

## 如何開始

```bash
cp team.env.example team.env        # 填 TEAM_STATE、PROJ_ROOT、TMUX_SESSION、TMUX_SOCKET、DEFAULT_MODEL
bin/init-state                      # 建立 TEAM_STATE 與 PROJECTS.md
# 填寫 $TEAM_STATE/PROJECTS.md
bin/new-role <proj> <專案目錄名>     # 每個專案一次，填寫其「專案硬規範」
```

之後依 AGENT.md §0 開工。

## 用 skill 啟動（任何目錄都可）

`skills/ai-team/SKILL.md` 是 Claude Code 的手動 skill。連到個人 skill 目錄後，在任何目錄開 Claude Code 都能用：

```bash
ln -s "$PWD/skills/ai-team" ~/.claude/skills/ai-team    # 你的 ~/.claude/skills 若是連到別處，就連進那個目錄
```

```
/ai-team                         # 回報現況
/ai-team 加專案 <目錄、建構方式、定位…>
/ai-team <需求>                   # 派工
```

看 agent 畫面：`tmux -L <TMUX_SOCKET> attach -t <TMUX_SESSION>`。

## 腳本

| 腳本 | 用途 |
|------|------|
| `bin/init-state` | 建立／檢查 TEAM_STATE（在 git repo 內且未被忽略會報錯） |
| `bin/new-role <proj> <dir>` | 從範本建立專案 role |
| `bin/new-task <proj> <dir> <slug>` | 建立任務書並記錄派工基準（分支、base commit、既有改動） |
| `bin/spawn-agent <proj> <dir> <model> <slug>` | 開／重開開發 agent，直接帶入 role 與任務書 |
| `bin/send <agent> <msg>` | 送訊息並確認送出 |
| `bin/peek <agent> [n]` | 看畫面 |
| `bin/wait-pane <agent> <regex> [秒]` | 等畫面出現字樣 |
| `bin/watch [秒]` | 背景監看：DONE/BLOCKED、核准畫面、codex 退出、逾時 |
| `bin/review <proj> <dir> <slug> <model> [輪]` | 唯讀沙箱審查，寫報告並代寫事件 |
| `bin/event <TYPE> …` | 寫 EVENTS.log（agent 與腳本共用） |

## 檔案流向（都在 `$TEAM_STATE`）

```
tasks/<proj>-<slug>.md          ← lead 寫，agent 讀；結案移到 tasks/done/
handoff/<proj>-rd-<slug>.md     ← <proj>-rd 寫，review-rd + lead 讀
handoff/review-<proj>-<slug>.md ← bin/review 寫（review-rd 的輸出），lead + <proj>-rd 讀
EVENTS.log                      ← bin/event append，bin/watch 監看
.logs/                          ← 啟動 prompt、review 的 codex 輸出
```

同一個任務從頭到尾用**同一個 `<slug>`**（不含專案前綴）。被退回修正時**更新原 handoff**，不要新增檔案。

## EVENTS.log 格式

一行一事件，append only，一律用 `bin/event` 寫：

```
<日期> <時間> <TYPE> <agent> <proj> <slug> <檔案|-> <摘要>
```

```
2026-01-01 14:02:11 START api-rd api login-timeout - 已讀任務書，開始
2026-01-01 14:32:05 DONE api-rd api login-timeout handoff/api-rd-login-timeout.md 新增逾時設定，已編譯與測試通過
2026-01-01 15:10:41 DONE review-rd api login-timeout handoff/review-api-login-timeout.md FAIL 1 Blocker 0 Major 2 Minor
2026-01-01 15:48:02 BLOCKED web-rd web login-page handoff/web-rd-login-page.md 等 api 的 response 欄位定義
```

事件類型：`START`（已讀任務書）/ `DONE`（完成；review 的摘要以 `PASS`／`FAIL` 開頭）/ `BLOCKED`（卡住，需 lead 決定）。

## 目錄

```
ai-team-state/                 # TEAM_ROOT（版控）
├── AGENT.md  README.md  GIT-COMMIT.md  CLAUDE.md
├── team.env.example           # team.env 不進版控
├── bin/                       # 腳本（bash 3.2 相容）
├── roles/review-rd.md
└── templates/                 # PROJECTS.md、role-rd.md、task.md、handoff-rd.md、handoff-review.md

$TEAM_STATE/                   # 你的資料（不進版控）
├── PROJECTS.md
├── EVENTS.log
├── roles/<proj>-rd.md
├── tasks/  tasks/done/
├── handoff/
└── .logs/
```
