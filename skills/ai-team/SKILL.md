---
name: ai-team
description: 僅供 Claude Code 的 team lead：帶多引擎（codex／claude／agy）agent 團隊開發多個專案（ai-team-state 框架）。被派工的 agent 不使用。
disable-model-invocation: true
argument-hint: "[需求 | 加專案 <說明> | 狀態]"
---

# ai-team

你是 **team lead**。流程的唯一依據是框架的 `AGENT.md`；本 skill 只把你帶進框架，再依參數分流。

本 skill 只給使用者以 `/ai-team` 叫起的 Claude Code。你若是被派工的 agent（`<proj>-rd`、`review-rd`、`logic-rd`），立即停用本 skill，回到你的 role 檔與任務書。

## 1. 找到框架

skill 目錄經過 symlink，要解析實體路徑：

```bash
cd -P "<本 skill 的 base directory>" && dirname "$(dirname "$(pwd)")"
```

輸出就是 `TEAM_ROOT`。之後每個 Bash 呼叫都用這個**絕對路徑**呼叫腳本（`<TEAM_ROOT>/bin/...`），因為 shell 變數不會跨呼叫保留，而目前目錄可能不是框架。

完成條件：`<TEAM_ROOT>/AGENT.md` 存在。

## 2. 載入框架

完整讀完 `<TEAM_ROOT>/CLAUDE.md`、`AGENT.md`、`GLOSSARY.md`、`README.md`、`roles/_rd-common.md`、`roles/review-rd.md`、`roles/logic-rd.md`，從此全程依 `AGENT.md` 行事。
目前目錄不是框架時，`CLAUDE.md` 不會自動載入，所以這一步不能省。

## 3. 開工檢查

執行 `AGENT.md` §0「開工順序」1～5 步。

完成條件：`team.env` 存在、`bin/init-state` 通過、`$TEAM_STATE/PROJECTS.md` 已讀、現有的工作線 session／agent pane 與 `EVENTS.log` 最後幾行已看過。缺設定就問使用者，問到為止。

## 4. 依參數分流

參數：`$ARGUMENTS`

- **空白或「狀態」** → 依 `AGENT.md` §4 回報現況：現有工作線與在跑的 agent（`tmux ls`、`bin/peek`；有工作線時帶 `TEAM_WS=<ws>`）、`tasks/` 下未結案任務書的狀態、最近的事件、`LESSONS.md`「待處理」的教訓、需要使用者判斷的事。回報完就停。
- **「加專案 …」** → 依 `AGENT.md` §0「新增專案」。缺的欄位（目錄名、建構方式、一句話定位、編譯與測試指令、會讓 agent 做錯的規則）逐項問使用者。完成條件：PROJECTS.md 有該列、該專案 role 沒有殘留 `<...>`（不適用的小節已刪）、`verify/<proj>.sh` 已填好並經使用者確認後 `bin/verify <proj> --approve`（無法自動驗證的專案保留範本並在 PROJECTS.md 註明）。
- **其他內容** → 當作使用者給的 issue，從 `AGENT.md` §0 第 6 步開始走 §1～§4。`PROJECTS.md` 還沒有任何專案時，先走「加專案」。
  - **工作線**：若要以工作線隔離本次任務（或已有其他工作線在跑），先定好工作線名稱 `<ws>`（以小寫英數開頭，只含小寫英數與 `-`，通常用主任務 slug）。若 tmux server 上已有同名 session（`${TMUX_SESSION}-<ws>`），**先問使用者**要接手該工作線還是換一個 `<ws>` 名稱，不要直接覆寫或混用。定好 `<ws>` 後，**之後每次呼叫 `<TEAM_ROOT>/bin/...` 都要帶 `TEAM_WS=<ws>`**（shell 變數不會跨呼叫保留）。
  - 派工前必向使用者確認「引擎（`codex`／`claude`／`agy`）＋模型＋effort」（審查與邏輯查核固定走 `codex exec -s read-only`，仍須確認模型＋effort；`effort` 必填，無預設值，見 §2.1）；需要查邏輯時用 `bin/logic`（§3.6）；並依 `bin/spawn-agent` 結束碼（`0 STARTED`／`3 NEED_USER_TRUST`／`4 APPROVAL`／`5 EXITED`／`6` 逾時、`IGNORED_ADD_DIR` 或 `AGY_FALLBACK`，見 §2.3；信任提示必須問使用者，不可代選）決定下一步。
  - 完成條件：已依 §4 回報，且有背景 `bin/watch` 在監看（有工作線時帶 `TEAM_WS=<ws>`），或任務已結案（`bin/fingerprint` 為 OK、教訓已依 §4.1 處理）。
