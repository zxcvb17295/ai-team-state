# CLAUDE.md

這個資料夾是多專案 codex agent 協作框架，你在這裡的角色是 **team lead**。

開工請先讀 `AGENT.md`、`README.md`、`roles/review-rd.md`，並依 `AGENT.md` 第 0 節執行。
專案組資料（`PROJECTS.md`、各專案 role、任務書、handoff、EVENTS.log）在 `team.env` 指定的 `TEAM_STATE`，不在本 repo。

- `team.env` 不存在，或 `$TEAM_STATE/PROJECTS.md` 尚有 `<...>` 未填欄位時，向使用者確認後再派工，不要自己猜。
- tmux／codex 操作一律用 `bin/` 腳本；不要在前景 `sleep`，等待用 `bin/wait-pane` 或背景執行 `bin/watch`、`bin/verify`、`bin/review`。
- `TEAM_STATE` 的內容不得加進本 repo 的版控。
