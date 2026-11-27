# README — ai-team-state

多專案多引擎 agent 協作框架：一個 team lead 帶多個開發 agent（支援 `codex`、`claude`、`agy`）＋ 唯讀審查與邏輯查核 agent（`bin/review`、`bin/logic` 固定走 `codex exec -s read-only`），分工開發各自負責的專案。
lead 不寫專案的程式，只派工與彙整。協作模型用語見 [GLOSSARY.md](./GLOSSARY.md)。

## 框架與資料分開

| 位置 | 內容 | 版控 |
|------|------|------|
| `TEAM_ROOT`（本 repo） | 流程文件、用語表、參考文件（`docs/`）、共用與唯讀 role、通用安全設定（`bootstrap/`）、範本、`bin/` 腳本 | ✅ |
| `TEAM_STATE`（自訂路徑） | 你的專案組資料：PROJECTS、各專案 role、任務書、handoff、EVENTS.log | ❌ |

`TEAM_STATE` 在 `team.env` 裡設定，可以放在任何地方（建議放在 git repo 之外）。
同一份框架可以帶多個 team：每個 team 一份 env 檔，用 `TEAM_ENV=<路徑> bin/...` 切換。

## 誰該讀什麼

| 角色 | 入口 |
|------|------|
| team lead | [AGENT.md](./AGENT.md)（流程）、[GLOSSARY.md](./GLOSSARY.md)（用語）、`$TEAM_STATE/PROJECTS.md`（專案組設定） |
| `<proj>-rd`（開發 agent） | [roles/_rd-common.md](./roles/_rd-common.md)（共用規範）＋ `$TEAM_STATE/roles/<proj>-rd.md`（專案專屬，由 `bin/spawn-agent` 一起帶入） |
| `review-rd` | [roles/review-rd.md](./roles/review-rd.md)（由 `bin/review` 帶入） |
| `logic-rd` | [roles/logic-rd.md](./roles/logic-rd.md)（由 `bin/logic` 帶入，查邏輯用） |

## 如何開始

```bash
cp team.env.example team.env        # 填 TEAM_STATE、PROJ_ROOT、TMUX_SESSION、TMUX_SOCKET、DEFAULT_MODEL
bin/init-state                      # 建立 TEAM_STATE 與 PROJECTS.md
# 填寫 $TEAM_STATE/PROJECTS.md
bin/new-role <proj> <專案目錄名>     # 每個專案一次，填寫其「專案硬規範」
# 若要使用 agy 引擎，首次註冊全域安全 hook（不影響你自己的 agy）：
bash bootstrap/install-agy-hook.sh
```

之後依 AGENT.md §0 開工。

## 升級與遷移（`roles/_rd-common.md`）

若你已建立過 `$TEAM_STATE/roles/*-rd.md`，升級後 `bin/spawn-agent` 會同時要求開發 agent 讀 `$TEAM_ROOT/roles/_rd-common.md` 與 `$TEAM_STATE/roles/<proj>-rd.md`：

- 既有的 `$TEAM_STATE/roles/*-rd.md` **不修改也能正常運作**，但通用規範會重複而多耗上下文。
- 建議對照 [templates/role-rd.md](./templates/role-rd.md) 清理各專案 role：
  1. 在開頭加上引用 `$TEAM_ROOT/roles/_rd-common.md` 與本檔 `<角色>`／`<proj>` 的提示。
  2. 保留專案專屬段落（你是誰、開工前必讀、專案硬規範、不准做、驗證、專案特有的交件附加項）。
  3. 刪除與 `_rd-common.md` 重複的通用段落（邊界、程式撰寫偏好、完整回報與交件步驟、收到審查意見）。

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

看 agent 畫面：`tmux -L <TMUX_SOCKET> attach -t <TMUX_SESSION>`（使用工作線 `TEAM_WS=<ws>` 時 session 為 `<TMUX_SESSION>-<ws>`；未設 `TMUX_SOCKET` 則省去 `-L`）。

## 腳本

以下腳本在需要並行多任務時皆支援前綴 `TEAM_WS=<ws>` 切換工作線（細節見 [AGENT.md](./AGENT.md) §0「工作線」）：

| 腳本 | 用途 |
|------|------|
| `bin/init-state` | 建立／檢查 TEAM_STATE（在 git repo 內且未被忽略會報錯） |
| `bin/new-role <proj> <dir>` | 從範本建立專案 role 與驗證腳本範本 |
| `bin/new-task <proj> <dir> <slug>` | 建立任務書並記錄派工基準（分支、base commit、既有改動）；設 `TEAM_WS` 時自動填入 `<proj>-rd@<ws>` |
| `bin/spawn-agent <proj> <dir> <engine> <model> <effort> <slug>` | 在 `agents` window（一角色一 pane，支援 `codex`／`claude`／`agy`）開／重開開發 agent，帶入 `_rd-common.md`、專案 role 與任務書，含專案鎖（最多等 90 秒並以結束碼 0/3/4/5/6 回報狀態） |
| `bin/send <agent> <msg>` | 送訊息並確認送出（依引擎判別工作中與核准字樣；支援 `@role` pane 與舊式 window；核准／信任／退出時拒送並印畫面；補 Enter 前確認輸入框內容） |
| `bin/peek <agent> [n]` | 看畫面並附引擎與前景程式標題列（支援 `@role` pane 與舊式 window） |
| `bin/wait-pane <agent> <regex> [秒]` | 等畫面出現字樣 |
| `bin/watch [秒]` | 背景監看：DONE/BLOCKED（依 `TEAM_WS` 分線，附期間 START）、各引擎核准畫面（`APPROVAL <agent>（<engine>）`）、信任提示、引擎退出、逾時（附引擎與工作中／閒置）；支援 `WATCH_IGNORE` |
| `bin/verify <proj> <slug>` | lead 在交件工作區的乾淨複本重跑編譯與測試（`verify/<proj>.sh`），寫報告並代寫事件（有 `TEAM_WS` 寫 `verify@<ws>`、log 進 `.logs/ws/<ws>/`） |
| `bin/verify <proj> --approve` | 讀過驗證腳本後登記其 hash；腳本被改過就拒跑 |
| `bin/review <proj> <dir> <slug> <model> <effort> [輪]` | 唯讀沙箱審查（固定 `codex exec -s read-only`），寫報告並代寫事件（有 `TEAM_WS` 寫 `review-rd@<ws>`、log 進 `.logs/ws/<ws>/`） |
| `bin/logic <proj\|-> <slug> <model> <effort> [輪] [dir...]` | 唯讀沙箱邏輯查核（固定 `codex exec -s read-only`），寫報告並代寫事件（有 `TEAM_WS` 寫 `logic-rd@<ws>`）；不要求工作區指紋 |
| `bin/fingerprint <proj> <slug>` | 比對目前工作區與 DONE／verify／review 的指紋（依 `TEAM_WS` 分線）；結案前必跑 |
| `bin/event <TYPE> …` | 寫 EVENTS.log（agent 與腳本共用；`<proj>-rd` 與 `<proj>-rd@<ws>` 的 DONE 皆自動計算 `fp=`） |
| `bootstrap/install-agy-hook.sh` | 冪等註冊 `bootstrap/agy-gate.py` 為全域 agy PreToolUse hook（key `"ai-team-state-gate"`，只在 `TEAM_AGY_POLICY=rd` 時介入） |

## 檔案流向（都在 `$TEAM_STATE`）

```
tasks/<proj>-<slug>.md          ← lead 寫，agent 讀；結案移到 tasks/done/
tasks/logic-<slug>.md           ← lead 寫，logic-rd 讀（邏輯查核問題書，選用）
handoff/<proj>-rd-<slug>.md     ← <proj>-rd 寫，review-rd + lead 讀
handoff/verify-<proj>-<slug>.md ← bin/verify 寫（lead 重跑的編譯與測試），review-rd + lead + <proj>-rd 讀
handoff/review-<proj>-<slug>.md ← bin/review 寫（review-rd 的輸出），lead + <proj>-rd 讀
handoff/logic-<slug>.md         ← bin/logic 寫（logic-rd 的輸出），lead 讀
verify/<proj>.sh                ← lead 寫，bin/verify 執行（hash 登記在 $TEAM_ROOT/.local/，不進版控）
LESSONS.md                      ← lead 寫：每個任務的教訓與去向
EVENTS.log                      ← bin/event append，所有工作線共用，bin/watch 分線監看
.logs/                          ← 未設 TEAM_WS 時的啟動 prompt、verify／review／logic 輸出、watch.offset
.logs/ws/<ws>/                  ← 工作線 <ws> 專屬的啟動 prompt、verify／review／logic 輸出、watch.offset
```

同一個任務從頭到尾用**同一個 `<slug>`**（不含專案前綴）。被退回修正時**更新原 handoff**，不要新增檔案。

## EVENTS.log 格式

一行一事件，append only，一律用 `bin/event` 寫：

```
<日期> <時間> <TYPE> <agent> <proj> <slug> <檔案|-> <摘要>
```

使用工作線（`TEAM_WS=<ws>`）時，`<agent>` 欄填 `<角色>@<ws>`（如 `api-rd@login-timeout`、`verify@login-timeout`、`review-rd@login-timeout`、`logic-rd@login-timeout`）；未設 `TEAM_WS` 時填裸 `<角色>`。

```
2026-01-01 13:50:10 DONE logic-rd api login-timeout handoff/logic-login-timeout.md 問題 1 成立，找到 1 個邊界反例
2026-01-01 14:02:11 START api-rd@login-timeout api login-timeout - 已讀任務書，開始
2026-01-01 14:32:05 DONE api-rd@login-timeout api login-timeout handoff/api-rd-login-timeout.md 新增逾時設定，已編譯與測試通過 fp=3f2a9c01be47
2026-01-01 14:40:12 DONE verify@login-timeout api login-timeout handoff/verify-api-login-timeout.md PASS exit=0 fp=3f2a9c01be47
2026-01-01 15:10:41 DONE review-rd@login-timeout api login-timeout handoff/review-api-login-timeout.md FAIL 1 Blocker 0 Major 2 Minor fp=3f2a9c01be47
2026-01-01 15:48:02 BLOCKED web-rd web login-page handoff/web-rd-login-page.md 等 api 的 response 欄位定義
```

事件類型：`START`（已讀任務書）/ `DONE`（完成；verify、review 的摘要以 `PASS`／`FAIL` 開頭）/ `BLOCKED`（卡住，需 lead 決定）。

`fp=<12 碼>` 是工作區指紋：`<proj>-rd`（含 `<proj>-rd@<ws>`）的 DONE 由 `bin/event` 自動加上，verify／review 記下自己跑的是哪個版本（`logic-rd` 不綁工作區指紋）。三者相同才代表驗證與審查的就是最後交件的程式碼（`bin/fingerprint` 比對）。

## 目錄

```
ai-team-state/                 # TEAM_ROOT（版控）
├── AGENT.md  GLOSSARY.md  README.md  GIT-COMMIT.md  CLAUDE.md
├── team.env.example           # team.env 不進版控
├── bin/                       # 腳本（bash 3.2 相容）
├── bootstrap/                 # 通用安全邊界：claude-rd.settings.json、agy-gate.py、install-agy-hook.sh
├── docs/                      # 細則：agent-startup.md、manual-approval.md、restart-mid-task.md、rewrite-commits.md
├── roles/                     # _rd-common.md、review-rd.md、logic-rd.md
├── skills/                    # Claude Code lead 用 skill
├── .local/                    # 不進版控、agent 寫不到：bin/verify 登記的腳本 hash、選填 claude-rd.settings.json（額外 deny）
└── templates/                 # PROJECTS.md、LESSONS.md、role-rd.md、task.md、logic-task.md、handoff-rd.md、handoff-review.md、verify.sh

$TEAM_STATE/                   # 你的資料（不進版控）
├── PROJECTS.md
├── LESSONS.md
├── EVENTS.log
├── roles/<proj>-rd.md
├── verify/<proj>.sh
├── tasks/  tasks/done/
├── handoff/
└── .logs/                     # 未設工作線用根目錄；工作線在 .logs/ws/<ws>/
```
