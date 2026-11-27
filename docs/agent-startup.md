# agent 啟動與監看：畫面判讀

[AGENT.md](../AGENT.md) §2.3（啟動）與 §3.1（監看）遇到下列畫面時讀本檔。引擎版本更新後字樣可能改變，遇到不一樣的請用 `bin/peek <agent>` 確認實際文字，並同步更新 `bin/_lib.sh`（或 `team.env`）與本檔。

## 三引擎狀態對照

腳本靠畫面底部字樣與 tmux 前景程式判斷狀態（字樣定義見 `bin/_lib.sh` 的 `working_pat`、`approval_pat`、`TRUST_PATTERN`、`ADDDIR_PATTERN`、`AGY_FALLBACK_PATTERN`；`codex` 亦可在 `team.env` 覆寫 `WORKING_PATTERN` 與 `APPROVAL_PATTERN`）：

| 狀態 | `codex` | `claude` | `agy` |
|---|---|---|---|
| 工作中 | `Working` 或 `(… esc to interrupt)`（`WORKING_PATTERN`） | 狀態列出現 `esc to interrupt` | 行首點字 spinner（`⣾`～`⣷`，如 `⣷  Generating...`、`⣟  Running command...`） |
| 閒置（做完一輪） | `Worked for Ns`、輸入框 `› …`，且底部無 `WORKING_PATTERN` | 狀態列無 `esc to interrupt`，底部顯示輸入框 `❯` | 最底行 `? for shortcuts`，無點字 spinner |
| 信任提示 | `Trust this folder`（預設游標在 Yes） | `Is this a project you created or one you trust`（預設游標在 No） | `Do you trust the contents of this project`（預設游標在 Yes） |
| 核准畫面 | `Would you like to`、`Yes, proceed`、`don't ask again`、`Allow command` 等（見 [manual-approval.md](./manual-approval.md)） | `Do you want to proceed`、`This command requires approval`（見 [manual-approval.md](./manual-approval.md)） | `Requesting permission for`、`Run this command?`、`Allow access to this file?`（見 [manual-approval.md](./manual-approval.md)） |
| 已退出 | pane 前景回到 shell（執行中多為 `node`／`codex`） | pane 前景回到 shell（執行中為 `claude`） | pane 前景回到 shell（執行中為 `agy`），畫面留 `Resume with -c` |

## 各引擎共通

- **`Compacting context`／`Compacting conversation`**：表示 agent 正在壓縮上下文，是正常現象，不是卡住，繼續等即可。
- **字樣誤判或漏判**：先用 `bin/peek <agent>` 確認實際文字；`codex` 可經使用者同意調整 `team.env` 的 `APPROVAL_PATTERN`／`WORKING_PATTERN`，`claude`／`agy` 則更新 `bin/_lib.sh` 與本檔。
- **任務書路徑一律寫絕對路徑**：不同引擎對子行程環境變數的繼承行為不同（例如 `codex` 不會繼承部分外層環境變數），因此檔案與 `bin/event` 路徑一律以絕對路徑寫在任務書與啟動 prompt 裡。

## `codex`

- **額度提示（`5h limit: NN% left`）**：這是 codex 帳號額度。剩不到 20% 且還有大量工作時要告知使用者，額度耗盡 agent 會停擺。
- **啟動時的 `⚠ 1 warning`**：例如 `Running without the shared background server ... requires embedded mode.` 屬無害提示，**不要按 F2／Esc 去看**。
- **啟動時載入 MCP**：若本機 codex 設定有 MCP server，啟動畫面可能短暫出現 `Starting MCP servers (... • esc to interrupt)`，腳本會視為工作中，屬正常。
- **停在 `Queued follow-up inputs`**：啟動後或送出訊息後一直停在 `Queued follow-up inputs`、沒有開始工作時，先用 `bin/peek <agent>` 確認；若重開一次仍同，直接告知使用者，不要反覆重試。
- **避免混用 `--approve-for-me` 與 `-s workspace-write`**：部分 codex 版本不允許兩者並用（會直接報錯退回 shell）。框架 `bin/_launch` 固定使用 `-s workspace-write -a "$CODEX_APPROVAL"`，不要隨意疊加衝突旗標。

## `claude`

- **提示畫面的 `Down` 鍵偶爾被當成 `Esc`**：在信任或 `--add-dir` 提示按 `Down` 時偶爾會被判為 `Esc` 而直接退出（`bin/spawn-agent` 回傳 exit 5 `EXITED`）；重新執行 `bin/spawn-agent` 即可。
- **`--add-dir` 提示（`Adding a new directory`）**：部分版本以命令列 `--add-dir` 啟動不會跳此提示；若跳出，`bin/spawn-agent` 會自動 `Down` → 確認 `❯` 指在 `Yes` → `Enter`（最多重試 3 次）。
- **啟動後第一個回應可能較慢**：讀取 role 與任務書期間畫面可能暫時停在等待動畫而尚未出現工具呼叫。`bin/spawn-agent` 最多等 90 秒，逾時回傳 exit 6（`TIMEOUT`）；用 `bin/peek <agent>` 看到 `esc to interrupt` 就代表還在跑，直接開 `bin/watch` 即可。
- **首次啟用 auto mode 的確認畫面**：若出現確認畫面，比照信任提示先問使用者，lead 不代選。
- **額度共用**：若 lead 與開發 agent 使用同一個 Claude 帳號，兩者共用額度；出現接近上限提示時告知使用者。

## `agy`（Antigravity CLI）

- **底部的 `esc to cancel` 不代表工作中**：停在核准畫面時它也在最底行。`bin/_lib.sh` 的 `agy` 工作中字樣使用點字 spinner（`⣾`～`⣷`），**不可改成 `esc to cancel`**，否則 `bin/watch` 與 `bin/spawn-agent` 會抓不到核准畫面。
- **模型或 effort 不相容時不會退出**：畫面會出現 `conflicts with --effort` 或 `is not supported for model` 警告，接著自動換成其他模型開工。`bin/spawn-agent` 啟動前會先查 `agy models`，啟動後也會偵測畫面，抓到即以 exit 6（`AGY_FALLBACK`）結束；此時它已在工作，lead 須先 `bin/send <agent> '/exit'` 停掉、查明再重開。
- **信任提示游標預設在 Yes，且不沿用到子目錄**：停在 `NEED_USER_TRUST`（exit 3）時絕不可盲送 `Enter`；每個新專案目錄第一次使用 `agy` 都會詢問信任。
- **互動模式（`-i`）**：`bin/_launch` 使用 `--mode auto --add-dir "$TEAM_STATE" -i "$prompt"` 保持互動並讓 auto mode 生效（非互動 print 模式 `-p` 可能不支援 auto mode）。
- **啟動公告橫幅無害**：例如新模型推出公告，不影響執行。
- **額度獨立**：`agy` 使用 Google 帳號額度，與 `codex`／`claude` 額度各自獨立。
