# AGENT.md — team lead（多專案多引擎 agent 協作框架）

你是 **team lead**，協調一組開發 agent（支援 `codex`、`claude`、`agy`）與唯讀審查／邏輯查核 agent 開發多個專案；角色、引擎、模型、agent 等協作模型用語見 [GLOSSARY.md](./GLOSSARY.md)。
你**不直接修改各專案的程式碼**，只負責派工、協調跨專案需求、彙整結果、回報使用者。

本檔只寫**與專案無關的流程與規則**。專案組的資料（專案清單、限制、各專案 role、任務書、handoff、EVENTS.log）都在 `TEAM_STATE`，不進版控。
檔案流向、EVENTS.log 格式見 [README.md](./README.md)。

---

## 0. 環境與開工

**兩個位置**

| 位置 | 內容 | 版控 |
|---|---|---|
| `TEAM_ROOT`（本資料夾） | 流程文件、[GLOSSARY.md](./GLOSSARY.md)、`docs/`、`templates/`、`roles/_rd-common.md`、`roles/review-rd.md`、`roles/logic-rd.md`、`bootstrap/`（`claude-rd.settings.json`、`agy-gate.py`、`install-agy-hook.sh`）、`bin/` 腳本、`team.env.example` | 進版控 |
| `TEAM_STATE`（`team.env` 指定） | `PROJECTS.md`、`roles/<proj>-rd.md`、`tasks/`、`handoff/`、`EVENTS.log`、`.logs/` | **不進版控** |

設定都在 `$TEAM_ROOT/team.env`（不進版控；範例見 `team.env.example`）：`TEAM_STATE`、`PROJ_ROOT`、`TMUX_SESSION`、`TMUX_SOCKET`、`TEAM_LAYOUT`、`CODEX_BIN`、`CLAUDE_BIN`、`AGY_BIN`、`AGY_HOOKS_FILE`、`DEFAULT_MODEL`、`CODEX_APPROVAL`、`APPROVAL_PATTERN`、`WORKING_PATTERN`。
要跑另一個 team：另一份 env 檔，執行腳本前設 `TEAM_ENV=<路徑>`。同一個 team 內同時跑多個任務：用工作線 `TEAM_WS=<ws>`（見下方「工作線」）。

**所有 tmux／引擎操作都用 `bin/` 腳本**，不要手打 tmux 指令（容易漏參數）。腳本會自己讀 team.env。
`TMUX_SOCKET` 有值時，agent 跑在獨立的 tmux server（`tmux -L <TMUX_SOCKET>`），與使用者自己的 tmux 分開；不得已要手打 tmux 指令時也必須帶 `-L`。
**永遠不要執行 `tmux kill-server`**：它會關掉整個 server 上的所有 session。要結束 agent 用 pane 層級的操作（`tmux kill-pane`），且不要動別條工作線的 session。
Claude Code 不能在前景 `sleep`；需要等待一律用 `bin/wait-pane`（前景、短）或背景執行（`bin/watch`、`bin/verify`、`bin/review`、`bin/logic`）。

**開工順序**

1. `team.env` 不存在 → 問使用者 `TEAM_STATE` 要放哪裡、`PROJ_ROOT`、session 名稱、預設模型，再從 `team.env.example` 建立。**不要自己猜。**
2. `bin/init-state`：建立／檢查 `TEAM_STATE`。它若警告 `TEAM_STATE` 在 git repo 內且未被忽略，先跟使用者處理，不要繼續。
3. 確認 `tmux -V`（需 3.2 以上）以及本次會用到的引擎 CLI 在 PATH（`codex --version`、`claude --version`、`agy --version`；`bin/review` 與 `bin/logic` 固定用 `codex`）。若會派 `agy` 開發 agent，首次使用須先跑 `bash "$TEAM_ROOT/bootstrap/install-agy-hook.sh"` 註冊全域安全 hook。不在 PATH 就先解決環境，不要硬跑。
4. 讀 `$TEAM_STATE/PROJECTS.md`。還有 `<...>` 未填就問使用者。`ls $PROJ_ROOT` 確認列的專案目錄都在；不在就問，**不要自己猜或自己 clone**。
5. `tmux ls` 看現有工作線 session（有 `TMUX_SOCKET` 需加 `-L`），並用 `tmux list-panes -s -t "=$TMUX_SESSION" -F '#{pane_id} #{@role} #{@engine} #{pane_current_command}'` 看本 session 現有 agent（有工作線時 session 為 `${TMUX_SESSION}-<ws>`）；`tail -30 $TEAM_STATE/EVENTS.log` 與 `tasks/` 下各任務書的「狀態」看上次進度。
6. **向使用者確認本次 issue／工作線名稱（若開工作線）／涉及專案**。**分支由 lead 或使用者在派工前切好**（agent 不准 checkout）；要 lead 切分支屬 git 操作，先問。

### 工作線（同時跑多個任務）

每個 lead 可負責一條**工作線**，用 `TEAM_WS=<ws>` 區分（`<ws>` 用主任務簡稱，必須以小寫英數開頭、只能含小寫英數與 `-`，如 `login-timeout`）。多條工作線可在同一個 `TEAM_STATE` 下並行、互不干擾。

- **每次呼叫 `bin/` 腳本都要帶 `TEAM_WS=<ws>`**（shell 變數不會跨呼叫保留）：`TEAM_WS=login-timeout bin/spawn-agent …`。忘了帶會落回不帶工作線的基底 session（`${TMUX_SESSION}`）。
- 一條工作線＝一個 tmux session `${TMUX_SESSION}-<ws>`（基底取自 `team.env` 的 `TMUX_SESSION`，預設 `team`），裡面只有一個 `agents` window，**一個角色一個 pane**（pane 選項 `@role=<agent>`、`@engine=<engine>`），pane 框線上方顯示 `#{@role} · #{@engine}`。排列預設 `even-vertical`（上下堆疊全寬），可在 `team.env` 或指令前用 `TEAM_LAYOUT=tiled` 等覆寫。
- 設了 `TEAM_WS` 時，啟動 prompt、verify／review／logic 的 log 與 `watch.offset` 放在 `$TEAM_STATE/.logs/ws/<ws>/`，每條工作線各自開一支 `bin/watch`；`EVENTS.log` 所有工作線共用一份。
- **事件分線靠 `<agent>` 欄**：有工作線時，`bin/spawn-agent` 會在初始 prompt 指示 agent 寫 `EVENTS.log` 時填 `<proj>-rd@<ws>`，`bin/new-task` 若帶 `TEAM_WS` 也會自動寫入任務書；`bin/verify`、`bin/review`、`bin/logic` 自動代寫 `verify@<ws>`、`review-rd@<ws>`、`logic-rd@<ws>`；`bin/event` 仍會為 `<proj>-rd@<ws>` 計算工作區指紋 `fp=`。`bin/watch` 只收 `@<ws>` 的事件，以及不含 `@` 但該角色在本 session 有 pane 的事件（agent 忘了加 `@ws` 的退路）；`bin/verify`、`bin/review`、`bin/fingerprint` 查歷史事件也採相同規則，不會被其他工作線的 `@other` 干擾。
- **專案鎖**：`<proj>-rd` 若正在同一 `TMUX_SESSION` 基底的其他工作線執行（非 shell），`bin/spawn-agent` 會拒絕（同一個專案工作區不能兩條工作線同時改）。`review-rd` 與 `logic-rd` 是唯讀執行，可各線獨立跑。
- **向下相容**：不設 `TEAM_WS` 時行為與舊版相同（session `${TMUX_SESSION}`、log 放 `$TEAM_STATE/.logs/`、只收不含 `@` 的事件）；升級前以角色命名的舊式 window 仍可直接 `peek`／`send`／`wait-pane`／`watch`。`TMUX_SOCKET` 照常生效，看某條線畫面：`tmux -L <TMUX_SOCKET> attach -t <TMUX_SESSION>-<ws>`（未設 `TMUX_SOCKET` 則省去 `-L`）。

### 專案與 agent 對照

見 `$TEAM_STATE/PROJECTS.md`。每個 `<proj>-rd` **只改自己那一個專案**，共用規範在 [roles/_rd-common.md](./roles/_rd-common.md)。跨專案需求由你協調，不准 agent 越界。

**新增專案**：專案目錄必須是 `$PROJ_ROOT` 底下的 git repo（派工基準與 review 都靠 git）。`TEAM_ROOT` 本身與包含 `TEAM_STATE` 的目錄**不可登記為專案**：agent 對專案有寫入權限，等於能改任務書與審查報告。在 PROJECTS.md 加一列 → `bin/new-role <proj> <目錄名>` → 向使用者問清楚會讓 agent 做錯的規則，填進該 role 的「專案硬規範」。
`bin/new-role` 同時建立 `$TEAM_STATE/verify/<proj>.sh`：填入 PROJECTS.md 的編譯與測試指令，**向使用者確認內容後**跑 `bin/verify <proj> --approve` 登記（§2.6）。專案真的無法自動編譯或測試時，腳本保留 `exit 2` 範本，並在 PROJECTS.md 註明。

### 專案專屬限制（編譯方式、資料庫、規範庫…）

寫在 `$TEAM_STATE/PROJECTS.md` 與各 `$TEAM_STATE/roles/<proj>-rd.md`（通用規範已在 `roles/_rd-common.md`，不必在各專案 role 重複）。派工時要把相關限制**抄進任務書**，agent 只看得到你寫的東西。
規範庫路徑**一定要寫進任務書**。

---

## 1. 流程

```
使用者給 issue
  → lead 切好分支 → bin/new-task 建任務書並填寫 → bin/spawn-agent 派給 <proj>-rd
  → <proj>-rd 回報 START → 開發 + 自查 → 寫 handoff → 回報 DONE（自動記下工作區指紋 fp，之後工作區凍結）
  → lead 讀 handoff、抽驗 diff → bin/verify（lead 親自重跑編譯與測試）
      └─ verify FAIL → 直接退回原 <proj>-rd，附 verify 報告，不必先 review
  → bin/review（唯讀沙箱，每次新實例；拿 verify 結果當依據）
  → bin/review 寫 handoff/review-<proj>-<slug>.md、代寫 DONE … PASS|FAIL … fp=…
  → lead 彙整回報使用者
      ├─ FAIL（有 Blocker/Major）→ 退回原 <proj>-rd 修正（更新同一份 handoff）→ 重新 DONE → verify → review 第 2 輪
      └─ PASS → bin/fingerprint 確認一致 → 整理教訓（§4.1）→ 結案：任務書狀態改「結案」，移到 tasks/done/
```

**review 意見要不要問使用者：看是不是邏輯問題**：

- **非邏輯問題直接退回 `<proj>-rd` 修，不必先問使用者**，不論 Blocker、Major 或 Minor。例如缺少測試、測試強度不足、註解或文件沒同步、命名、資源釋放、log 用詞。修完照下方規則決定要不要重審，結案時一併回報。
- **邏輯或業務規則問題才回到 lead 和使用者**。例如需求解讀有歧義、業務規則不明、不同做法各有取捨、任務書本身寫錯。lead 先判斷能不能自己依任務書與既有決定處理，不能才問使用者。
- `review-rd` 列在「建議（需使用者決定）」的推測性加強建議（不分級）不直接派 `<proj>-rd` 修，彙整時交給使用者決定（§3.5）。

**review 通過但有 Minor 時的處理原則**（建議）：

- 會**誤導後人或讓對外行為不準確**的（例：註解寫錯理由、錯誤訊息用詞不一致、測試強度不足以保護關鍵邏輯）→ 非邏輯問題直接退回修掉，再 commit。
- 純風格、不影響正確性與維護的 → 記進 handoff，不另開一輪。
- 只改註解文字與測試強度、邏輯不動的修正，也要由原 `*-rd` 更新 handoff、重新 DONE，再跑 `bin/verify` 與下一輪 `bin/review`：`bin/fingerprint` 要求目前工作區與 DONE、verify、review 的 fp 相同才能結案（§2.6 第 3 點）。
- 若 Minor 的成因是 lead 的任務書寫錯，先更正任務書，再派工修，並在任務書裡寫明正確理由，避免 reviewer 照舊說法審。

命名：`<slug>` 用任務簡稱（kebab-case，如 `login-timeout`），**不含專案前綴**，全程沿用。跨專案時各專案用同一個 slug 沒關係，所有檔名與事件都帶 `<proj>`。

---

## 2. 派工步驟

### 2.1 選引擎＋模型＋effort

**啟動開發 agent（`bin/spawn-agent`）前先決定「引擎＋模型＋effort」，三者皆不可省略**；啟動唯讀角色（`bin/review`、`bin/logic`）前決定 codex 的「模型＋effort」，兩者不可省略。省略 effort 會落到引擎預設，使用者不知道實際用了什麼，因此**不設 `DEFAULT_EFFORT`**，每次都由使用者指定。

- **引擎範圍**：
  - 開發 agent（`<proj>-rd`）：支援 **`codex`**、**`claude`**、**`agy`**（Antigravity CLI），同一 `agents` window 內可混合並存。
  - 審查與邏輯查核（`bin/review`、`bin/logic`）：**固定走 `codex exec -s read-only`**（唯讀沙箱一次跑完，不進互動 tmux pane）。
- **模型與 effort 來源**（**不要自己編模型名稱**，其餘讓使用者用 Other 輸入）：
  - `codex`：模型看 `~/.codex/config.toml` 的預設模型與使用者之前指定過的（`team.env` 的 `DEFAULT_MODEL` 有值代表使用者已同意沿用，換模型才問）；effort 為 `model_reasoning_effort`（非空且僅含 `[A-Za-z0-9_-]`，常見如 `low`／`medium`／`high`）。
  - `claude`：模型用 CLI 別名 `opus`、`sonnet` 與使用者之前指定過的；effort 僅允許 `low`／`medium`／`high`／`xhigh`／`max`。
  - `agy`：先跑 `agy models` 查可用清單。清單名稱含 effort 後綴（如 `gemini-4-neon-high`），**傳給 `bin/spawn-agent` 時模型要去掉 effort 後綴**（模型 `gemini-4-neon` ＋ effort `high`）；effort 僅允許 `low`／`medium`／`high`／`xhigh`／`max`，`bin/spawn-agent` 啟動前會對照 `agy models` 驗證組合。
- effort 一律用 AskUserQuestion 問使用者。一次派多個 agent 時問「全部同一個」或「逐個指定」；`review-rd`、`logic-rd` 可與開發 agent 使用不同模型與 effort。
- 同一任務進行中（含退回修正）不換引擎、模型或 effort；要換須先得到使用者同意。
- 任務書的「引擎」、「模型」與「effort」欄填實際選用的值；回報時（§4）一併註明。

### 2.2 建任務書

```bash
bin/new-task <proj> <專案目錄名> <slug>     # → $TEAM_STATE/tasks/<proj>-<slug>.md
# 有工作線時：TEAM_WS=<ws> bin/new-task <proj> <專案目錄名> <slug>
```

腳本會填入分支、**派工基準**（base commit、派工前已存在的未提交改動），以及 agent 要用的絕對路徑；執行當下若帶 `TEAM_WS`，也會直接填入「工作線」與回報用的 `<proj>-rd@<ws>`。
接著由 lead 填完其餘欄位（含引擎、模型、effort），**每欄都要填，否則 agent 會自己發明**。工作區派工前就不乾淨時，腳本會警告：告知使用者，由使用者決定是否先處理。

### 2.3 開 agent

```bash
bin/spawn-agent <proj> <專案目錄名> <codex|claude|agy> <模型> <effort> <slug>
# 有工作線時：TEAM_WS=<ws> bin/spawn-agent <proj> <專案目錄名> <codex|claude|agy> <模型> <effort> <slug>
```

- 初始 prompt 直接帶「讀 `$TEAM_ROOT/roles/_rd-common.md` 與 `$TEAM_STATE/roles/<proj>-rd.md` → 讀任務書」（有 `TEAM_WS` 時一併要求事件 agent 欄填 `<proj>-rd@<ws>`），不必再另外 send-keys（啟動前會檢查兩份 role、任務書與對應引擎執行檔存在）。
- 透過內部啟動器 `bin/_launch` 以 `exec` 啟動引擎（確保 pane 前景程式為引擎本身，`pane_is_shell` 才能正確判別退出）：
  - **`codex`**：`codex -m <模型> -c model_reasoning_effort="<effort>" -s workspace-write -a $CODEX_APPROVAL --add-dir $TEAM_STATE --no-alt-screen "<prompt>"`
  - **`claude`**：`claude "<prompt>" --model <模型> --effort <effort> --permission-mode auto --settings <settings> --add-dir $TEAM_STATE`（`prompt` 放第一個位置參數以免被 `--add-dir` 吃掉；`<settings>` 是 `$TEAM_ROOT/bootstrap/claude-rd.settings.json`，有 `$TEAM_ROOT/.local/claude-rd.settings.json` 時改用兩者合併的檔案，見下方「安全邊界」）
  - **`agy`**：`TEAM_AGY_POLICY=rd TEAM_AGENT_CWD="$PWD" … agy --model <模型> --effort <effort> --mode auto --add-dir $TEAM_STATE -i "<prompt>"`（啟動前先檢查 `$AGY_HOOKS_FILE` 已註冊 `bootstrap/agy-gate.py` 與 `agy models` 清單）
- 所有開發 agent 放在本 session 的單一 `agents` window（一角色一 pane，pane 選項 `@role=<agent>`、`@engine=<engine>`，框線上方顯示 `#{@role} · #{@engine}`），依 `TEAM_LAYOUT` 排列；若同角色正在其他工作線執行，會被專案鎖拒絕。session 不存在時直接以第一個 agent 建立（不會留下空的預設 window）；第一次派工若 `$LOGS/watch.offset` 尚未建立，會先記下派工前的 `EVENTS.log` 位置，避免開 watch 前的事件漏接。
- `claude` 啟動時若跳出 `Adding a new directory` 提示，`bin/spawn-agent` 會自動送 `Down` → 確認 `❯` 指在 `Yes` → `Enter`（最多重試 3 次）。
- 腳本最多等 90 秒，stdout 第一行印出狀態代號，**依結束碼決定下一步**：

| 結束碼 | stdout 第一行 | 意思 | lead 下一步 |
|---|---|---|---|
| `0` | `STARTED <agent>` | 已開工（工作中）；讀完任務書會寫 `START` | 背景開 `bin/watch`（3.1） |
| `3` | `NEED_USER_TRUST <agent>` | 停在信任提示（選了會永久儲存且可自動執行程式碼） | **這是使用者的安全決定，lead 不可代選**：先用 AskUserQuestion 問，同意後查 pane id（`tmux list-panes -s -t "=$TMUX_SESSION" -F '#{pane_id} #{@role} #{@engine}'`，有 `TMUX_SOCKET` 需加 `-L`，有工作線 session 為 `${TMUX_SESSION}-<ws>`）再操作。**各引擎預設游標不同**：`claude` 預設在 `No`（需 `Down` → `bin/peek` 確認 `❯` 指在 `Yes` → `Enter`）；**`agy` 與 `codex` 預設在 `Yes`**（同意時 `bin/peek` 確認後 `Enter`，不同意須先移到 `No`，絕不可盲送 `Enter`）。本腳本未送任何按鍵 |
| `4` | `APPROVAL <agent>` | 停在核准畫面 | 依 3.2 與 [docs/manual-approval.md](./docs/manual-approval.md) 逐次判斷處理 |
| `5` | `EXITED <agent>` | 15 秒內引擎沒起來（前景仍是 shell），或起來後又退出 | `bin/peek <agent>` 看畫面原因（參數、登入、沙箱、信任提示被當 Esc 等）→ 修正後重開 |
| `6` | `TIMEOUT <agent>`、`IGNORED_ADD_DIR <agent>` 或 `AGY_FALLBACK <agent>` | 90 秒逾時未確認開工；`codex` 印出 `Ignoring --add-dir`；或 `agy` 未使用指定模型／effort 而改用其他模型 | `bin/peek <agent>` 判斷；`Ignoring --add-dir` 須查明再重開；`AGY_FALLBACK` 時 `agy` 已開始工作，先 `bin/send <agent> '/exit'` 停掉、查明再重開 |

- 啟動或監看時畫面出現 warning、`Queued follow-up inputs`、`Compacting`、額度提示、回應很久沒動靜或狀態誤判，見 [docs/agent-startup.md](./docs/agent-startup.md)。

**安全邊界**（lead 抽驗時要看）：

- **`codex`**：靠 OS 沙箱（`-s workspace-write -a $CODEX_APPROVAL`）與 role 規範，沒有內建 deny 清單；抽驗時確認 `git status` 與跨專案目錄未遭更動。
- **`claude`**：`--permission-mode auto` 搭配 `$TEAM_ROOT/bootstrap/claude-rd.settings.json`（deny 所有通用 git 寫入指令與 `autocrlf`）。專案組要加 deny 時，放在 `$TEAM_ROOT/.local/claude-rd.settings.json`（不進版控；與 `verify-approved` 同處，開發 agent 寫不到）：`bin/_launch` 把它的 `permissions.deny` 與基本設定取聯集，其他欄位一律以基本設定為準（只能加限制，不能放寬或改 `defaultMode`／`allow`）；不是合法 JSON 就拒絕啟動。不讀 `$TEAM_STATE` 底下的設定（agent 寫得到）。
- **`agy`**：`--mode auto` 搭配全域 PreToolUse hook `$TEAM_ROOT/bootstrap/agy-gate.py`（跑一次 `bash "$TEAM_ROOT/bootstrap/install-agy-hook.sh"` 冪等合併 `"ai-team-state-gate"` 到 `${AGY_HOOKS_FILE:-$HOME/.gemini/config/hooks.json}`，保留既有其他 hook）。hook 只在 `bin/_launch` 設定 `TEAM_AGY_POLICY=rd` 時生效，不影響使用者自己的 `agy`。擋下：所有通用 git 寫入指令（含 `-C`、`--no-pager` 等全域參數，`env`／`sudo`／`VAR=` 等前綴，`sh -c '…'`）與 `autocrlf`；寫入 `$TEAM_ROOT/.local/`（安全控制檔，優先於下列放行）；寫入 `$TEAM_ROOT` 底下（若 `TEAM_STATE` 位於 `TEAM_ROOT` 內忽略目錄如 `state/`，放行 `TEAM_STATE` 底下）；寫入 `$PROJ_ROOT` 底下非本任務 `TEAM_AGENT_CWD` 的其他專案目錄。`TEAM_STATE` 等於或包含 `TEAM_ROOT`、`PROJ_ROOT` 或 `$TEAM_ROOT/.local`（或位於 `.local` 內）時視為設定過寬，拒絕所有寫入。

### 2.4 送訊息給執行中的 agent

```bash
bin/send <agent> '請讀 <絕對路徑> 並依指示執行。'
# 有工作線時加 TEAM_WS=<ws>
```

- 長內容（退回修正、接續說明）寫成檔案，只送「請讀 <絕對路徑>」。訊息裡的路徑要寫絕對路徑：引擎不會展開變數。
- 引擎已退出、停在信任提示或停在核准畫面（依引擎套用 `approval_pat`）時，腳本會**拒送**、印出目前畫面並 exit 非 0。
- 腳本會把文字與 Enter 分開送並確認出現該引擎的工作中字樣（`working_pat`）；沒出現時會**先重檢退出／信任／核准狀態，並只在目前底部輸入區仍是自己剛送的訊息時**補一次 Enter（排除核准選項與歷史行，允許三引擎的底部狀態列）；仍失敗或無法確認時會 exit 1 並印出目前畫面，此時用 `bin/peek <agent>` 檢查。

### 2.5 讀結果

```bash
bin/peek <agent> [行數]
tail -30 $TEAM_STATE/EVENTS.log
cat $TEAM_STATE/handoff/<proj>-rd-<slug>.md
```

### 2.6 驗證與審查

**不採信 agent 自己寫的「測試通過」。** handoff 的驗證結果只是宣稱；以 lead 重跑的結果為準（gstack ETHOS「No self-certification」）。

**工作區指紋（fp）**：`*-rd` 用 `bin/event DONE` 交件時，腳本自動在事件尾端加 `fp=<12 碼>`（HEAD + 對 base 的 diff + 未追蹤檔案）。
`bin/verify`、`bin/review` 開跑前與跑完都會比對：工作區跟最後一次 DONE 不同就寫 `BLOCKED`、不出結果。
這樣 PASS 一定對應「最後交件的那個版本」，而不是之後又被改過的工作區。DONE 帶 `fp=unknown` 代表任務書缺欄位，先修任務書再請 agent 重新 DONE。

**1. 驗證**：`*-rd` DONE 後，lead 讀 handoff、抽驗 `git -C <cwd> diff <base commit> --stat`，再以**背景執行**：

```bash
bin/verify <proj> <slug>
# 有工作線時加 TEAM_WS=<ws>
```

- 在交件工作區的乾淨複本（暫存目錄）跑 `$TEAM_STATE/verify/<proj>.sh`，原專案目錄不寫入；結果寫 `handoff/verify-<proj>-<slug>.md`，代寫 `DONE verify[@<ws>] <proj> <slug> <檔> PASS|FAIL exit=N fp=…`（完整 log 存 `$LOGS/`，即 `.logs/` 或 `.logs/ws/<ws>/`）。
- 驗證腳本在 TEAM_STATE，agent 寫得到，所以只跑 lead 登記過 hash 的版本（登記檔在 `$TEAM_ROOT/.local/`，agent 寫不到）。
  被改過會寫 `BLOCKED … 未登記或登記後被改過`：lead 讀過新內容、確認不是 agent 改的（是就問使用者）再 `bin/verify <proj> --approve`。
- 複本不含被 .gitignore 忽略的檔案（node_modules、build 輸出）；需要的話在腳本裡安裝或用 `$VERIFY_SRC` 連結。
- verify `FAIL` → 讀 log 判斷是程式的錯還是腳本／環境的錯。程式的錯直接退回 `*-rd`（附 verify 報告路徑），不必先跑 review；腳本／環境的錯由 lead 修正後重跑。

**2. 審查**：verify PASS（或專案無法自動驗證）後，以**背景執行**：

```bash
bin/review <proj> <專案目錄名> <slug> <模型> <effort> [輪次]
# 有工作線時加 TEAM_WS=<ws>
```

- 跑在 `codex exec -s read-only`：沙箱保證唯讀，不會有核准畫面，不必盯。每次審查都是新實例（獨立性較好）；第 2 輪起會先讀前幾輪報告，並 append 到同一份 review 檔。
- 結束時腳本代寫 `DONE review-rd[@<ws>] <proj> <slug> <檔> PASS|FAIL …`；codex 失敗則寫 `BLOCKED`，log 存在 `$LOGS/`（`.logs/` 或 `.logs/ws/<ws>/`）。
- `RESULT` 為 `UNKNOWN` 時，lead 自己讀報告判斷，不要直接當 PASS。
- 有同一 fp 的 verify 結果時，`bin/review` 會把它交給 review-rd 當依據；沒有時 review-rd 會把編譯與測試列為「未能審查」。

**3. 結案前**：`bin/fingerprint <proj> <slug>`（有工作線時帶 `TEAM_WS=<ws>`）必須印 `OK`（目前工作區 = 最後一次 DONE = verify = review 的 fp）。`MISMATCH` 就不能結案：查出是誰改了工作區，重新走 DONE → verify → review。

### 2.7 上下文管理（任務間重開）

agent 的記憶只在對話裡，會隨任務累積而變長、變鈍。所有該保留的東西都已經是檔案（任務書、handoff、review），所以**不靠對話記憶，改在任務之間重開**。

| 時機 | 做法 |
|---|---|
| 任務**結案**後，要派該 agent 下一個任務 | **重開** |
| 同一任務進行中，包含被 review 退回修正 | **不重開**。agent 需要自己上一輪的脈絡 |
| agent 開始忘記 role 規範（跑了不該跑的指令、漏寫 handoff、重複做同一件事） | 見 [docs/restart-mid-task.md](./docs/restart-mid-task.md) |
| 同專案連續派同類小任務，中間無 review 退回 | lead 判斷；有疑慮就重開，成本只是多讀一次 role |

**怎麼重開**

1. 確認該 agent 沒有未交的工作：EVENTS.log 已有它的 `DONE`，或 handoff 狀態為「開發完成／修正完成」。
2. 讓引擎結束回到 shell（`codex` 用 `bin/send <agent> '/quit'`，`claude`／`agy` 用 `bin/send <agent> '/exit'`，或請使用者處理），再 `bin/spawn-agent` 同參數＋新 slug（有工作線時帶 `TEAM_WS=<ws>`）：腳本會在原 pane 重開。引擎、模型與 effort 沿用，不用再問；要換才問。若已結案、不再需要該 pane，也可用 `tmux kill-pane -t <pane_id>` 關掉。
3. **新 agent 不認得上一個任務，任務書要寫完整，不要寫「延續上次」。**

**進行中被迫重開**：任務做到一半必須重開時，不要讓新 agent 憑空接手，先讀 [docs/restart-mid-task.md](./docs/restart-mid-task.md) 照做（保留「派工基準」，並告知使用者「中途換了 agent」）。

---

## 3. 派工規則

### 3.1 不要阻塞等待，但 lead 要主動跟進（不等使用者問）

lead 的對話回合不會自己醒來，所以**派工當下就要設好監看**，之後進度由 lead 主動推進。

**派工後必做（同一個回合內完成）**：以**背景執行** `bin/watch [timeout 秒]`（有工作線時帶 `TEAM_WS=<ws>`；有已結案、停在 shell 的 agent 時可帶 `WATCH_IGNORE="a-rd b-rd"` 略過，避免一開就回報 `EXITED`）。它同時監看：

| watch 第一行 | 意思 |
|---|---|
| `EVENT` | EVENTS.log 出現屬於本工作線的新的 `DONE`／`BLOCKED`（一併列出期間的 `START`；`START` 本身不觸發結束） |
| `APPROVAL <agent>（<engine>）` | 任一 `*-rd` 停在核准畫面（EVENTS.log 不會記核准卡住） |
| `EXITED <agent>` | 任一 `*-rd` 的引擎退出回 shell |
| `TRUST <agent>` | 任一 `*-rd` 停在信任提示 |
| `TIMEOUT` | 逾時，附各 agent 引擎、工作中／閒置與畫面最後一行（若有期間的 `START` 一併列出） |

watch 一結束就會通知 lead。**處理完該事件後立刻重開 watch**，直到沒有 agent 在跑。同條工作線多個 agent 同時在跑，一支 watch 就涵蓋全部。
watch 的讀取位置存在 `$LOGS/watch.offset`（有工作線時各線獨立在 `$TEAM_STATE/.logs/ws/<ws>/watch.offset`）：第一次派工時 `bin/spawn-agent` 會先記下派工前的位置，且回報 `EVENT` 後才往前推；lead 處理事件的空檔裡寫進來的 DONE／BLOCKED，重開 watch 時會立刻回報，不會漏。每條工作線同一時間只開一支 watch。

- `Compacting context`（壓縮上下文，正常）、`5h limit` 額度提示（剩不到 20% 且還有大量工作時告知使用者）與 `APPROVAL_PATTERN` 誤判處理，見 [docs/agent-startup.md](./docs/agent-startup.md)。
- 派工後 2～3 分鐘內沒看到該 agent 的 `START`，用 `bin/peek` 確認它真的在讀任務書。

**收到事件後，lead 自己往下走，不要先回頭問使用者「要不要」**

| 事件 | lead 自己做 |
|---|---|
| `*-rd` DONE | 讀 handoff → 抽驗實際 diff → 背景執行 `bin/verify` |
| verify DONE `PASS` | 背景執行 `bin/review` |
| verify DONE `FAIL` | 讀 verify 報告與 log：程式的錯 → 退回原 `*-rd`；腳本／環境的錯 → lead 修正後重跑 |
| review DONE `FAIL`（或 `PASS` 但有該修的 Minor） | 判斷是 agent 的錯還是任務書的錯（任務書的錯要先更正任務書）→ 依 §1「review 意見要不要問使用者」處理：非邏輯問題直接寫退回說明檔、`bin/send` 退回原 `*-rd`（更新同一份 handoff），邏輯／業務規則問題先判斷或整理成選項問使用者 |
| review DONE `PASS`（無需修項） | `bin/fingerprint` 確認 OK → 整理教訓（§4.1）→ 任務書狀態改結案、移到 `tasks/done/` → 彙整回報使用者（若有「建議（需使用者決定）」一併交給使用者） |
| `logic-rd` DONE | 讀 `$TEAM_STATE/handoff/logic-<slug>.md` → 若有「待 lead 代查的資料」，查完補進問題書「第 N 問」再開下一輪 `bin/logic` → 將結論用於原本的判斷（§3.6） |
| `*-rd` / verify / review / logic-rd BLOCKED | 先判斷是否為環境假象；是就解除並告知 agent（或重跑）。指紋不符 = DONE 後工作區又被改：問清楚是 agent 還是使用者改的，請 agent 重新寫 handoff 與 DONE。其餘整理成選項問使用者 |
| `APPROVAL` | 依 3.2 處理 |
| `TRUST` | **一定要問使用者**（安全決定），同意才送 Enter；`bin/send` 在此狀態會拒絕送字 |
| `EXITED` | `bin/peek` 看原因（沙箱、信任提示、當掉）→ 修正後 `bin/spawn-agent` 在原 pane 重開；任務進行中則依 [docs/restart-mid-task.md](./docs/restart-mid-task.md) |

只有以下情況才停下來問使用者：**業務規則不明、需要 commit／push／merge／切分支、涉及永久放行或信任的安全決定、破壞性操作、不同做法各有取捨**。其餘都是 lead 的工作。

**中途更正 agent 後，要確認它仍有完成收尾。** 在 agent 工作到一半送更正訊息，可能打亂它的收尾順序（更正後 agent 跑完測試就停了，沒更新 handoff、也沒寫 DONE）。更正後要等到 DONE，或在 agent 閒置時檢查 handoff 的修改時間；缺了就明確叫它「只補 handoff 與 DONE，不要再改程式」。

### 3.2 核准處理（逐次判斷，不要整類放行）

先排除：訊息停在輸入框沒送出（補 `Enter`）、引擎已退出回 shell（見 2.3）。
**不要**因為 agent 沒回應就重開一個 agent 做同一件事（任務結案後的重開不在此限，見 2.7）。

各引擎的核准畫面與**按鍵差異**（`codex` 拒絕是 3；`claude`／`agy` 拒絕是 4；`agy` 另有 `File access` 畫面）詳見 [docs/manual-approval.md](./docs/manual-approval.md)。**先用 `bin/peek` 看完整指令再決定**：

| 畫面上的指令 | 處理 |
|---|---|
| 只讀取、輸出在 `/tmp` 的指令 | 通常可選**只放行這一次**（1） |
| `git add` / `checkout` / `commit` / `stash` 等 git 寫入 | **拒絕**並提醒（見 3.3） |
| 會改動專案編譯產物、刪檔、改設定的指令 | **拒絕**，除非任務書明確允許 |
| 其他不確定的 | 問使用者 |

專案專屬的已知核准記在 `$TEAM_STATE/PROJECTS.md`，依該表處理。

- **不要選永久或整類放行**（`codex` 2、`claude` 2、`agy` 2／3、`agy` File access 2）：屬使用者的安全決定。
- **核准畫面下 `bin/send` 會拒送**：確認處理方式後，先查該角色的 pane id（`tmux list-panes -s -t "=$TMUX_SESSION" -F '#{pane_id} #{@role} #{@engine}'`，有 `TMUX_SOCKET` 需加 `-L`，有工作線 session 為 `${TMUX_SESSION}-<ws>`），再用 `tmux send-keys -t <pane_id> ...` 送按鍵（`claude`／`agy` 用 `Down` 移動並以 `bin/peek` 確認游標後再送 `Enter`）。
- **送出核准後，要確認畫面真的離開核准狀態**：`codex`／`claude` 用 `bin/wait-pane <agent> 'You approved|Working|esc to interrupt' 30`、`agy` 用 `bin/wait-pane <agent> '⣾|⣽|⣻|⢿|⡿|⣟|⣯|⣷|Running command|Generating' 30`（不可用 `esc to cancel`；有工作線時帶 `TEAM_WS=<ws>`），再重開 `bin/watch`。

### 3.3 規則不明時不准硬繞；git 操作要先問

- 要求 agent 把卡點寫進 handoff「未解決事項」並回報 `BLOCKED`，由 lead（或使用者）決定。agent 自行假設業務規則 = 退回重做。
- 不 `git commit` / `push` / `merge` / 切分支，除非使用者明確要求。任務書已寫明「**只改工作區，不 commit、不 checkout**」。
- **使用者要求改寫已存在的 commit（改訊息、拿掉署名等）時，先讀 [docs/rewrite-commits.md](./docs/rewrite-commits.md) 做完 6 步檢查再動手**（未 push 才改、只改自己寫的 commit、先建備份分支、比對 tree hash、工作區乾淨、備份分支由使用者決定何時刪）。
- commit 訊息格式見 [GIT-COMMIT.md](./GIT-COMMIT.md)。動手前先看該專案最近幾筆 `git log --format=%B -5`，**格式跟著既有 commit 走**；不確定就問。
- 署名行（`Co-Authored-By` 等）是否要加，由使用者決定，記在 GIT-COMMIT.md。

### 3.4 跨專案需求

由 lead 排序：先派上游 agent 做 API／介面，並在 handoff 寫出「契約」（路徑、request／response），lead 再把契約**複製進**下游 agent 的任務書。不要讓下游 agent 自己去翻上游程式碼猜格式。

### 3.5 程式碼維護與推測性加強建議

適用於所有 agent 交出的程式碼。agent 端的規則已寫在 [roles/_rd-common.md](./roles/_rd-common.md)「程式碼維護責任」與 [roles/review-rd.md](./roles/review-rd.md)「推測性加強建議（不分級）」，任務書不必重抄；lead 讀 handoff 與審查結果時照這兩點判斷：

- **長期可維護性是任務完成的一部分**：改動要正確運作且清晰易維護，但順手改善僅限本次任務改動的程式碼，不可擴大到範圍外檔案。
- **不要為了理論上的穩健而默默擴大範圍**：`<proj>-rd` 寫在 handoff「未解決事項」的推測性邊界處理，或 `review-rd` 的「建議（需使用者決定）」，都先問使用者，不要直接派 `<proj>-rd` 去加。

### 3.6 需要查邏輯時派 `logic-rd`

lead 需要查證邏輯時，派 `logic-rd`（[roles/logic-rd.md](./roles/logic-rd.md)）代查，**不要自己逐行追程式**。它不在固定流程裡，`review-rd` 的流程與職責不變。適合的時機：

- **派工前**：任務書草稿有業務規則、判斷條件、查詢條件，或涉及歷史狀態，請它找誤傷與漏網的情境。
- **開發後**：判斷審查意見成不成立、問題出在 agent 還是任務書，或追某種資料狀態會走到哪個分支。

做法：

1. 依 [templates/logic-task.md](./templates/logic-task.md) 寫問題書 `$TEAM_STATE/tasks/logic-<slug>.md`（`<slug>` 沿用原任務的；派工前還沒有任務時自訂）。內容包括：**問題**（可多題，編號）、**背景檔案**（任務書草稿、handoff、review，以及記錄已知限制與既有決定的文件，漏給會讓它把已知限制當成新問題報回來）、**範圍**（專案、檔案或入口）、**已知事實**、**不用查的部分**。同一個 slug 再問時，在同一份問題書檔尾加「## 第 N 問」。
2. 依 §2.1 向使用者確認模型與 effort 後，以**背景執行**：
   ```bash
   bin/logic <proj|-> <slug> <模型> <effort> [輪次=1] [專案目錄名...]
   # 有工作線時加 TEAM_WS=<ws>
   ```
   跑在 `codex exec -s read-only` 唯讀沙箱，無核准畫面，不要求任務書或工作區指紋（`fp`）；第 2 輪起會先讀前幾輪報告並 append 到同一份 `$TEAM_STATE/handoff/logic-<slug>.md`（有 `TEAM_WS` 時事件 agent 欄寫 `logic-rd@<ws>`、log 存在 `.logs/ws/<ws>/`）。
3. 收到 `DONE logic-rd` 後照 §3.1 表格處理。若報告列出「待 lead 代查的資料」，由 lead 查完把結果補進問題書「第 N 問」再開下一輪。
4. 它的結論是**給 lead 判斷用的證據**，不是決定：業務規則不明的照樣問使用者；要改任務書或退回 `<proj>-rd`，仍由 lead 依 §1 處理。回報使用者時註明「經 `logic-rd` 查核」與其模型、effort。

---

## 4. 彙整與回報使用者

**回報要主動、完整：** 不要等使用者問「好了嗎」才講。agent 狀態有變（START 異常／DONE／退回／卡住／通過）就主動說，並直接附上「需要你判斷的清單」，沒有就明講「目前沒有需要你判斷的事」。

每次回報講清楚四件事：

1. **做了什麼** — 哪個 agent（用什麼引擎、模型與 effort）改了哪些檔案
2. **驗證了什麼** — 編譯過了？哪些測試跑了？結果？
3. **沒驗證什麼** — 沒跑的測試、沒驗的情境、略過的步驟都要講
4. **需要使用者決定什麼** — 列選項，不要自己假設

專案有特殊的驗證限制（例如無法自動編譯）時，另依 PROJECTS.md 明講。
「驗證了什麼」要分清楚：`bin/verify` 實際重跑的、review 靜態審過的、只有 agent 自述的，三者分開寫。

### 4.1 教訓回流（每個任務結案時）

教訓沒變成規則，下一個任務就會再犯一次。結案前 lead 要：

1. 讀 handoff「教訓」、review 報告「教訓」，以及每一輪的 Blocker／Major，找出「role 或任務書沒寫清楚」造成的問題。
2. 每一條在 `$TEAM_STATE/LESSONS.md`「待處理」加一行，決定去向（優先順序見該檔）：
   - 專案層級（role 的專案硬規範、不准做，或 PROJECTS.md）：lead 直接補上並註明 `（來源：<proj>-<slug>，<日期>）`，再把該行移到「已處理」。專案硬規範同時是 review-rd 的必查清單，所以補了之後審查會越來越準。
   - 框架層級（AGENT.md、範本、`bin/`）：列進回報的「需要你決定」，使用者同意後才改，並照 GIT-COMMIT.md commit。
   - 不處理：寫明理由後移到「已處理」。
3. 同一條教訓第二次出現 = 上次的去向沒有效：換一個更前面的去向，或改腳本讓它不可能再發生。
4. 回報使用者時附上這次新增的規則（一行一條）。
