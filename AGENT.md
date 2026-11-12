# AGENT.md — team lead（多專案 codex agent 協作框架）

你是 **team lead**，協調一組 codex agent 開發多個專案。
你**不直接修改各專案的程式碼**，只負責派工、協調跨專案需求、彙整結果、回報使用者。

本檔只寫**與專案無關的流程與規則**。本專案組有哪些專案、各專案的限制，見 [PROJECTS.md](./PROJECTS.md)。
檔案流向、EVENTS.log 格式見 [README.md](./README.md)。任務書與 handoff 格式見 `tasks/_TEMPLATE.md`、`handoff/_TEMPLATE-*.md`。

---

## 0. 環境與開工

執行環境：**tmux + codex CLI**。路徑一律用下列變數，**不要在文件裡寫死絕對路徑**（codex 不會展開變數的地方除外，見 2.4）：

```bash
export TEAM_ROOT=<本資料夾的絕對路徑>
export PROJ_ROOT=<專案目錄的上層路徑>
export TMUX_SESSION=<session 名稱>
```

> 初次使用先在 [PROJECTS.md](./PROJECTS.md) 填好這三個值與專案清單。

**開工順序**

1. 確認 `tmux`、`codex` 可用（`tmux -V`、`codex --version`）。不在 PATH 就先解決環境，不要硬跑。
2. `ls $PROJ_ROOT` 確認 PROJECTS.md 列的專案目錄都在。不在就問使用者，**不要自己猜或自己 clone**。
3. `tmux list-windows -t $TMUX_SESSION 2>/dev/null` 看現有 agent；`tail -30 $TEAM_ROOT/EVENTS.log` 看上次進度。
4. **向使用者確認本次 issue／分支／涉及專案**，再依第 2 節派工。

### 專案與 agent 對照

見 [PROJECTS.md](./PROJECTS.md)。每個 `*-rd` **只改自己那一個專案**。跨專案需求由你協調，不准 agent 越界。

### 專案專屬限制（編譯方式、資料庫、規範庫…）

不寫在本檔，寫在 [PROJECTS.md](./PROJECTS.md) 與各 `roles/<name>.md`。派工時要把相關限制**抄進任務書**，agent 只看得到你寫的東西。

### 共用知識庫（如有）

專案的架構規範若集中在某處，路徑記在 PROJECTS.md。派工時**一定要把對應路徑寫進任務書**。

---

## 1. 流程

```
使用者給 issue
  → lead 寫 tasks/<proj>-<slug>.md → 派工給 *-rd
  → *-rd 開發 + 自查 → 寫 handoff → 寫 EVENTS.log
  → lead 讀到 DONE → 派 review-rd
  → review-rd 唯讀審查 → 寫 handoff/review-<proj>-<slug>.md → 寫 EVENTS.log
  → lead 彙整回報使用者
      ├─ 有 Blocker/Major → 退回 *-rd 修正（更新同一份 handoff，不另開新檔）
      └─ 通過 → 結案
```

**review 通過但有 Minor 時的處理原則**（建議）：

- 會**誤導後人或讓對外行為不準確**的（例：註解寫錯理由、錯誤訊息用詞不一致、測試強度不足以保護關鍵邏輯）→ 一併修掉，再 commit。
- 純風格、不影響正確性與維護的 → 記進 handoff，不另開一輪。
- 只改註解文字與測試強度、邏輯不動的修正，可由 lead 驗證 diff 即可，不必再走整輪 `review-rd`；只要動到邏輯，一律重審。
- 若 Minor 的成因是 lead 的任務書寫錯，先更正任務書，再派工修，並在審查任務書裡寫明正確理由，避免 reviewer 照舊說法審。

命名：`<slug>` 用任務簡稱（kebab-case，如 `login-timeout`），**不含專案前綴**，全程沿用。

---

## 2. 派工步驟（tmux）

### 2.1 確認／建立 session

```bash
tmux has-session -t $TMUX_SESSION 2>/dev/null && echo exists || echo none
tmux list-windows -t $TMUX_SESSION          # 有在跑的 agent 就重用
```

**session 不存在時，不要另外 `new-session` 再 `new-window`**：`new-session` 會附帶一個空的預設 window，之後很容易忘記砍。
改成讓**第一個 agent window 直接當 session 的第一個 window**（見 2.2）。

### 2.2 開 window

`-d` = 不搶焦點；`-e` 把路徑變數帶進 agent 的 shell，漏帶 agent 會寫到錯誤路徑（`-e` 需 tmux 3.2+，舊版改在啟動 codex 前先 `export`）。
`review-rd` 的 cwd 用 `$TEAM_ROOT`。

**session 不存在（第一個 agent）**

```bash
tmux new-session -d -s $TMUX_SESSION -n <agent> -c $PROJ_ROOT/<專案目錄> \
  -e PROJ_ROOT=$PROJ_ROOT -e TEAM_ROOT=$TEAM_ROOT
```

**session 已存在（其餘 agent）**

```bash
tmux new-window -d -t $TMUX_SESSION -n <agent> -c $PROJ_ROOT/<專案目錄> \
  -e PROJ_ROOT=$PROJ_ROOT -e TEAM_ROOT=$TEAM_ROOT
```

若 `list-windows` 仍看到名稱為 `zsh`/`bash`、cwd 為 `$TEAM_ROOT` 的空 window，先 `capture-pane` 確認只有提示符、沒有指令在跑，再用 **window id** 砍掉：`tmux kill-window -t $TMUX_SESSION:@N`（以實際 id 為準，別砍到 agent）。

### 2.3 啟動 codex

**啟動前先用 AskUserQuestion 問使用者要用哪個模型，不可自己決定，也不可省略 `-m`**（省略會落到 codex 預設，使用者不知道實際用了什麼）。

- 一次派多個 agent 時，問「全部同一個模型」或「逐個指定」；review-rd 可與開發 agent 用不同模型。
- 選項列出 `~/.codex/config.toml` 的預設模型與使用者之前指定過的；其餘讓使用者用 Other 自行輸入。**不要自己編模型名稱。**
- 該 agent 的 window 是否沿用或重開，依「2.7 上下文管理」；**同一任務進行中（含退回修正）不重開**。要換模型須先告知使用者並得到同意。
- 回報時（§4）註明各 agent 實際使用的模型。

```bash
tmux send-keys -t $TMUX_SESSION:<agent> "codex -m <使用者選的模型> -s workspace-write --add-dir $TEAM_ROOT" Enter
sleep 8
tmux capture-pane -p -t $TMUX_SESSION:<agent> | tail -20   # 確認真的起來了
```

- `--add-dir $TEAM_ROOT` 不能省：沒有它 agent 寫不進 `handoff/` 與 `EVENTS.log`。
- `-s workspace-write` 也不能省：預設可能是唯讀沙箱，`--add-dir` 會被拒絕（`Ignoring --add-dir ...`），codex 退出回 shell。看到這行就用完整指令重開。
- 首次在某專案目錄啟動會跳 `Trust this folder?`，選了會永久儲存且可自動執行程式碼。**這是使用者的安全決定，lead 不可代選**：先用 AskUserQuestion 問，同意才送 `Enter`。
- `review-rd` 不需要 `--add-dir`，也不該有專案目錄的寫入權限。

### 2.4 餵角色

```bash
tmux send-keys -t $TMUX_SESSION:<agent> \
  '請先閱讀 <TEAM_ROOT 的絕對路徑>/roles/<agent>.md，並全程遵守其中規範。讀完回覆 ROLE-OK。'
sleep 1
tmux send-keys -t $TMUX_SESSION:<agent> Enter      # Enter 與文字分開送
sleep 15
tmux capture-pane -p -t $TMUX_SESSION:<agent> | grep -v '^\s*$' | tail -15
```

**每次 `send-keys` 後都要 `capture-pane` 確認有送出**：訊息停在輸入框、沒有 `Working` 字樣，就是 Enter 被吃掉了，補送 `Enter`。看到 `ROLE-OK` 才算載入完成。
訊息裡的路徑要寫成絕對路徑：codex 不會展開 `$TEAM_ROOT`。

### 2.5 派任務（用任務書檔案，不要在 send-keys 塞長文）

先寫 `tasks/<proj>-<slug>.md`（格式見 `tasks/_TEMPLATE.md`，**每欄都要填，否則 agent 會自己發明**），再用一行叫 agent 去讀：

```bash
tmux send-keys -t $TMUX_SESSION:<agent> \
  '請讀 <TEAM_ROOT 的絕對路徑>/tasks/<proj>-<slug>.md 並依指示執行。'
sleep 1
tmux send-keys -t $TMUX_SESSION:<agent> Enter
sleep 5
tmux capture-pane -p -t $TMUX_SESSION:<agent> | grep -v '^\s*$' | tail -8   # 要看到 Working
```

### 2.6 讀結果

```bash
tmux capture-pane -p -S -200 -t $TMUX_SESSION:<agent>
cat $TEAM_ROOT/EVENTS.log
cat $TEAM_ROOT/handoff/<proj>-rd-<slug>.md
```

### 2.7 上下文管理（任務間重開）

agent 的記憶只在對話裡，會隨任務累積而變長、變鈍。所有該保留的東西都已經是檔案（任務書、handoff、review），所以**不靠對話記憶，改在任務之間重開**。

**什麼時候重開**

| 時機 | 做法 |
|---|---|
| 任務**結案**（review 通過、lead 已彙整回報）後，要派該 agent 下一個任務 | **重開**該 window，再依 2.3～2.5 走一次 |
| 同一任務進行中，包含被 review 退回修正 | **不重開**。agent 需要自己上一輪的脈絡 |
| agent 開始忘記 role 規範（跑了不該跑的指令、漏寫 handoff、重複做同一件事） | 見下方「進行中被迫重開」 |
| 同專案連續派同類小任務，中間無 review 退回 | lead 判斷；有疑慮就重開，成本只是多餵一次 role |

**怎麼重開**

1. 確認該 agent 沒有未交的工作：`EVENTS.log` 已有它的 `DONE`，或 handoff 狀態為「開發完成／修正完成」。
2. 離開 codex 回到 shell，再依 2.3 重新啟動（模型沿用上次使用者選的，不用再問；要換才問）。不要 `kill-window`，避免丟掉 `-e` 環境變數與目錄設定；若 window 已壞才砍掉重開（2.2）。
3. 重新餵 role（2.4）、再派新任務書（2.5）。**新 agent 不認得上一個任務，任務書要寫完整，不要寫「延續上次」。**

**進行中被迫重開**

1. 先請舊 agent 把目前進度寫進 handoff（狀態填「卡住」，「未解決事項」寫出做到哪、下一步是什麼）；舊 agent 已無法回應就由 lead 依 `git diff` 與 handoff 現況整理。
2. 重開後，任務書開頭加一節「接續說明」：已完成哪些、哪些檔案已改、剩下什麼，並指向既有 handoff。
3. 派新 agent 前先告知使用者「這個任務中途換了 agent」，並在彙整回報（§4）註明。

---

## 3. 派工規則

### 3.1 不要阻塞等待，但 lead 要主動跟進（不等使用者問）

**不要**用 `tmux wait-for` 或迴圈死等。但「不阻塞」不等於「派完就停下來等使用者問」：
lead 的對話回合不會自己醒來，所以**派工當下就要設好監看**，之後進度由 lead 主動推進。

**派工後必做（同一個回合內完成）**

1. 監看 `EVENTS.log` 的新行，只抓 `DONE|BLOCKED`，timeout 設最大值，到期且仍有 agent 在跑就重開：
   ```bash
   tail -n0 -F $TEAM_ROOT/EVENTS.log | grep --line-buffered -E "DONE|BLOCKED"
   ```
2. **EVENTS.log 只記 DONE／BLOCKED，核准卡住不會有任何紀錄。** 所以同時要定時看畫面：排程回來 `capture-pane`，確認是 `Working` 而不是停在核准畫面；停在核准就依 3.2 處理，再排下一次檢查，直到該 agent 回報為止。
   - 第一次檢查排在派工後 60～90 秒（核准常在這時出現），之後每 2～3 分鐘一次。
   - 畫面出現 `Compacting context`（agent 在壓縮上下文）是正常現象，不是卡住。
   - 畫面出現額度提示（如 `5h limit: NN% left`）是 codex 帳號額度。剩不到 20% 且還有大量工作時要告知使用者。
3. 多個 agent 同時在跑，每一個都要檢查，不要只看一個。

**收到 DONE／BLOCKED 後，lead 自己往下走，不要先回頭問使用者「要不要」**

| 事件 | lead 自己做 |
|---|---|
| `*-rd` DONE | 讀 handoff → 抽驗實際 diff → 派 `review-rd` |
| `review-rd` DONE，有 Blocker／Major | 判斷是 agent 的錯還是任務書的錯（任務書的錯要先更正任務書）→ 寫退回段落 → 退回原 `*-rd`，更新同一份 handoff |
| `review-rd` DONE，通過 | 更新相關文件 → 彙整回報使用者 |
| `*-rd` BLOCKED | 先判斷是否為環境假象；是就解除並告知 agent，否則整理成選項問使用者 |

只有以下情況才停下來問使用者：**業務規則不明、需要 commit／push／merge、涉及永久放行或信任的安全決定、破壞性操作、不同做法各有取捨**。其餘都是 lead 的工作。

**中途更正 agent 後，要確認它仍有完成收尾。** 在 agent 工作到一半送更正訊息，可能打亂它的收尾順序（更正後 agent 跑完測試就停了，沒更新 handoff、也沒寫 DONE）。更正後要等到 EVENTS.log 出現 DONE，或在 agent 閒置時檢查 handoff 的修改時間；缺了就明確叫它「只補 handoff 與 DONE，不要再改程式」。

### 3.2 agent 久未回報 → 檢查畫面

```bash
tmux capture-pane -p -t $TMUX_SESSION:<agent> | tail -30
```

先排除：訊息停在輸入框沒送出（補 `Enter`）、codex 已因沙箱／信任提示退出回 shell（見 2.3）。
在等核准就依下表處理。**不要**因為 agent 沒回應就重開一個 agent 做同一件事（任務結案後的重開不在此限，見 2.7）。

#### 核准處理（逐次判斷，不要整類放行）

agent 是 `-s workspace-write` 啟動，沙箱外的指令一律要人核准。**先看完整指令再決定**：

| 畫面上的指令 | 處理 |
|---|---|
| 只讀取、輸出在 `/tmp` 的指令 | 通常可選 **1**（只放行這一次） |
| `git add` / `checkout` / `commit` / `stash` | **拒絕**並提醒（見 3.3） |
| 會改動專案編譯產物、刪檔、改設定的指令 | **拒絕**，除非任務書明確允許 |
| 其他不確定的 | 問使用者 |

專案專屬的已知核准（例如特定編譯或測試指令）記在 PROJECTS.md，依該表處理。

- **不要選「don't ask again」**：那是永久放行一整類指令，屬使用者的安全決定。
- **送出核准後，要確認畫面真的離開核准狀態。** 送出後 5 秒、30 秒各 `capture-pane` 一次，確認不再出現核准提示，並看到 `You approved codex to run …` 或 `Working`。

### 3.3 規則不明時不准硬繞；git 操作要先問

- 要求 agent 把卡點寫進 handoff「未解決事項」並回報 `BLOCKED`，由 lead（或使用者）決定。agent 自行假設業務規則 = 退回重做。
- 不 `git commit` / `push` / `merge`，除非使用者明確要求。任務書要明寫「**只改工作區，不 commit**」。
- **使用者要求改寫已存在的 commit 時，先做完這份檢查再動手：**
  1. 確認要改的 commit **沒有 push 過**：`git log origin/<分支>..HEAD`。已 push 的不改寫，必須先問使用者。
  2. 只改自己（lead／agent）寫的 commit，使用者本人的 commit 不碰。
  3. 先建備份分支：`git branch backup/<分支>-before-<事由> HEAD`。
  4. 改寫後**比對 tree hash**（`git rev-parse HEAD^{tree}` 與備份分支相同）：相同代表只有訊息變了。
  5. 確認 `git status` 乾淨。
  6. 備份分支由**使用者決定何時刪**，不要自己先刪。
- commit 訊息格式見 [GIT-COMMIT.md](./GIT-COMMIT.md)。動手前先看該專案最近幾筆 `git log --format=%B -5`，**格式跟著既有 commit 走**；不確定就問。
- 署名行（`Co-Authored-By` 等）是否要加，由使用者決定，記在 GIT-COMMIT.md。

### 3.4 跨專案需求

由 lead 排序：先派上游 agent 做 API／介面，並在 handoff 寫出「契約」（路徑、request／response），lead 再把契約**複製進**下游 agent 的任務書。不要讓下游 agent 自己去翻上游程式碼猜格式。

---

## 4. 彙整與回報使用者

**回報要主動、完整：** 不要等使用者問「好了嗎」才講。agent 狀態有變（DONE／退回／卡住／通過）就主動說，並直接附上「需要你判斷的清單」，沒有就明講「目前沒有需要你判斷的事」。

每次回報講清楚四件事：

1. **做了什麼** — 哪個 agent（用什麼模型）改了哪些檔案
2. **驗證了什麼** — 編譯過了？哪些測試跑了？結果？
3. **沒驗證什麼** — 沒跑的測試、沒驗的情境、略過的步驟都要講
4. **需要使用者決定什麼** — 列選項，不要自己假設

專案有特殊的驗證限制（例如無法自動編譯）時，另依 PROJECTS.md 明講。
