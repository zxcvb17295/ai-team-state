#!/usr/bin/env bash
# verify/{{PROJ}}.sh — {{PROJ}} 的編譯與測試，由 bin/verify 執行（lead 填寫）
#
# - 執行目錄是「交件工作區的乾淨複本」根目錄，不是原專案目錄；改什麼都不會影響原專案。
# - 被 .gitignore 忽略的東西（node_modules、build 輸出、本機設定）不在複本裡：
#   需要就在這裡安裝（例：npm ci），或從原專案連結（例：ln -s "$VERIFY_SRC/node_modules" .）。
# - exit 0 = 通過，其他 = 失敗。只放確定能自動跑的指令；跑不了的情境寫進任務書請 lead 代驗。
# - 每次修改本檔後，lead 讀過內容再跑 bin/verify {{PROJ}} --approve，否則 bin/verify 會拒跑。

set -euo pipefail

echo "尚未設定 {{PROJ}} 的驗證指令：請編輯 $0" >&2
exit 2

# 例：
# mvn -o -q clean package
# npm ci && npm test
