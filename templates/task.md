# 任務書：{{PROJ}}-{{SLUG}}

> lead 用 `bin/new-task` 建立後填寫。agent 只看得到這份文件，沒寫到的東西 agent 就不知道。
> 每個欄位都要填，不確定的寫「未定，請在 handoff 寫出卡點並回報 BLOCKED」。

## 基本資訊

| 項目 | 內容 |
|------|------|
| 狀態 | 進行中 ／ 審查中 ／ 退回修正 ／ 結案（lead 維護；結案後移到 `tasks/done/`） |
| 負責 agent | `{{PROJ}}-rd` |
| 專案 cwd | `{{PROJ_ROOT}}/{{PROJ_DIR}}` |
| 分支 | `{{BRANCH}}`（已由 lead／使用者切好，**不准 checkout 或建立分支**） |
| slug | `{{SLUG}}` |
| 引擎 | `codex ／ claude ／ agy（派工前由使用者指定）` |
| 模型 | `{{MODEL}}` |
| effort | `（派工前由使用者指定，不可省略）` |
| 工作線 | {{TEAM_WS_INFO}} |
| issue | `#<id>` 或 N/A |
| 建立時間 | {{DATE}} |

## 派工基準

review 以此為基準判斷哪些改動是本任務造成的。**不要修改本節。**

- base commit：`{{BASE_HEAD}}`
- 派工前已存在的未提交改動（不屬於本任務，不要碰；若任務必須改到這些檔案，先回報 BLOCKED）：

```
{{BASE_STATUS}}
```

## 目的與背景

為什麼要做這件事、要解決什麼問題、誰會用到。規則不明的部分直接寫「未定」，不要讓 agent 猜。

## 目標

具體到檔案與功能。例：

> `AuthService` 新增 `refreshToken()`，逾時 30 分鐘後回傳新的 token。
> 需新增對應的單元測試。

## 涉及資料

- 資料來源／結構：
- 樣本或現況（註明環境；敏感資料只放必要欄位）：
- 無資料變動則寫「無」

## 必讀文件

- 共用規範：`{{TEAM_ROOT}}/roles/_rd-common.md`
- 專案 role：`{{TEAM_STATE}}/roles/{{PROJ}}-rd.md`
- 專案架構規範：`<路徑>`（見 PROJECTS.md）
- 專案自帶：`{{PROJ_ROOT}}/{{PROJ_DIR}}/AGENTS.md`（若存在）
- 名詞定義：`<路徑>`（若有）。**程式註解、訊息、文件的用詞以它為準，lead 派工前先核對**
- 其他：

## 參考程式位置

同專案既有的相似實作，照它的寫法做：

- `<path/to/Example>` — 為什麼參考它

## 已知限制與不准自行發明的規則

- 不准自行假設業務規則。規則不明 → 寫進 handoff「未解決事項」並回報 `BLOCKED`
- 不准升級／新增依賴版本
- 不准修改共用基底類別
- 不准碰其他專案的程式碼。需要別的專案配合 → 寫進 handoff「跨專案需求」
- **只改工作區，不 `git add` / `commit` / `checkout` / `stash` / `push`**
- **要跑的 git 指令一律限定檔案路徑**（`git diff -- <檔案>`），避免掃整個專案卡住
- （專案特定限制，lead 依 PROJECTS.md 補充）

## 跨專案契約（如有）

lead 從上游 agent 的 handoff 複製過來。**不要叫 agent 自己去翻別的專案猜格式。**

```
API: <METHOD> <path>
Request : <欄位>
Response: <欄位>
```

## 驗證方式

- 編譯：`<指令>`（見 PROJECTS.md）
- 測試：`<指令，或寫「本專案無自動化測試，請說明人工驗證方式」>`
- 要驗的情境：
- 停在核准畫面時不要空等，先在 handoff 註記「等待核准：<指令>」。
- **需 lead 代驗的項目**（agent 無法自己驗的，例如連不到的外部系統；無則寫「無」）：
  - agent 在 handoff 列出要驗的內容與預期結果
  - lead 建議驗證項目：

## 產出

handoff 檔：`{{TEAM_STATE}}/handoff/{{PROJ}}-rd-{{SLUG}}.md`（格式見 `{{TEAM_ROOT}}/templates/handoff-rd.md`）

## 回報（EVENTS.log）

> 若在工作線（`TEAM_WS=<ws>`）下執行，`<agent>` 欄一律填 `{{PROJ}}-rd@<ws>`（不用裸 `{{PROJ}}-rd`），lead 靠它分辨工作線。

讀完本任務書、開始動手前：

```bash
'{{TEAM_ROOT}}/bin/event' START {{EVENT_AGENT}} {{PROJ}} {{SLUG}} - 已讀任務書，開始
```

完成後：

```bash
'{{TEAM_ROOT}}/bin/event' DONE {{EVENT_AGENT}} {{PROJ}} {{SLUG}} handoff/{{PROJ}}-rd-{{SLUG}}.md <一句話摘要>
```

卡住時：

```bash
'{{TEAM_ROOT}}/bin/event' BLOCKED {{EVENT_AGENT}} {{PROJ}} {{SLUG}} handoff/{{PROJ}}-rd-{{SLUG}}.md <卡在哪>
```
