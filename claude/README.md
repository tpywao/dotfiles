# claude

Claude Code の設定一式。`install.sh` の `link_claude_files` がこのディレクトリ配下のファイルを `~/.claude/` へ **symlink** で張る。ただし `settings.json` はリンクせず、`merge_claude_settings` が共有キーだけを既存の設定へ上書き適用する。

## symlink 同期の仕組み

- リンクの作成は `install.sh`（`claude/` 配下を再帰的に `~/.claude/` へ symlink。`settings.json` は除外）
- **編集は必ず dotfiles 側で行う。`~/.claude/` 側は参照専用。** Claude Code の Edit は symlink 経由の書き込みを拒否する（`Refusing to write through symlink`）ため、`~/.claude/` 側を誤って編集することは構造的に起きない
- symlink はパス参照なので、`git switch` や atomic save（tmpfile + rename）でリンクが切れない。hardlink だった頃はこれで頻繁に切れ、両側が黙って分岐していた
- 既存の hardlink は `install.sh` の再実行で symlink へ置き換わる。内容が分岐していた場合は `~/.claude/` 側を `*.presymlink.<ts>` へ退避してから張る（退避ファイルは中身を確認して手で消す）
- `hooks/relink-claude-files.sh`（PostToolUse hook）は hardlink 時代の再リンク用。symlink では実体を辿って同一 inode と判定されるため、何もせず終了する
- 新しい skill・hook・設定ファイルを追加するときは `claude-add-config` スキルを使う（リンク漏れを防ぐ手順になっている）

## settings.json をマージ方式にしている理由

Claude Code 自身が `model` / `effortLevel` / `modelSettings` / `autoMode` を `~/.claude/settings.json` へ書き込むため、このファイルはリンクできない。

- symlink にすると、本体がこのファイルへ書き込んだ時点で dotfiles 側の実体が書き換わる。マシン固有の値がそのままリポジトリへ流れ込む。特に `autoMode.environment` にはホームディレクトリのパスやリポジトリ名が入る
- hardlink でも同じ流入が起きるうえ、書き込みが atomic save なのでリンクが切れる。本体の設定書き込みは PostToolUse hook を通らないため `relink-claude-files.sh` では復旧できず、気づかないまま両側が別々に育つ

そこで `install.sh` の `merge_claude_settings` が `jq -s '.[0] * .[1]'` で **dotfiles 側のキーだけを既存の設定へ上書き**する。dotfiles 側に無いキーは既存値がそのまま残るため、マシン固有の設定は保持される。

- dotfiles 側に置くのは共有したいキーのみ（`permissions`、`hooks`、`statusLine`、`model`、`enabledMcpjsonServers`、`enabledPlugins`、`extraKnownMarketplaces`、`language`、`theme` など）
- マシン固有のキーは dotfiles 側に書かない（`effortLevel`、`modelSettings`、`autoMode`）
- 配列（`permissions.allow` など）は結合ではなく置換になる。dotfiles 側で項目を削除すればそれも反映される
- CLI の「Yes, and don't ask again」はプロジェクトの `.claude/settings.local.json` に書かれるため、この方式で失われることはない

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `CLAUDE.md` | 全プロジェクト共通のグローバル指示（質問方法、worktree 運用、コードコメント方針、自動生成ファイルの扱いなど） |
| `settings.json` | 共有したい設定のみ（permissions の allow リスト、model、hooks の配線、plugins、language など）。hardlink ではなくマージ方式で反映する |
| `keybindings.json` | Claude Code のキーバインド（`meta+k` → submit） |

## hooks/

`settings.json` で配線されるフックスクリプト。

| スクリプト | イベント | 役割 |
| --- | --- | --- |
| `block-dangerous.sh` | PreToolUse (Bash) | `rm -rf` など破壊的コマンドを exit 2 でブロック |
| `inject-context.sh` | SessionStart | ブランチ名と working tree の状態をコンテキストに注入 |
| `update-usage.sh` | SessionStart | `usage/collect.py` をバックグラウンド起動（セッション開始を遅延させない） |
| `relink-claude-files.sh` | PostToolUse (Edit\|Write) | hardlink 時代の再同期用。symlink 化後は何もせず終了する（`settings.json` も対象外） |
| `remind-pr-selfcheck.sh` | PreToolUse (Bash) | `gh pr create` の初回を exit 2 で一度止め、`pr-selfcheck` の実行を促す（30分以内の再実行は通す） |
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
| `pr-selfcheck` | PR を出す前に diff を走査し、レビュー負荷を上げる要因を本文の追記案にする |
| `review-strict` | 同調しない厳格なコードレビュー |

## agents/

読み取り専用の調査系サブエージェント定義。

| エージェント | 用途 |
| --- | --- |
| `datadog-triage` | Datadog（spans/logs/error tracking）でエラー・レイテンシを調査 |
| `db-investigator` | Postgres / BigQuery / Metabase を横断したデータ調査・クエリ性能分析 |

## usage/

- `collect.py` — `~/.claude/projects/**/*.jsonl` を全スキャンして日別利用量を集計し、`~/.claude/usage/daily-usage.jsonl` にマージ、静的ダッシュボード `~/.claude/usage/dashboard.html` を生成する。標準ライブラリのみで動作し、SessionStart フックから起動される
