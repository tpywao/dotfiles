---
name: impl
description: チケット ID から feature ブランチを origin/dev から作成して実装を開始する。チケット ID を指定して実装を始めたいと言われたときに使う。
---

引数 `$ARGUMENTS` に TICKET_ID が渡される（引数なしならユーザに `AskUserQuestion` で確認する）。

`feature/$ARGUMENTS` という名前で作業ブランチを `origin/dev` から作成し、そのブランチにチェックアウトしてから実装を開始する。
