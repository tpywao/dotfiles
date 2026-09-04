# claude

Claude Code の設定一式。`claude/install.sh` の `link_claude_files` がこのディレクトリ配下のファイルを `~/.claude/` へ **symlink** で張る。ただし `settings.json` はリンクせず、`merge_claude_settings` が共有キーだけを既存の設定へ上書き適用する。`install.sh` と `Skillfile` はインストーラ側のファイルなのでリンク対象から外している。

## symlink 同期の仕組み

- リンクの作成は `claude/install.sh`（`claude/` 配下を再帰的に `~/.claude/` へ symlink。`settings.json` / `install.sh` / `Skillfile` は除外）
- **編集は必ず dotfiles 側で行う。`~/.claude/` 側は参照専用。** Claude Code の Edit は symlink 経由の書き込みを拒否する（`Refusing to write through symlink`）ため、`~/.claude/` 側を誤って編集することは構造的に起きない
- symlink はパス参照なので、`git switch` や atomic save（tmpfile + rename）でリンクが切れない。hardlink だった頃はこれで頻繁に切れ、両側が黙って分岐していた
- 既存の hardlink は `claude/install.sh` の再実行で symlink へ置き換わる。内容が分岐していた場合は `~/.claude/` 側を `*.presymlink.<ts>` へ退避してから張る（退避ファイルは中身を確認して手で消す）
- 新しい skill・hook・設定ファイルを追加するときは `claude-add-config` スキルを使う（リンク漏れを防ぐ手順になっている）

## settings.json をマージ方式にしている理由

Claude Code 自身が `model` / `effortLevel` / `modelSettings` / `autoMode` を `~/.claude/settings.json` へ書き込むため、このファイルはリンクできない。

- symlink にすると、本体がこのファイルへ書き込んだ時点で dotfiles 側の実体が書き換わる。マシン固有の値がそのままリポジトリへ流れ込む。特に `autoMode.environment` にはホームディレクトリのパスやリポジトリ名が入る
- hardlink でも同じ流入が起きるうえ、書き込みが atomic save なのでリンクが切れる。切れたことに気づかないまま両側が別々に育つ

そこで `claude/install.sh` の `merge_claude_settings` が `jq` の `*` で **dotfiles 側のキーだけを既存の設定へ上書き**する。dotfiles 側に無いキーは既存値がそのまま残るため、マシン固有の設定は保持される。

- dotfiles 側に置くのは共有したいキーのみ（`permissions`、`hooks`、`statusLine`、`model`、`enabledMcpjsonServers`、`enabledPlugins`、`skillOverrides`、`extraKnownMarketplaces`、`language`、`theme` など）
- マシン固有のキーは dotfiles 側に書かない（`effortLevel`、`modelSettings`、`autoMode`）
- 配列（`permissions.allow` など）は結合ではなく置換になる。dotfiles 側で項目を削除すればそれも反映される
- `hooks` は再帰マージのあとに dotfiles 側の値で**丸ごと差し替える**。残り続けた配線は実体を失ったスクリプトを呼び続けるため、削除も同期する必要がある。副作用として、マシン単位で hook を足すには `~/.claude/settings.json` への直書きではなくプロジェクトの `.claude/settings.local.json` を使う
- `hooks` 以外のオブジェクト（`skillOverrides`、`enabledPlugins` など）は再帰マージなので、dotfiles 側でエントリを削除しても同期済みのマシンには残り続ける。取り消すには各マシンの `~/.claude/settings.json` から手で消す
- CLI の「Yes, and don't ask again」はプロジェクトの `.claude/settings.local.json` に書かれるため、この方式で失われることはない
- プラグイン（`enabledPlugins` / `extraKnownMarketplaces`）について、新マシンで自動なのは marketplace の登録まで。プラグイン本体は自動インストールされない。起動時に「未インストール」の警告と実行すべき `claude plugin install <name>` コマンドが表示されるので、それを自分で一度実行する（v2.1.195 時点の挙動）。バージョン固定を書ける場所（marketplace.json の `version` / `source.ref`）は上流 marketplace 側にしかないため、外部 marketplace のプラグインは版固定できず、インストールした時点の最新版が入る

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

### 外部スキル（Skillfile によるマニフェスト管理）

外部リポジトリ由来のスキルは実体をこのリポジトリに置かず（vendoring しない）、`claude/Skillfile`（`<owner>/<repo> <skill> <pin>` の行形式）をマニフェストとして管理する。`claude/install.sh` の `install_external_skills` が `gh skill install --pin` で `~/.claude/skills/` へ導入する。

| スキル | 出所 |
| --- | --- |
| `archify` | tt-a1i/archify |
| `find-skills` | vercel-labs/skills |
| `gh-stack` | github/gh-stack |

方針:

- バージョンは `Skillfile` の pin（タグ）で固定する。どのマシンでも同じ版が入ることは pin が保証する。スキルの実体は git 管理外なので、更新しても diff レビューは発生しない（内容を確認したいときは pin を上げる前に `gh skill preview <owner>/<repo> <skill>` か上流の compare を読む）
- pin されたスキルは `gh skill update` の対象外（gh の仕様。update を実行すると notice 付きでスキップされる）。うっかり `--unpin` などで導入済みの版が pin とずれても、`claude/install.sh` が SKILL.md frontmatter の `github-ref` と pin を突き合わせて入れ直すため、次回の `./install.sh` 実行時に `Skillfile` の pin の版へ戻る
- インストーラは `gh skill` に一本化する。`npx skills` は使わない（pin・メタデータの仕組みが gh skill と別系統になるため）。`npx skills` は実体を `~/.agents/skills/`（store）に置き、各エージェントのスキルディレクトリからそこへディレクトリ symlink を張る方式。過去に導入した分の store と他エージェント向け symlink は他ツールが参照している可能性があるため触らないが、`~/.claude/skills/<name>` へ張られたディレクトリ symlink だけは `install_external_skills` が除去する（残したまま gh skill install すると、symlink を辿って store 側の実体を書き換えかねないため）
- 外部スキルは `~/.claude/skills/` 側の実ファイルであり dotfiles の symlink 同期対象外。手編集しない（版が pin とずれたと判定された時点で `claude/install.sh` が入れ直し、編集が上書きされて消える）。カスタムしたい場合は別名の自作スキルとして dotfiles 側に fork する

導入手順:

1. `claude/Skillfile` に行を追加する（pin は上流のリリースタグ）
2. コミット → PR。マージ後に `./install.sh` を実行する（他のマシンも pull 後に `./install.sh` を実行する）

更新手順:

1. 上流のリリースを確認して `claude/Skillfile` の pin を上げる
2. コミット → PR。マージ後に `./install.sh` を実行する（ref が pin とずれたスキルだけ入れ直される）

## agents/

読み取り専用の調査系サブエージェント定義。

| エージェント | 用途 |
| --- | --- |
| `datadog-triage` | Datadog（spans/logs/error tracking）でエラー・レイテンシを調査 |
| `db-investigator` | Postgres / BigQuery / Metabase を横断したデータ調査・クエリ性能分析 |

## usage/

- `collect.py` — `~/.claude/projects/**/*.jsonl` を全スキャンして日別利用量を集計し、`~/.claude/usage/daily-usage.jsonl` にマージ、静的ダッシュボード `~/.claude/usage/dashboard.html` を生成する。標準ライブラリのみで動作し、SessionStart フックから起動される
