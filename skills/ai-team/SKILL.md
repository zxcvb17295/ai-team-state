---
name: ai-team
description: 僅供 Claude Code 的 team lead：帶 codex agent 團隊開發多個專案（ai-team-state 框架）。被派工的 agent 不使用。
disable-model-invocation: true
argument-hint: "[需求 | 加專案 <說明> | 狀態]"
---

# ai-team

你是 **team lead**。流程的唯一依據是框架的 `AGENT.md`；本 skill 只把你帶進框架，再依參數分流。

本 skill 只給使用者以 `/ai-team` 叫起的 Claude Code。你若是被派工的 codex agent（`<proj>-rd`、`review-rd`），立即停用本 skill，回到你的 role 檔與任務書。

## 1. 找到框架

skill 目錄經過 symlink，要解析實體路徑：

```bash
cd -P "<本 skill 的 base directory>" && dirname "$(dirname "$(pwd)")"
```

輸出就是 `TEAM_ROOT`。之後每個 Bash 呼叫都用這個**絕對路徑**呼叫腳本（`<TEAM_ROOT>/bin/...`），因為 shell 變數不會跨呼叫保留，而目前目錄可能不是框架。

完成條件：`<TEAM_ROOT>/AGENT.md` 存在。

## 2. 載入框架

完整讀完 `<TEAM_ROOT>/CLAUDE.md`、`AGENT.md`、`README.md`、`roles/review-rd.md`，從此全程依 `AGENT.md` 行事。
目前目錄不是框架時，`CLAUDE.md` 不會自動載入，所以這一步不能省。

## 3. 開工檢查

執行 `AGENT.md` §0「開工順序」1～5 步。

完成條件：`team.env` 存在、`bin/init-state` 通過、`$TEAM_STATE/PROJECTS.md` 已讀、目前的 agent window 與 `EVENTS.log` 最後幾行已看過。缺設定就問使用者，問到為止。

## 4. 依參數分流

參數：`$ARGUMENTS`

- **空白或「狀態」** → 依 `AGENT.md` §4 回報現況：在跑的 agent（`bin/peek`）、`tasks/` 下未結案任務書的狀態、最近的事件、需要使用者判斷的事。回報完就停。
- **「加專案 …」** → 依 `AGENT.md` §0「新增專案」。缺的欄位（目錄名、建構方式、一句話定位、編譯與測試指令、會讓 agent 做錯的規則）逐項問使用者。完成條件：PROJECTS.md 有該列、該專案 role 沒有殘留 `<...>`（不適用的小節已刪）。
- **其他內容** → 當作使用者給的 issue，從 `AGENT.md` §0 第 6 步開始走 §1～§4。`PROJECTS.md` 還沒有任何專案時，先走「加專案」。完成條件：已依 §4 回報，且有背景 `bin/watch` 在監看，或任務已結案。
