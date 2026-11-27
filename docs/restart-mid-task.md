# 任務進行中被迫重開 agent

任務做到一半必須重開 agent 時才讀這份（[AGENT.md](../AGENT.md) §2.7）。不要讓新 agent 憑空接手：

1. 先請舊 agent 把目前進度寫進 handoff（狀態填「卡住」，「未解決事項」寫出做到哪、下一步是什麼）；舊 agent 已無法回應就由 lead 依 `git -C <cwd> diff <base commit>` 與 handoff 現況整理。
2. 讓舊引擎結束回到 shell（`codex` 用 `bin/send <agent> '/quit'`，`claude`／`agy` 用 `bin/send <agent> '/exit'`，或請使用者處理），先不要啟動新 agent。
3. 在原任務書開頭補上一節「接續說明」：已完成哪些、哪些檔案已改、剩下什麼，並指向既有 handoff。**「派工基準」（`base commit` 與派工前已存在的改動）不要改**，確保後續 `bin/verify`、`bin/review` 與 `bin/fingerprint` 仍以原本的基準涵蓋整個任務的改動。
4. 先告知使用者「這個任務中途換了 agent」，最後再執行 `bin/spawn-agent` 同參數於原 pane 重開（有工作線時帶 `TEAM_WS=<ws>`；新 agent 啟動時會直接讀取已補完接續說明的原任務書），並在彙整回報（[AGENT.md](../AGENT.md) §4）註明。
