# README — ai-team-state

多專案 codex agent 協作的共用狀態資料夾，也是一套可複製的協作框架。

## 這是什麼

一個 team lead 帶多個開發 agent + 1 個審查 agent，分工開發各自負責的專案。
lead 不寫專案的程式，只派工與彙整。所有協作狀態（任務書、交接、審查、事件）都放在這裡。

## 誰該讀什麼

| 角色 | 入口 |
|------|------|
| team lead | [AGENT.md](./AGENT.md)（流程）、[PROJECTS.md](./PROJECTS.md)（本專案組設定） |
| `*-rd`（開發 agent） | `roles/<name>.md` |
| `review-rd` | [roles/review-rd.md](./roles/review-rd.md) |

## 如何開始（套用到新專案組）

1. 填寫 [PROJECTS.md](./PROJECTS.md)：路徑、專案清單、編譯方式、專屬限制。
2. 每個專案複製 `roles/_TEMPLATE-rd.md` 為 `roles/<proj>-rd.md`，填入該專案的硬規範。
3. 調整 `roles/review-rd.md` 的「各專案必查清單」。
4. 確認三個環境變數（`TEAM_ROOT`、`PROJ_ROOT`、`TMUX_SESSION`）。
5. 依 AGENT.md §0 開工。

## 檔案流向

```
tasks/<proj>-<slug>.md          ← lead 寫，agent 讀
handoff/<proj>-rd-<slug>.md     ← *-rd 寫，review-rd + lead 讀
handoff/review-<proj>-<slug>.md ← review-rd 寫，lead + *-rd 讀
EVENTS.log                      ← 所有 agent append，lead 監看（不進版控）
```

同一個任務從頭到尾用**同一個 `<slug>`**（不含專案前綴）。被退回修正時**更新原 handoff**，不要新增檔案。

## EVENTS.log 格式

一行一事件，append only：

```
2026-01-01 14:32:05 DONE api-rd login-timeout handoff/api-rd-login-timeout.md 新增逾時設定，已編譯與測試通過
2026-01-01 15:10:41 DONE review-rd login-timeout handoff/review-api-login-timeout.md 1 Blocker 2 Minor
2026-01-01 15:48:02 BLOCKED web-rd login-page 等 api 的 response 欄位定義
```

事件類型：`DONE`（完成）/ `BLOCKED`（卡住，需 lead 決定）。

## 目錄

```
ai-team-state/
├── AGENT.md  README.md  PROJECTS.md  GIT-COMMIT.md  CLAUDE.md
├── EVENTS.log          # 不進版控
├── roles/              # _TEMPLATE-rd.md、review-rd.md、各專案 <proj>-rd.md
├── tasks/              # _TEMPLATE.md、各任務書
└── handoff/            # _TEMPLATE-rd.md、_TEMPLATE-review.md、各交接與審查
```
