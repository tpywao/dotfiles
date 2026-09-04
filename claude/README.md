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

- dotfiles 側に置くのは共有したいキーのみ（`permissions`、`hooks`、`statusLine`、`model`、`enabledMcpjsonServers`、`enabledPlugins`、`skillOverrides`、`extraKnownMarketplaces`、`language`、`theme` など）
- マシン固有のキーは dotfiles 側に書かない（`effortLevel`、`modelSettings`、`autoMode`）
- 配列（`permissions.allow` など）は結合ではなく置換になる。dotfiles 側で項目を削除すればそれも反映される
- オブジェクト（`skillOverrides` など）は再帰マージなので、dotfiles 側でエントリを削除しても同期済みのマシンには残り続ける。取り消すには各マシンの `~/.claude/settings.json` から手で消す
- CLI の「Yes, and don't ask again」はプロジェクトの `.claude/settings.local.json` に書かれるため、この方式で失われることはない

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `CLAUDE.md` | 全プロジェクト共通のグローバル指示（質問方法、worktree 運用、コードコメント方針、自動生成ファイルの扱いなど） |
| `settings.json` | 共有したい設定のみ（permissions の allow リスト、model、hooks の配線、plugins、language など）。hardlink ではなくマージ方式で反映する |
| `keybindings.json` | Claude Code のキーバインド（`meta+k` → submit） |
| `skills-external.json` | 外部インストーラ由来スキルの出所記録（リポジトリ・commit hash）。詳細は「外部スキル（vendoring）」を参照 |

## hooks/

`settings.json` で配線されるフックスクリプト。

| スクリプト | イベント | 役割 |
| --- | --- | --- |
| `block-dangerous.sh` | PreToolUse (Bash) | `rm -rf` など破壊的コマンドを exit 2 でブロック |
| `inject-context.sh` | SessionStart | ブランチ名と working tree の状態をコンテキストに注入 |
| `update-usage.sh` | SessionStart | `usage/collect.py` をバックグラウンド起動（セッション開始を遅延させない） |
| `relink-claude-files.sh` | PostToolUse (Edit\|Write) | hardlink 時代の再同期用。symlink 化後は何もせず終了する（`settings.json` も対象外） |
| `notify-stop.sh` | Stop | 作業完了を macOS 通知（terminal-notifier があればクリックでアプリ前面化） |

このほか UserPromptSubmit に `codegraph prompt-hook` が配線されている（スクリプトではなく `settings.json` に直接記述）。

## skills/

`<name>/SKILL.md` の形式。詳細は各 SKILL.md の frontmatter を参照。

| スキル | 用途 |
| --- | --- |
| `claude-add-config` | ~/.claude/ への設定追加と symlink 同期 |
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

`complexity` は `settings.json` の `skillOverrides` で `name-only` にしている。Claude には名前だけが提示され、説明文は常駐しない（`/complexity` での呼び出しはそのまま使える）。

### 外部スキル（vendoring）

`npx skills` / `gh skill` で導入したスキルは、実体をこのリポジトリへ取り込んで（vendoring）管理する。出所は `claude/skills-external.json` に記録する。

| スキル | 出所 | インストーラ |
| --- | --- | --- |
| `archify` | tt-a1i/archify | npx skills |
| `find-skills` | vercel-labs/skills | npx skills |
| `gh-stack` | github/gh-stack | gh skill |

方針:

- 内容のバージョン管理は git 履歴が担う。更新は必ず diff レビューを通るため、上流の変更が黙って反映されることがない。新しいマシンは clone + `install.sh` だけで揃う（インストーラ不要）
- インストーラの管理ファイル（`~/.agents/skills/` の store と `~/.agents/.skill-lock.json`）はマシンローカルのまま触らない。update の実行に使う
- vendoring したスキルは dotfiles 側で手編集しない。インストーラの update に上書きされて編集が消える。カスタムしたい場合は別名の自作スキルとして fork する
- `npx skills` が `~/.claude/skills/<name>` に張るディレクトリ symlink（store 参照）は `install.sh` が除去し、ファイル単位の symlink に張り替える。除去しないままファイル単位リンクを張ると symlink を辿って store 側の実体を壊すため

取り込み手順（新規に外部スキルを導入したとき）:

1. インストーラでインストールする（`npx skills add <owner>/<repo> -g` / `gh skill install <owner>/<repo> <name>`）
2. 実体を `claude/skills/<name>/` へコピーする。実体の場所はインストーラで異なる: `npx skills` は `~/.agents/skills/<name>`、`gh skill` は `~/.claude/skills/<name>` に直置き
3. `~/.agents/.skill-lock.json` の該当エントリ（source / skillFolderHash 等）を `claude/skills-external.json` へ転記する
4. コミット → PR。マージ後に `./install.sh` を実行してファイル単位 symlink に張り替える

更新手順:

1. `npx skills update` / `gh skill update` を実行する
2. 更新後の実体を `claude/skills/<name>/` へコピーし直し、diff をレビューする
3. `claude/skills-external.json` の skillFolderHash を `~/.agents/.skill-lock.json` から転記する
4. コミット → PR。マージ後に `./install.sh` を実行する

`gh skill update` は `~/.claude/skills/<name>` のファイル単位 symlink を実ファイルで置き換える（リンク先の dotfiles 実体は書き換えない。sandbox で検証済み）。dotfiles へコピーする前に `install.sh` を実行すると、更新内容が `*.presymlink.<ts>` へ退避されてリンクが旧内容に戻るため、上記の順序（コピー → コミット → マージ → install.sh）を守る。

## agents/

読み取り専用の調査系サブエージェント定義。

| エージェント | 用途 |
| --- | --- |
| `datadog-triage` | Datadog（spans/logs/error tracking）でエラー・レイテンシを調査 |
| `db-investigator` | Postgres / BigQuery / Metabase を横断したデータ調査・クエリ性能分析 |

## usage/

- `collect.py` — `~/.claude/projects/**/*.jsonl` を全スキャンして日別利用量を集計し、`~/.claude/usage/daily-usage.jsonl` にマージ、静的ダッシュボード `~/.claude/usage/dashboard.html` を生成する。標準ライブラリのみで動作し、SessionStart フックから起動される
