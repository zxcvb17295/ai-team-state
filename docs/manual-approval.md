# 人工核准：各引擎畫面、判斷與按鍵差異

開發 agent 停在核准畫面時才讀本檔（[AGENT.md](../AGENT.md) §3.2）。

- **`codex`**：以 `-s workspace-write -a $CODEX_APPROVAL` 啟動。`on-request` 下沙箱外的指令會跳核准畫面；`never` 下直接失敗回給 agent。
- **`claude`**：以 `--permission-mode auto` 搭配 `bootstrap/claude-rd.settings.json`（有 `$TEAM_ROOT/.local/claude-rd.settings.json` 時再加上其中的 deny）啟動。正常不會出現核准畫面；若出現代表 auto mode 未生效，先告知使用者再依下表處理。
- **`agy`**：以 `--mode auto` 搭配全域 hook `bootstrap/agy-gate.py` 啟動。auto mode 只自動放行編輯與安全的指令，其他指令或跨目錄讀檔會正常跳核准畫面，因此 `agy` 較常遇到。

## 通用判斷原則（各引擎相同）

先用 `bin/peek <agent>` 看完整指令與目標路徑再決定，**逐次判斷，不可整類或永久放行**：

| 畫面上的指令／操作 | 處理 | 原因 |
|---|---|---|
| 只讀取、輸出在 `/tmp` 的指令 | 通常可選**只放行這一次**（1） | 不改動專案檔與工作區 |
| `git add` / `checkout` / `commit` / `stash` / `push` / `merge` / `reset` / `restore` / `autocrlf` 等 | **拒絕**並提醒 | git 寫入操作由使用者執行（見 [AGENT.md](../AGENT.md) §3.3） |
| 修改建置產物、刪檔、改外部設定的指令 | **拒絕**，除非任務書明確允許 | 避免破壞工作區或環境 |
| 讀取任務書列為必讀／參考的外部檔案（如 `agy` 的 `File access`） | 選**這一次放行**（1） | 任務書明確要求的唯讀參考 |
| 其他不在表內或不確定的 | 先看完整指令，不確定就問使用者 | 安全邊界由使用者決定 |

專案專屬的已知核准項目記在 `$TEAM_STATE/PROJECTS.md`「已知會出現的核准」，優先依該表處理。

## 各引擎畫面與按鍵差異（切勿套錯）

> **核准畫面下 `bin/send` 會拒送**。確認處理方式後，先查該角色的 pane id：
> `tmux list-panes -s -t "=$TMUX_SESSION" -F '#{pane_id} #{@role} #{@engine}'`（有 `TMUX_SOCKET` 需加 `-L`，有工作線 session 為 `${TMUX_SESSION}-<ws>`），再以 `tmux send-keys -t <pane_id> ...` 送鍵。

### `codex`

- 畫面字樣：`Would you like to`、`Yes, proceed`、`don't ask again`、`Allow command` 等（`APPROVAL_PATTERN`）。
- 按鍵：**1＝只放行這一次**、2＝永久放行（`don't ask again`）、**3＝拒絕**。
- 不可選 **2**（永久放行屬使用者的安全決定）。

### `claude`

- 畫面字樣：`This command requires approval` / `Do you want to proceed?`。
- 按鍵：**1＝Yes（只放行這一次）**、2＝`Yes, and don't ask again for: <指令> *`、3＝`Yes, and switch to auto mode`、**4＝No（拒絕）**。
- **拒絕是 4，不是 3。** 選項 3 會切換為 auto mode：agent 預設就該是 auto mode，看到此畫面代表 auto mode 未生效，應先告知使用者，不要自行選 3。
- 不可選 **2**（整類永久放行）。
- 操作方式：用 `Down` 移動游標，經 `bin/peek <agent>` 確認 `❯` 指著目標選項後再送 `Enter`，不要盲送數字。
- 選 No 後畫面會顯示 `Interrupted · What should Claude do instead?` 並回到輸入框，接著送一句提醒（說明為何拒絕與替代做法）再送 `Enter`。
- 落在 `claude-rd.settings.json` `deny` 清單內的指令不會跳核准畫面，agent 會直接看到被設定拒絕的訊息。

### `agy`（Antigravity CLI）

- **指令核准畫面**（`Requesting permission for: <指令>` / `Run this command?`）：
  - 按鍵：**1＝`Yes, run command`（只放行這一次）**、2＝本次對話同前綴皆放行、3＝同前綴永久放行（寫入設定檔）、**4＝`No, cancel`（拒絕）**。
  - **拒絕是 4，不是 3。** 預設游標在 1：用 `Down` 移動，經 `bin/peek <agent>` 確認 `>` 指著目標選項後再送 `Enter`，不要盲送數字。
  - 不可選 **2** 或 **3**（整類／永久放行屬使用者的安全決定）。
- **檔案存取畫面**（`File access` / `Allow access to this file?`，讀取 workspace 以外的檔案時出現）：
  - 按鍵：**1＝只放行這一次**、2＝永久放行所有 workspace 以外的檔案存取、**3＝拒絕**。
  - 任務書列出的背景檔案選 **1**；**不可選 2**（全域永久放行屬使用者的安全決定）。
  - 剛在信任提示選 Yes 的該次啟動，部分版本可能對 workspace 內的檔案也逐檔跳 `File access`（僅 1 放行／2 拒絕）：信任已寫入設定檔，若 agent 尚未改檔，可送 `Escape` 中斷 → `bin/send <agent> '/exit'` → 以原參數重開 `bin/spawn-agent`。
- 落在 `bootstrap/agy-gate.py` `deny` 清單內的指令或越界寫入不會跳核准畫面，agent 會直接看到 `tool call denied by pre-tool hook: ai-team-state：…`。

## 送出核准後：確認已離開核准畫面

送出按鍵後，畫面短暫重畫成輸入框不代表已放行，務必用 `bin/wait-pane` 確認出現工作中字樣（有工作線時帶 `TEAM_WS=<ws>`），再重開 `bin/watch`：

- **`codex`／`claude`**：
  ```bash
  bin/wait-pane <agent> 'You approved|Working|esc to interrupt' 30
  ```
- **`agy`**：
  ```bash
  bin/wait-pane <agent> '⣾|⣽|⣻|⢿|⡿|⣟|⣯|⣷|Running command|Generating' 30
  ```
  **不可用 `esc to cancel`**：停在核准畫面時 `esc to cancel` 也在最底行，會誤判為已離開核准畫面。
