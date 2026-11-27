# ai-team-state 用語表

team lead 協調多個開發 agent（支援 `codex`、`claude`、`agy`）與唯讀審查／邏輯查核 agent 開發多專案的協作模型用語。各專案自己的業務名詞不在此，見專案各自的用語表或規範庫。

## 協作者

**lead**：
派工、協調、驗證、彙整並回報使用者的協調者，本身不直接修改各業務專案的程式碼。
_Avoid_: 主控、manager

**角色**：
一份職責定義（`$TEAM_ROOT/roles/*.md` 與 `$TEAM_STATE/roles/<proj>-rd.md`），例如 `<proj>-rd`、`review-rd`、`logic-rd`，描述這個位置該做什麼與不能做什麼。
_Avoid_: agent（指職責時）、人員

**引擎**：
執行角色的 AI CLI。開發 agent（`<proj>-rd`）支援 `codex`、`claude` 與 `agy`（Antigravity CLI）；唯讀角色（`review-rd`、`logic-rd`）固定使用 `codex`（`codex exec -s read-only`）。
_Avoid_: 工具、平台、provider

**模型**：
引擎底下實際使用的具體模型（搭配 `effort` 推論強度），每次派工由使用者指定或同意沿用。
_Avoid_: 版本

**agent**：
某個角色在引擎與模型上執行的實體；同一條工作線裡，同一個角色同時間只有一個 agent（開發角色 `<proj>-rd` 在 tmux session 的 `agents` window 中各自佔一個 pane，`review-rd` 與 `logic-rd` 則為單次唯讀執行的實體）。
_Avoid_: codex（指 agent 時）、bot

## 協作機制

**工作線（`TEAM_WS`）**：
同一個 `TEAM_STATE` 下同時執行多個獨立任務的隔離單位，由環境變數 `TEAM_WS=<ws>` 指定（以小寫英數開頭、只含小寫英數與 `-`）。每條工作線各自有 tmux session（`<TMUX_SESSION>-<ws>`）與 `.logs/ws/<ws>/`，共用 `EVENTS.log` 並以 `<角色>@<ws>` 分線；同一開發角色（`<proj>-rd`）受專案鎖保護，不可在兩條工作線同時執行（詳見 [AGENT.md](./AGENT.md) §0）。

**派工基準**：
任務書在派工當下記錄的 `base commit` 與派工前已存在的未提交改動，作為 `review-rd` 與 `bin/fingerprint` 判斷本任務變更範圍的依據。

**工作區指紋（fp）**：
由 `HEAD`、相對 `base commit` 的 diff 與未追蹤檔案內容計算出的 12 碼雜湊值。開發 agent 回報 `DONE` 時自動寫入 `EVENTS.log`，`bin/verify`、`bin/review` 與 `bin/fingerprint` 藉此確認驗證與審查對象就是最後交件的工作區。
