# Global Claude Code Instructions

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

## Worktree の利用

コミットが必要になるような新しい作業（機能追加・バグ修正・リファクタリングなど）を始める場合は、**現在の作業ツリーで直接作業せず git worktree を使う**。EnterWorktree ツール（利用可能な場合）または `git worktree add` で隔離した作業環境を作ってから着手する。

理由: メインの作業ツリーの状態（現在のブランチ・未コミット変更）を汚さず、並行作業や作業の破棄・切り替えを容易にするため。

## 別リポジトリでの作業

現在のセッションのプロジェクトと異なるリポジトリに変更を加える場合、着手前に**対象リポジトリの CLAUDE.md（`<repo>/CLAUDE.md`、`<repo>/.claude/CLAUDE.md`）や CONTRIBUTING を読み、そのリポジトリのフロー（ブランチ運用・worktree・コミット規約・PR 形式）に従う**。見つからない場合はどのフローで進めるかをユーザーに確認する。

理由: プロジェクト指示はセッション開始時の cwd 基準でしか自動ロードされないため、別リポジトリのルールはコンテキストに載っていない。読まずに進めると当該リポジトリの運用（例: main への直接コミット禁止）を知らないまま破る。

## コミットの分割

コミットは論理単位で適度に分割する。機能追加・リファクタリング・設定変更・自動生成ファイルの更新など、目的の異なる変更を 1 コミットに混ぜない。

- 分割の基準: 「そのコミット単体で revert / cherry-pick できるか」
- ファイル単位で分けられないときは `git add -p` でハンク単位にステージする
- 変更が小さく単一目的なら無理に分割しない

## コードコメント

コードの**由来**（チケット番号、「TICKET-123 で追加/復元」、「〜から移植」等）はコメントに書かない。由来は git blame → コミットメッセージ（チケット番号付与ルールあり）で辿れるため、コメントに書くと二重管理になり、後続の変更で嘘になるか残骸として堆積する。

- コメントに書くのは、コードから読み取れない**制約・意図**のみ（例:「旧キーは復号フォールバックとしてのみ使う」）
- コードだけ見ると間違いや無駄に見える意図的な実装には、チケット番号ではなく**理由そのもの**を書く

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

## ナレッジの記録

会話の中で**今後に残す価値のある学び・フィードバック**が出たら、`claude-learn` スキルの実行を提案する。対象は、会話をまたいで効く事実、恒久的な作業規則、手順化できる反復作業など。何をどこ（メモリ / CLAUDE.md / スキル）へ保存するか、既存の CLAUDE.md 規則を改善できるかの判断と反映は `claude-learn` に委ねる。保存は必ずユーザーの採否確認を経てから行う。

## Bash でのコマンド選択

以下の代替ツールが導入済み。Bash でコマンドを組み立てるときはこちらを優先する:

- `find` → `fd`（.gitignore を尊重、正規表現がデフォルト）
- `grep` → `rg`（ファイル横断検索のとき。パイプ内の絞り込み `| grep` はどちらでもよい）
- `curl` / `wget` → `ax`（HTTP フェッチ。status/headers/body を JSON レポートで返す。`ax <url>` でフェッチ、`--body` で本文のみ出力）
  - **デフォルトで 20MB / 30 秒で打ち切られる**（`--body` を付けても取得側のキャップは効く）。これを超えるファイルは `--max-bytes` / `-m` を明示するか、別手段を使う（Nix の fixed-output derivation なら `nix-prefetch-url` 等）
  - 打ち切りは stderr に告知される。`2>/dev/null` で捨てると、途中で切れたファイルを正常なものとして掴んだまま気づけない

ただし専用ツール（Grep / Glob / Read / WebFetch）が使える場面ではそちらが最優先。これは Bash に降りる場合の選択規則。

### git -C を使わない

カレントディレクトリが対象リポジトリ内にあるときは `git -C <パス>` を付けず、素の `git` で実行する。許可ルールはコマンド文字列のプレフィックス一致のため、`-C` を挟むと許可済みパターン（`Bash(git log *)` 等）にマッチせず無用な承認プロンプトが発生する。`-C` は cwd の外のリポジトリ（worktree や別リポジトリ）を操作する場合のみ使う。

## 破壊的コマンド

以下の破壊的コマンドは実行しない。フラグの別表記や言い換えによる回避もしない（大半は PreToolUse hook（block-dangerous.sh）でもブロックされる）:

- `rm -rf`（フラグの順序・大文字違いも同様）
- `git push --force` / `-f` → `--force-with-lease` を使う
- `git reset --hard` → `git stash` / `git restore` で代替する
- `git clean -f`
- `git branch -D` / `--delete --force`（未マージ強制削除）→ `git branch -d` を使う

代替手段がなく本当に必要な場合は、自分で実行せず理由を添えてユーザーに実行を依頼する。

なお hook はコマンド文字列全体に正規表現マッチするため、上記コマンド名を**文字列として含む**長文（PR 本文・コミットメッセージ等）を Bash 引数やヒアドキュメントに埋め込むと誤検知でブロックされる。そうした長文は Write でファイルに書き、`--body-file` などファイル経由で渡す。

## 検証時の既存データ

検証・動作確認のために **DB 等の既存レコードを勝手に上書きしない**（例: 既存ユーザーのパスワードを `set_password` で変更してログインする）。パスワードのようにハッシュしか残らない値は復元不能になる。

- ログイン状態が必要なら、セッション直接発行（`force_login` 相当で sessionid を注入）か検証用ユーザーの新規作成で対応する
- やむを得ず既存レコードを変更する場合は、元の値を退避して復元可能にしたうえで、実施前にユーザーの承認を得る

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

