# claude

Claude Code の設定一式。`install.sh` の `link_claude_md` がこのディレクトリ配下の全ファイルを `~/.claude/` へ **hardlink** で同期する。

## hardlink 同期の仕組み

- 初回リンクは `install.sh`（`claude/` 配下を再帰的に `~/.claude/` へ hardlink）
- Claude Code の Edit/Write は atomic save（tmpfile + rename）のため、編集のたびに hardlink が切れる。これを `hooks/relink-claude-files.sh`（PostToolUse hook）が検知して再リンクする。両側が分岐していた場合は古い側を `*.relinkbak.<ts>` に退避してから上書きする
- 新しい skill・hook・設定ファイルを追加するときは `claude-add-config` スキルを使う（リンク漏れを防ぐ手順になっている）

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `CLAUDE.md` | 全プロジェクト共通のグローバル指示（質問方法、worktree 運用、コードコメント方針、自動生成ファイルの扱いなど） |
| `settings.json` | permissions（allow リスト）、model、hooks の配線、plugins、language など |
| `keybindings.json` | Claude Code のキーバインド（`meta+k` → submit） |

## hooks/

`settings.json` で配線されるフックスクリプト。

| スクリプト | イベント | 役割 |
| --- | --- | --- |
| `block-dangerous.sh` | PreToolUse (Bash) | `rm -rf` など破壊的コマンドを exit 2 でブロック |
| `inject-context.sh` | SessionStart | ブランチ名と working tree の状態をコンテキストに注入 |
| `update-usage.sh` | SessionStart | `usage/collect.py` をバックグラウンド起動（セッション開始を遅延させない） |
| `relink-claude-files.sh` | PostToolUse (Edit\|Write) | 上記の hardlink 再同期 |
| `notify-stop.sh` | Stop | 作業完了を macOS 通知（terminal-notifier があればクリックでアプリ前面化） |

このほか UserPromptSubmit に `codegraph prompt-hook` が配線されている（スクリプトではなく `settings.json` に直接記述）。

## skills/

`<name>/SKILL.md` の形式。詳細は各 SKILL.md の frontmatter を参照。

| スキル | 用途 |
| --- | --- |
| `claude-add-config` | ~/.claude/ への設定追加と hardlink 同期 |
| `claude-env-audit` | Claude Code 環境の定期監査 |
| `claude-learn` | 会話で得た学びをメモリ / CLAUDE.md / スキルへ反映 |
| `complexity` | 計算量を O 記法で解析・比較 |
| `create-ticket` | Backlog にチケット起票 |
| `daily-recap` | 特定日の作業サマリ |
| `def` | Backlog チケットから実装方針をまとめる |
| `fix-tests` | Django テストを緑になるまで修正する反復ループ |
| `impl` | チケット ID から feature ブランチを作って実装開始 |
| `mb-reorder-params` | Metabase カードのパラメータ並び替え |
| `pr-format` | PR タイトル・本文のフォーマット |
| `review-strict` | 同調しない厳格なコードレビュー |

## agents/

読み取り専用の調査系サブエージェント定義。

| エージェント | 用途 |
| --- | --- |
| `datadog-triage` | Datadog（spans/logs/error tracking）でエラー・レイテンシを調査 |
| `db-investigator` | Postgres / BigQuery / Metabase を横断したデータ調査・クエリ性能分析 |

## usage/

- `collect.py` — `~/.claude/projects/**/*.jsonl` を全スキャンして日別利用量を集計し、`~/.claude/usage/daily-usage.jsonl` にマージ、静的ダッシュボード `~/.claude/usage/dashboard.html` を生成する。標準ライブラリのみで動作し、SessionStart フックから起動される
