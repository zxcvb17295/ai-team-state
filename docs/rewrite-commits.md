# 改寫已存在的 commit

使用者要求改寫已存在的 commit（改訊息、拿掉署名等）時才讀這份（[AGENT.md](../AGENT.md) §3.3）。**先做完這份檢查再動手：**

1. 確認要改的 commit **沒有 push 過**：`git log origin/<分支>..HEAD`。已 push 的不改寫，改寫需要 force push，必須先問使用者。
2. 只改自己（lead／agent）寫的 commit，使用者本人的 commit 不碰：範圍用 `<使用者最後一個 commit>..HEAD`。
3. 先建備份分支：`git branch backup/<分支>-before-<事由> HEAD`。
4. 改寫後**比對 tree hash**（`git rev-parse HEAD^{tree}` 與備份分支相同）：相同代表只有訊息變了、程式內容一個位元組都沒動。
5. 確認 `git status` 乾淨、遠端分支沒被動到。
6. 備份分支由**使用者決定何時刪**，不要自己先刪；若使用了 `filter-branch`，留下的 `refs/original/` 同樣先問再清。
