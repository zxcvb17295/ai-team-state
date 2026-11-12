# GIT-COMMIT — commit 訊息參考（Conventional Commits）

適用：lead 在使用者**明確要求 commit** 時使用（見 AGENT.md §3.3）。`*-rd` 與 `review-rd` 不 commit。
適用範圍：`ai-team-state` 本身。各專案的 commit **沿用該專案原本的格式**（動手前先看 `git log --format=%B -5`）。

署名行（`Co-Authored-By` 等）：`<由使用者決定：加 / 不加>`。

## 格式

```
<type>[(scope)]: <description>
<空行>
[body]
<空行>
[footer(s)]
```

## type（必要）

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 錯誤修復 |
| `docs` | 僅更改文件 |
| `refactor` | 重構調整（不改外部行為） |
| `perf` | 提高效能的更動 |
| `test` | 新增缺少的測試，或修正現有測試 |
| `style` | 不影響程式碼意義的變更（空格、格式等） |
| `build` | 影響建置系統或外部相依性的變更 |
| `ci` | 對 CI 設定檔與腳本的變更 |
| `chore` | 繁瑣雜務，沒有生產程式碼更改（例：更新 `.gitignore`） |
| `revert` | 回復先前的 commit |

## scope（非必要）

用括號包住，必須是描述該程式部分的**名詞**。本倉庫建議：`agent`、`roles`、`tasks`、`handoff`。

## description（必要）

簡短描述，**不超過 100 個字元**。說「做了什麼」，不寫句號。

## body／footer（非必要）

- body：詳細描述，說明**為什麼**這樣改；與 description 之間空一行。
- footer：issue 編號 `Refs: #1234`；破壞性變更 `BREAKING CHANGE: <說明>`。

## 範例

```
feat: 新增登入逾時設定
```

```
fix(auth): 修正逾時後未清除 session

逾時後改為同時清除伺服端 session，避免舊 token 仍可使用。

Refs: #1234
```

```
docs(agent): 補上任務間重開 agent 的規則
```

## 注意

- 一個 commit 只做一件事；不同主題拆開 commit。
- 只 `git add` 這次要提交的檔案，不要 `git add -A`：工作區可能有別的 session 正在修改的檔案。
- 不 `push` / `merge`，除非使用者明確要求。
