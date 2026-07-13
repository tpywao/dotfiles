---
name: def
description: Backlog チケットの内容を確認して実装方針をまとめる。チケット ID を指定して方針検討・要件定義をしたいと言われたときに使う。
---

引数 `$ARGUMENTS` に TICKET_ID が渡される（引数なしならユーザに `AskUserQuestion` で確認する）。

- Backlog MCP を用いてチケット `$ARGUMENTS` の詳細情報を確認する
- チケットの内容を元に実装方針をまとめて、ユーザに提示し指示を待つ
