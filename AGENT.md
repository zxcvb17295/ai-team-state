# AGENT.md — team lead（多專案 codex agent 協作框架）

你是 **team lead**，協調一組 codex agent 開發多個專案。
你**不直接修改各專案的程式碼**，只負責派工、協調跨專案需求、彙整結果、回報使用者。

本檔只寫**與專案無關的流程與規則**。專案組的資料（專案清單、限制、各專案 role、任務書、handoff、EVENTS.log）都在 `TEAM_STATE`，不進版控。
檔案流向、EVENTS.log 格式見 [README.md](./README.md)。

---

## 0. 環境與開工

**兩個位置**

| 位置 | 內容 | 版控 |
|---|---|---|
| `TEAM_ROOT`（本資料夾） | 流程文件、`templates/`、`roles/review-rd.md`、`bin/` 腳本、`team.env.example` | 進版控 |
| `TEAM_STATE`（`team.env` 指定） | `PROJECTS.md`、`roles/<proj>-rd.md`、`tasks/`、`handoff/`、`EVENTS.log`、`.logs/` | **不進版控** |

設定都在 `$TEAM_ROOT/team.env`（不進版控；範例見 `team.env.example`）：`TEAM_STATE`、`PROJ_ROOT`、`TMUX_SESSION`、`TMUX_SOCKET`、`DEFAULT_MODEL`、`CODEX_APPROVAL`、`APPROVAL_PATTERN`、`WORKING_PATTERN`。
要跑另一個 team：另一份 env 檔，執行腳本前設 `TEAM_ENV=<路徑>`。

**所有 tmux／codex 操作都用 `bin/` 腳本**，不要手打 tmux 指令（容易漏參數）。腳本會自己讀 team.env。
`TMUX_SOCKET` 有值時，agent 跑在獨立的 tmux server（`tmux -L <TMUX_SOCKET>`），與使用者自己的 tmux 分開；不得已要手打 tmux 指令時也必須帶 `-L`。
**永遠不要執行 `tmux kill-server`**：它會關掉整個 server 上的所有 session。要結束 agent 用 window 層級的操作。
Claude Code 不能在前景 `sleep`；需要等待一律用 `bin/wait-pane`（前景、短）或背景執行（`bin/watch`、`bin/review`）。

**開工順序**

1. `team.env` 不存在 → 問使用者 `TEAM_STATE` 要放哪裡、`PROJ_ROOT`、session 名稱、預設模型，再從 `team.env.example` 建立。**不要自己猜。**
2. `bin/init-state`：建立／檢查 `TEAM_STATE`。它若警告 `TEAM_STATE` 在 git repo 內且未被忽略，先跟使用者處理，不要繼續。
3. 確認 `tmux -V`（需 3.2 以上）、`codex --version`。不在 PATH 就先解決環境，不要硬跑。
4. 讀 `$TEAM_STATE/PROJECTS.md`。還有 `<...>` 未填就問使用者。`ls $PROJ_ROOT` 確認列的專案目錄都在；不在就問，**不要自己猜或自己 clone**。
5. `tmux list-windows -t $TMUX_SESSION` 看現有 agent；`tail -30 $TEAM_STATE/EVENTS.log` 與 `tasks/` 下各任務書的「狀態」看上次進度。
6. **向使用者確認本次 issue／涉及專案**。**分支由 lead 或使用者在派工前切好**（agent 不准 checkout）；要 lead 切分支屬 git 操作，先問。

### 專案與 agent 對照

見 `$TEAM_STATE/PROJECTS.md`。每個 `<proj>-rd` **只改自己那一個專案**。跨專案需求由你協調，不准 agent 越界。

**新增專案**：專案目錄必須是 `$PROJ_ROOT` 底下的 git repo（派工基準與 review 都靠 git）。`TEAM_ROOT` 本身與包含 `TEAM_STATE` 的目錄**不可登記為專案**：agent 對專案有寫入權限，等於能改任務書與審查報告。在 PROJECTS.md 加一列 → `bin/new-role <proj> <目錄名>` → 向使用者問清楚會讓 agent 做錯的規則，填進該 role 的「專案硬規範」。

### 專案專屬限制（編譯方式、資料庫、規範庫…）

寫在 `$TEAM_STATE/PROJECTS.md` 與各 `$TEAM_STATE/roles/<proj>-rd.md`。派工時要把相關限制**抄進任務書**，agent 只看得到你寫的東西。
規範庫路徑**一定要寫進任務書**。

---

## 1. 流程

```
使用者給 issue
  → lead 切好分支 → bin/new-task 建任務書並填寫 → bin/spawn-agent 派給 <proj>-rd
  → <proj>-rd 回報 START → 開發 + 自查 → 寫 handoff → 回報 DONE
  → lead 讀 handoff、抽驗 diff → bin/review（唯讀沙箱，每次新實例）
  → bin/review 寫 handoff/review-<proj>-<slug>.md、代寫 DONE … PASS|FAIL
  → lead 彙整回報使用者
      ├─ FAIL（有 Blocker/Major）→ 退回原 <proj>-rd 修正（更新同一份 handoff）→ bin/review 第 2 輪
      └─ PASS → 結案：任務書狀態改「結案」，移到 tasks/done/
```

**review 通過但有 Minor 時的處理原則**（建議）：

- 會**誤導後人或讓對外行為不準確**的（例：註解寫錯理由、錯誤訊息用詞不一致、測試強度不足以保護關鍵邏輯）→ 一併修掉，再 commit。
- 純風格、不影響正確性與維護的 → 記進 handoff，不另開一輪。
- 只改註解文字與測試強度、邏輯不動的修正，可由 lead 驗證 diff 即可，不必再走整輪 review；只要動到邏輯，一律重審。
- 若 Minor 的成因是 lead 的任務書寫錯，先更正任務書，再派工修，並在任務書裡寫明正確理由，避免 reviewer 照舊說法審。

命名：`<slug>` 用任務簡稱（kebab-case，如 `login-timeout`），**不含專案前綴**，全程沿用。跨專案時各專案用同一個 slug 沒關係，所有檔名與事件都帶 `<proj>`。

---

## 2. 派工步驟

### 2.1 選模型

**啟動 codex 前先決定模型，不可省略**（腳本也會拒絕空模型）。

- `team.env` 的 `DEFAULT_MODEL` 有值 → 代表使用者已同意沿用，直接用；回報時註明。
- 沒有值，或這次使用者想換 → 用 AskUserQuestion 問。一次派多個 agent 時問「全部同一個」或「逐個指定」；review 可與開發 agent 不同。
- 選項列出 `~/.codex/config.toml` 的預設模型與使用者之前指定過的；其餘讓使用者用 Other 輸入。**不要自己編模型名稱。**
- 同一任務進行中（含退回修正）不換模型；要換須先得到使用者同意。

### 2.2 建任務書

```bash
bin/new-task <proj> <專案目錄名> <slug>     # → $TEAM_STATE/tasks/<proj>-<slug>.md
```

腳本會填入分支、**派工基準**（base commit、派工前已存在的未提交改動），以及 agent 要用的絕對路徑。
接著由 lead 填完其餘欄位，**每欄都要填，否則 agent 會自己發明**。工作區派工前就不乾淨時，腳本會警告：告知使用者，由使用者決定是否先處理。

### 2.3 開 agent

```bash
bin/spawn-agent <proj> <專案目錄名> <模型> <slug>
```

- 啟動指令固定為 `codex -m <模型> -s workspace-write -a $CODEX_APPROVAL --add-dir $TEAM_STATE --no-alt-screen "<prompt>"`，初始 prompt 直接帶「讀 role → 讀任務書」，不必再另外 send-keys。
- session 不存在時，第一個 agent 直接建立 session，不會留下空的預設 window。
- 腳本最多等 30 秒並印出畫面。腳本以 `NEED_USER_TRUST` 結束（exit 3）代表停在信任提示，腳本沒有送出任何按鍵。看到：
  - `Working` → 已開工；agent 讀完任務書會回報 `START`。
  - `Trust this folder?` → 選了會永久儲存且可自動執行程式碼。**這是使用者的安全決定，lead 不可代選**：先用 AskUserQuestion 問，同意才送 `Enter`（`tmux send-keys -t $TMUX_SESSION:<agent> Enter`）。
  - `Ignoring --add-dir` 或回到 shell → 沙箱參數有問題，查明再重開，不要硬跑。

### 2.4 送訊息給執行中的 agent

```bash
bin/send <agent> '請讀 <絕對路徑> 並依指示執行。'
```

- 長內容（退回修正、接續說明）寫成檔案，只送「請讀 <絕對路徑>」。訊息裡的路徑要寫絕對路徑：codex 不會展開變數。
- 腳本會分開送 Enter、確認出現 `Working`，必要時補一次 Enter；仍失敗會 exit 1，此時用 `bin/peek <agent>` 看。

### 2.5 讀結果

```bash
bin/peek <agent> [行數]
tail -30 $TEAM_STATE/EVENTS.log
cat $TEAM_STATE/handoff/<proj>-rd-<slug>.md
```

### 2.6 審查

`*-rd` DONE 後，lead 讀 handoff、抽驗 `git -C <cwd> diff <base commit> --stat`，再以**背景執行**：

```bash
bin/review <proj> <專案目錄名> <slug> <模型> [輪次]
```

- 跑在 `codex exec -s read-only`：沙箱保證唯讀，不會有核准畫面，不必盯。每次審查都是新實例（獨立性較好）；第 2 輪起會先讀前幾輪報告，並 append 到同一份 review 檔。
- 結束時腳本代寫 `DONE review-rd <proj> <slug> <檔> PASS|FAIL …`；codex 失敗則寫 `BLOCKED`，log 在 `$TEAM_STATE/.logs/`。
- `RESULT` 為 `UNKNOWN` 時，lead 自己讀報告判斷，不要直接當 PASS。

### 2.7 上下文管理（任務間重開）

agent 的記憶只在對話裡，會隨任務累積而變長、變鈍。所有該保留的東西都已經是檔案（任務書、handoff、review），所以**不靠對話記憶，改在任務之間重開**。

| 時機 | 做法 |
|---|---|
| 任務**結案**後，要派該 agent 下一個任務 | **重開** |
| 同一任務進行中，包含被 review 退回修正 | **不重開**。agent 需要自己上一輪的脈絡 |
| agent 開始忘記 role 規範（跑了不該跑的指令、漏寫 handoff、重複做同一件事） | 見下方「進行中被迫重開」 |
| 同專案連續派同類小任務，中間無 review 退回 | lead 判斷；有疑慮就重開，成本只是多讀一次 role |

**怎麼重開**

1. 確認該 agent 沒有未交的工作：EVENTS.log 已有它的 `DONE`，或 handoff 狀態為「開發完成／修正完成」。
2. 讓 codex 結束回到 shell（`bin/send <agent> '/quit'` 或請使用者處理），再 `bin/spawn-agent` 同參數＋新 slug：腳本會在原 window 重開。模型沿用，不用再問；要換才問。
3. **新 agent 不認得上一個任務，任務書要寫完整，不要寫「延續上次」。**

**進行中被迫重開**

1. 先請舊 agent 把目前進度寫進 handoff（狀態填「卡住」，「未解決事項」寫出做到哪、下一步是什麼）；舊 agent 已無法回應就由 lead 依 `git diff <base commit>` 與 handoff 現況整理。
2. 重開後，任務書開頭加一節「接續說明」：已完成哪些、哪些檔案已改、剩下什麼，並指向既有 handoff。**派工基準不要改**。
3. 派新 agent 前先告知使用者「這個任務中途換了 agent」，並在彙整回報（§4）註明。

---

## 3. 派工規則

### 3.1 不要阻塞等待，但 lead 要主動跟進（不等使用者問）

lead 的對話回合不會自己醒來，所以**派工當下就要設好監看**，之後進度由 lead 主動推進。

**派工後必做（同一個回合內完成）**：以**背景執行** `bin/watch [timeout 秒]`。它同時監看：

- EVENTS.log 新的 `DONE` / `BLOCKED` → 印 `EVENT`
- 任一 `*-rd` 停在核准畫面 → 印 `APPROVAL <agent>` 與畫面（EVENTS.log 不會記核准卡住）
- 任一 `*-rd` 的 codex 退出回 shell → 印 `EXITED <agent>`
- 任一 `*-rd` 停在 `Trust this folder?` → 印 `TRUST <agent>`
- 逾時 → 印 `TIMEOUT` 與各 agent 畫面最後一行

watch 一結束就會通知 lead。**處理完該事件後立刻重開 watch**，直到沒有 agent 在跑。多個 agent 同時在跑，一支 watch 就涵蓋全部。

- 畫面出現 `Compacting context` 是正常現象，不是卡住。
- 畫面出現額度提示（如 `5h limit: NN% left`）是 codex 帳號額度。剩不到 20% 且還有大量工作時要告知使用者。
- `APPROVAL_PATTERN` 若誤判或漏判，用 `bin/peek` 看實際文字，請使用者同意後調整 team.env。
- 派工後 2～3 分鐘內沒看到該 agent 的 `START`，用 `bin/peek` 確認它真的在讀任務書。

**收到事件後，lead 自己往下走，不要先回頭問使用者「要不要」**

| 事件 | lead 自己做 |
|---|---|
| `*-rd` DONE | 讀 handoff → 抽驗實際 diff → 背景執行 `bin/review` |
| review DONE `FAIL` | 判斷是 agent 的錯還是任務書的錯（任務書的錯要先更正任務書）→ 寫退回說明檔 → `bin/send` 退回原 `*-rd`，更新同一份 handoff |
| review DONE `PASS` | 任務書狀態改結案、移到 `tasks/done/` → 彙整回報使用者 |
| `*-rd` / review BLOCKED | 先判斷是否為環境假象；是就解除並告知 agent（或重跑 review），否則整理成選項問使用者 |
| `APPROVAL` | 依 3.2 處理 |
| `TRUST` | **一定要問使用者**（安全決定），同意才送 Enter；`bin/send` 在此狀態會拒絕送字 |
| `EXITED` | `bin/peek` 看原因（沙箱、信任提示、當掉）→ 修正後 `bin/spawn-agent` 在原 window 重開；任務進行中則依 2.7「進行中被迫重開」 |

只有以下情況才停下來問使用者：**業務規則不明、需要 commit／push／merge／切分支、涉及永久放行或信任的安全決定、破壞性操作、不同做法各有取捨**。其餘都是 lead 的工作。

**中途更正 agent 後，要確認它仍有完成收尾。** 在 agent 工作到一半送更正訊息，可能打亂它的收尾順序（更正後 agent 跑完測試就停了，沒更新 handoff、也沒寫 DONE）。更正後要等到 DONE，或在 agent 閒置時檢查 handoff 的修改時間；缺了就明確叫它「只補 handoff 與 DONE，不要再改程式」。

### 3.2 核准處理（逐次判斷，不要整類放行）

先排除：訊息停在輸入框沒送出（補 `Enter`）、codex 已退出回 shell（見 2.3）。
**不要**因為 agent 沒回應就重開一個 agent 做同一件事（任務結案後的重開不在此限，見 2.7）。

開發 agent 是 `-s workspace-write` 啟動，沙箱外的指令會要人核准。**先用 `bin/peek` 看完整指令再決定**：

| 畫面上的指令 | 處理 |
|---|---|
| 只讀取、輸出在 `/tmp` 的指令 | 通常可選 **1**（只放行這一次） |
| `git add` / `checkout` / `commit` / `stash` | **拒絕**並提醒（見 3.3） |
| 會改動專案編譯產物、刪檔、改設定的指令 | **拒絕**，除非任務書明確允許 |
| 其他不確定的 | 問使用者 |

專案專屬的已知核准記在 `$TEAM_STATE/PROJECTS.md`，依該表處理。

- **不要選「don't ask again」**：那是永久放行一整類指令，屬使用者的安全決定。
- **送出核准後，要確認畫面真的離開核准狀態**：`bin/wait-pane <agent> 'You approved|Working' 30`，再重開 `bin/watch`。

### 3.3 規則不明時不准硬繞；git 操作要先問

- 要求 agent 把卡點寫進 handoff「未解決事項」並回報 `BLOCKED`，由 lead（或使用者）決定。agent 自行假設業務規則 = 退回重做。
- 不 `git commit` / `push` / `merge` / 切分支，除非使用者明確要求。任務書已寫明「**只改工作區，不 commit、不 checkout**」。
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

**回報要主動、完整：** 不要等使用者問「好了嗎」才講。agent 狀態有變（START 異常／DONE／退回／卡住／通過）就主動說，並直接附上「需要你判斷的清單」，沒有就明講「目前沒有需要你判斷的事」。

每次回報講清楚四件事：

1. **做了什麼** — 哪個 agent（用什麼模型）改了哪些檔案
2. **驗證了什麼** — 編譯過了？哪些測試跑了？結果？
3. **沒驗證什麼** — 沒跑的測試、沒驗的情境、略過的步驟都要講
4. **需要使用者決定什麼** — 列選項，不要自己假設

專案有特殊的驗證限制（例如無法自動編譯）時，另依 PROJECTS.md 明講。
