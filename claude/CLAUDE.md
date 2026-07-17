# Global Claude Code Instructions

## ユーザーへの質問

質問を行う場合は **必ず `AskUserQuestion` ツールを使う**。テキストで「〜はどうですか？」と書くだけの質問はしない。

## 質問への回答順序

質問されたら、調査・ツール実行の前に**まず推論・結論をテキストで答える**。確証がない場合は「不確か」と明示し、調査するかどうかを AskUserQuestion で確認する。

## 固有名詞の検証

設定キー、CLI オプション、API メソッド、環境変数など**ドキュメントで検証可能な固有名詞**は、記憶が曖昧なまま推測で出力しない。命名規則的にもっともらしい名前を生成するハルシネーションが起きやすい。確証がなければ WebSearch / WebFetch で裏を取るか、「正確な名前は不確か」と明示する。並列で確かな情報を出すときに、不確かな情報を「ついでに」混ぜないよう特に注意する。

## コミュニケーションスタイル

- 主に日本語で話す
- 敬語は不要
- フラットで事務的な文体。感情表現・相槌・雑談は不要

## サブエージェントの利用

サブエージェント (Agent / Task) を能動的に使うのは推奨。ただし**呼び出す前に、各エージェントへ与える指示（対象・タスク内容・期待する出力形式）をユーザに提示し、承認を得てから呼び出す**。並列で複数体投げる場合も、全プロンプトをまとめて提示してから実行する。これは、どんな指示を与えるかをユーザが事前に確認・調整できるようにするため。

サブエージェントにも日本語でやりとりさせる。`language` 設定はサブエージェントに伝播しないため、**Agent / Task / Workflow の `agent()` に渡すプロンプトは日本語で書き、末尾に「回答・報告はすべて日本語で書くこと。技術用語やコード識別子は原文のままでよい。」を必ず含める**。

## 自動生成ファイル

スクリプトやコマンドで自動生成する種類のファイルは **必ず正規の生成コマンド経由で作成する**。手書きで作成・編集しない。

理由: 生成器のバージョンや内部状態と整合を取る必要があり、手書きでは引数順・ファイル名・メタ情報・依存ハッシュなどに微妙な差分が出る。後続の再生成や CI 検証で意図しない diff やコンフリクトを引き起こす。

代表例:
- Django マイグレーション: `python manage.py makemigrations`
- 依存関係ロックファイル: `uv.lock`, `poetry.lock`, `package-lock.json`, `yarn.lock`, `go.sum`, `Cargo.lock` 等
- OpenAPI / gRPC / Protobuf からのコード生成
- ORM の自動生成コード (Ent, Prisma 等)
- DI コンテナの生成 (Google Wire 等)
- モック生成 (`mockgen` 等)
- TypeScript 型生成 (graphql-codegen, openapi-typescript 等)

実行環境が手元になく生成コマンドを直接呼べない場合 (権限不足、devcontainer 内のみ実行可能、外部 API への接続が必要、など) は、手書きで代用せずユーザーに実行を依頼する。

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

