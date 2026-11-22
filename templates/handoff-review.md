# 審查：review-<proj>-<slug>

> 由 `review-rd` 以最後回覆輸出、`bin/review` 寫入檔案。唯讀審查，**不替人改程式**。
> 第 2 輪起只輸出「## 第 N 輪」一節（含本範本各小節），會 append 在前一輪之後。
> **最後一行固定為**：`RESULT: PASS|FAIL <N> Blocker <M> Major <K> Minor`

| 項目 | 內容 |
|------|------|
| 審查對象 | `handoff/<proj>-rd-<slug>.md` |
| 專案 | `<專案名>` |
| 分支 | `<branch>` |
| 審查輪次 | 第 N 輪 |
| 結論 | 通過 / 需修正 |
| 審查時間 | `YYYY-MM-DD HH:MM` |

## 審查依據

| 來源 | 內容 |
|------|------|
| handoff | 宣稱改了什麼 |
| 任務書「派工基準」 | base commit、派工前已存在的改動（不算本任務） |
| `git --no-optional-locks status --short` | 實際動到的檔案 |
| `git diff <base commit>` | 實際差異 |
| 專案規範 | role 檔「專案硬規範」與 PROJECTS.md 的規範庫 |

**handoff 與實際 diff 不一致要明寫**（漏報檔案、多改檔案都算 Major 以上）。派工前就存在的改動不算。

## Blocker

會導致功能錯誤、資料錯誤、安全問題，或違反專案硬規範。必須修。

- `path/to/File:123` — 問題描述 + 為什麼是 Blocker

## Major

不會立刻壞，但違反架構慣例、遺漏錯誤處理、效能風險。應修。

- `path/to/File:45` —

## Minor

命名、註解、格式、可讀性。可修。

- `path/to/File:88` —

## 通過項

確認沒問題的部分，寫出來讓 lead 知道審過了哪些。

- 

## 未能審查的部分

缺乏資訊、需要執行環境才能判斷的，老實列出。

- 例：實際效能無法靜態判斷，建議上線前實測

## 教訓

這次的 Blocker／Major 裡，哪些是「role 的專案硬規範或任務書沒寫清楚」造成的？寫出建議補進去的規則（一句話＋放哪裡）。
沒有就寫「無」。lead 會整理進 `$TEAM_STATE/LESSONS.md`。

- 例：建議 role「專案硬規範」新增：所有 DAO 查詢必須帶 `tenant_id`（本輪 Blocker 1 的成因）

RESULT: FAIL 1 Blocker 0 Major 2 Minor
