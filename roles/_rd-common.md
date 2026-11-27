# roles/_rd-common — 所有開發 agent（`<proj>-rd`）共用規範

本檔與你自己的 `$TEAM_STATE/roles/<proj>-rd.md` 一起讀，兩份都要全程遵守。
下文的 `<角色>`（如 `api-rd`）、`<proj>`（如 `api`）與實際絕對路徑，以你那份專案 role 檔與任務書為準。

**語言**：所有回覆（含對話畫面上的說明、摘要、recap）與寫出的文件（handoff、EVENTS.log 摘要）一律用**繁體中文**。程式碼、識別字、指令、錯誤訊息原文照原樣，不翻譯。

## 邊界

- **只改你負責的那一個專案**，其他專案一個字都不准動（各專案特別點名的見自己的 role）。
- 需要其他專案配合 → 寫進 handoff「跨專案需求」，由 lead 協調。**不要自己去翻別的專案程式碼猜格式，也不要寫死假資料繞過。**
- **只改工作區，不 `git add` / `commit` / `checkout` / `stash` / `push` / `merge`。** 分支已由 lead 或使用者切好。
- 任務書「派工基準」列的既有改動不屬於你，不要碰；若任務必須改到這些檔案，先寫進 handoff 並回報 `BLOCKED`。
- 規則不明就停，寫進 handoff「未解決事項」並回報 `BLOCKED`；**自行假設業務規則 = 退回重做。**

## 程式碼維護責任

長期可維護性是任務完成的一部分：交出的程式碼要正確運作，也要清楚、容易維護。

- 順手改善僅限本次改動的程式碼本身（命名、重複邏輯、註解、錯誤處理），不得因此修改任務範圍外的檔案，也不得違反自己 role 檔「不准做」各項。
- **不要為了理論上的穩健而默默擴大範圍。** 想為推測性或發生機率極低的競態（race）、安全邊界情況增加複雜度時，先不要實作，其餘工作照常完成；在 handoff「未解決事項」寫明具體的失敗情境、發生機率與複雜度成本，由 lead 回報交給使用者決定。

## 交件（回報 EVENTS.log）

一律使用任務書「回報」一節提供的 `bin/event` 絕對路徑指令寫，**不要自己 `echo >>`**（格式不一致 lead 的監看會漏抓）：

```bash
'<TEAM_ROOT>/bin/event' <START|DONE|BLOCKED> <角色> <proj> <slug> <檔案|-> <摘要>
```

1. **讀完任務書、開始動手前**先回報 `START`（lead 用它確認你真的開工了）：
   ```bash
   '<TEAM_ROOT>/bin/event' START <角色> <proj> <slug> - 已讀任務書，開始
   ```
2. 完成時寫 `<TEAM_STATE>/handoff/<proj>-rd-<slug>.md`（格式見 `<TEAM_ROOT>/templates/handoff-rd.md`，實際路徑見任務書「產出」）。
   必寫：改動檔案、做法、驗證結果、**沒驗證的部分**、未解決事項、跨專案需求、教訓；另加自己 role「交件」列的專案必寫項。寫完 handoff 後再回報 `DONE`：
   ```bash
   '<TEAM_ROOT>/bin/event' DONE <角色> <proj> <slug> handoff/<proj>-rd-<slug>.md <一句話摘要>
   ```
3. 卡住時不要硬繞：把卡點寫進 handoff「未解決事項」，然後：
   ```bash
   '<TEAM_ROOT>/bin/event' BLOCKED <角色> <proj> <slug> handoff/<proj>-rd-<slug>.md <卡在哪>
   ```

**順序固定：先寫完 handoff，最後才寫 `DONE`。** 中途收到 lead 更正也一樣，改完要補 handoff 與 `DONE`。

**`DONE` 之後工作區就凍結，不准再改任何檔案**（包含「順手」修小地方）。`DONE` 會自動記下工作區指紋（`fp`），lead 的驗證（`bin/verify`）與審查（`bin/review`）都綁在這個指紋上；之後再改，驗證和審查都會被擋下、整輪重來。要再改：先跟 lead 說，改完照上面順序重新寫 handoff 與 `DONE`。

## 收到審查意見

讀 `<TEAM_STATE>/handoff/review-<proj>-<slug>.md`，**逐項**處理：修了寫「已修」，不修寫理由。
更新原本那份 handoff 的「修正紀錄」，**不要開新檔**。完成後再 `DONE` 回報一次。
