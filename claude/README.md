# claude

Claude Code の設定一式。`claude/install.sh` の `link_claude_files` がこのディレクトリ配下のファイルを `~/.claude/` へ **symlink** で張る。ただし `settings.json` はリンクせず、`merge_claude_settings` が共有キーだけを既存の設定へ上書き適用する。`mcp-servers.json` も同様のマージ元で、`merge_claude_mcp_servers` が `~/.claude.json` へ反映する。`install.sh` と `Skillfile` はインストーラ側のファイルなのでリンク対象から外している。

## symlink 同期の仕組み

- リンクの作成は `claude/install.sh`。粒度は 2 種類ある
  - `skills/` は**スキルのディレクトリ単位**（`~/.claude/skills/<name>` が dotfiles へのリンク）。スキル内に `references/` などを足しても `install.sh` の再実行は要らない
  - それ以外は**ファイル単位**。`settings.json` / `mcp-servers.json` / `install.sh` / `Skillfile` は除外。skills 以外にファイルを新設したときは `install.sh` の再実行が要る
- ディレクトリごと張らないのは、`~/.claude/` の各階層に dotfiles 管理外のものが同居するため。`skills/` には外部スキル、`usage/` には `collect.py` の生成物（`daily-usage.jsonl`、`dashboard.html`）、`~/.claude/` 直下にはセッション状態（`projects/`、`history.jsonl` など）がある。ディレクトリを 1 本の symlink にするとこれらが見えなくなる
- **編集は必ず dotfiles 側で行う。`~/.claude/` 側は参照専用。** Claude Code の Edit は symlink 経由の書き込みを拒否する（`Refusing to write <path>: it is a symbolic link. Write to the link's target path instead.`）ため、`~/.claude/` 側を誤って編集することは構造的に起きない
- symlink はパス参照なので、`git switch` や atomic save（tmpfile + rename）でリンクが切れない。hardlink だった頃はこれで頻繁に切れ、両側が黙って分岐していた
- 既存の実ファイル・実ディレクトリは `claude/install.sh` の再実行で symlink へ置き換わる
  - ファイルは内容が分岐していたときだけ `*.presymlink.<ts>` へ退避する
  - スキルのディレクトリは、中身がそのスキルへのリンクだけなら退避せずに張り替える。他のものが混ざっていれば `*.presymlink.<ts>` へ退避し、`notice()` で手で消すよう案内する（退避先は SKILL.md を持ったまま `skills/` の直下に残り、スキルとして読み込まれうる）
- 新しい skill・hook・設定ファイルを追加するときは `claude-add-config` スキルを使う（リンク漏れを防ぐ手順になっている）

## settings.json をマージ方式にしている理由

Claude Code 自身が `model` / `effortLevel` / `modelSettings` / `autoMode` を `~/.claude/settings.json` へ書き込むため、このファイルはリンクできない。

- symlink にすると、本体がこのファイルへ書き込んだ時点で dotfiles 側の実体が書き換わる。マシン固有の値がそのままリポジトリへ流れ込む。特に `autoMode.environment` にはホームディレクトリのパスやリポジトリ名が入る
- hardlink でも同じ流入が起きるうえ、書き込みが atomic save なのでリンクが切れる。切れたことに気づかないまま両側が別々に育つ

そこで `claude/install.sh` の `merge_claude_settings` が `jq` の `*` で **dotfiles 側のキーだけを既存の設定へ上書き**する。dotfiles 側に無いキーは既存値がそのまま残るため、マシン固有の設定は保持される。

- dotfiles 側に置くのは共有したいキーのみ（`permissions`、`hooks`、`statusLine`、`model`、`enabledMcpjsonServers`、`enabledPlugins`、`skillOverrides`、`extraKnownMarketplaces`、`language`、`theme` など）
- マシン固有のキーは dotfiles 側に書かない（`effortLevel`、`modelSettings`、`autoMode`）
- 配列（`permissions.allow` など）は結合ではなく置換になる。dotfiles 側で項目を削除すればそれも反映される
- `hooks` は **dotfiles が配った hook だけを入れ替える**。残り続けた配線は実体を失ったスクリプトを呼び続けるため削除も同期する一方、他のアプリ（エージェント管理ツール等）が `~/.claude/settings.json` に足した hook は残す
  - 配った hook は `${XDG_STATE_HOME:-~/.local/state}/dotfiles/claude-hooks.json` に記録し、次の実行で既存の設定から取り除いてから dotfiles 側の hook を入れる。記録は積み増しで、消えるのは記録に載った hook だけ
  - 記録が無いマシン（初回）では何も取り除かない。それより前に dotfiles 側で消した hook が残っていれば手で消す
- `hooks` 以外のオブジェクト（`skillOverrides`、`enabledPlugins` など）は再帰マージなので、dotfiles 側でエントリを削除しても同期済みのマシンには残り続ける。取り消すには各マシンの `~/.claude/settings.json` から手で消す
- `env` の `DO_NOT_TRACK` は `"0"` にしている。`zsh/.zshenv` が全シェルで `DO_NOT_TRACK=1` を export しているが、Claude Code はこれを `DISABLE_TELEMETRY` と同じに扱い、機能フラグの取得まで止める。止まると advisor など、フラグで有効になる機能が使えない。Claude Code ではテレメトリの停止とフラグの取得を別々に切り替えられないため、Claude Code についてだけ打ち消す
  - settings の `env` は、シェルから引き継いだ同名の変数を上書きする。起動方法（ターミナル・IDE 拡張）を問わず効く。ただし Claude Desktop が用意する起動時の環境に同名の変数があると、そちらが優先される
  - 値は Claude Code が起動する子プロセスにも渡る。Bash ツールのシェルは `.zshenv` を読み直すので `1` に戻る（2026-11-26 に v2.1.332 で確認）。zsh を経由しない子プロセス（stdio の MCP サーバーなど）は `0` のままになる見込みだが、確かめていない
- CLI の「Yes, and don't ask again」はプロジェクトの `.claude/settings.local.json` に書かれるため、この方式で失われることはない
- プラグイン（`enabledPlugins` / `extraKnownMarketplaces`）について、新マシンで自動なのは marketplace の登録まで。プラグイン本体は自動インストールされない。起動時に「未インストール」の警告と実行すべき `claude plugin install <name>` コマンドが表示されるので、それを自分で一度実行する（v2.1.195 時点の挙動）。バージョン固定を書ける場所（marketplace.json の `version` / `source.ref`）は上流 marketplace 側にしかないため、外部 marketplace のプラグインは版固定できず、インストールした時点の最新版が入る

## mcpServers の共有（mcp-servers.json）

MCP サーバーの登録先 `~/.claude.json` は、Claude Code 自身がセッション状態やプロジェクト履歴を書き込むマシンローカルのファイルで、`settings.json` と同じ理由でリンクできない。`claude/install.sh` の `merge_claude_mcp_servers` が `claude/mcp-servers.json` の内容を `~/.claude.json` へ既定の再帰マージで反映する。

- dotfiles 側に置くのはマシン間で共有したいサーバーのみ。現状は `context7`（ライブラリ公式ドキュメント取得）、`deepwiki`（公開 GitHub リポジトリへの質問応答）、`nixos`（nixpkgs・home-manager オプション検索）、`codegraph`（コード知識グラフ）
- stdio サーバーはコマンドが PATH に要る。`codegraph` は `ai-tools/`、`nixos`（コマンド名 `mcp-nixos`）は `nix/packages.nix` で入り、いずれも home-manager が導入する
- マシン固有のサーバー（ローカルの環境変数やバイナリに依存する stdio サーバー等）は各マシンで `claude mcp add -s user` したままで保持される
- マシン側で共有サーバーに追記したキーも `dst` にしか無いキーとして保持される（例: レート制限緩和のため `headers` に API キーを足す）
- API キーやトークンの値そのものは dotfiles 側に書かない。各マシンの `~/.claude.json` 側で `headers` に追記するか、stdio サーバーなら `env` の変数参照（`${VAR}`）を使う
- 削除は同期しない。`hooks` と違って丸ごと差し替えるとマシン固有のサーバーが消えるため、既定の再帰マージのままにしている（残ったサーバーは接続に失敗するだけで実害が小さい）。dotfiles 側で消したサーバーは各マシンで `claude mcp remove <name> -s user` する
- サーバーの追加・変更はコミット → PR。マージ後に `./install.sh`（または `./claude/install.sh` 単体）を実行する。反映は次のセッションから

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `CLAUDE.md` | 全プロジェクト共通のグローバル指示（質問方法、worktree 運用、コードコメント方針、自動生成ファイルの扱いなど） |
| `settings.json` | 共有したい設定のみ（permissions の allow リスト、model、hooks の配線、plugins、language など）。hardlink ではなくマージ方式で反映する |
| `mcp-servers.json` | マシン間で共有したい MCP サーバーのみ。`~/.claude.json` へマージ方式で反映する |
| `keybindings.json` | Claude Code のキーバインド（`meta+k` → submit） |

## hooks/

`settings.json` で配線されるフックスクリプト。

| スクリプト | イベント | 役割 |
| --- | --- | --- |
| `block-dangerous.sh` | PreToolUse (Bash) | `rm -rf` など破壊的コマンドを exit 2 でブロック |
| `inject-context.sh` | SessionStart | session_id・ブランチ名・working tree の状態をコンテキストに注入 |
| `agent-status.sh` | Stop | 作業の状態が変わったときに `agent-status` スキルでのシートへの記録を促す（詳細は「agent-status」の節） |
| `update-usage.sh` | SessionStart | `usage/collect.py` をバックグラウンド起動（セッション開始を遅延させない） |

このほか UserPromptSubmit に `codegraph prompt-hook` が配線されている（スクリプトではなく `settings.json` に直接記述）。

### agent-status（作業状況のシート）

各マシンの Claude Code のセッションが、作業の状態を Claude Sheets の 1 つのシートへ 1 作業 1 行で記録する。未 push のコミットや返答待ちの作業が手元の worktree にしか無く、別のセッションや GitHub から見えない問題への対処。コードは外へ出さず、状態だけを組織の claude.ai アカウント内の非公開のシートに書く。

- **シートを書くのはモデル。** Claude Sheets は Docs コネクタ経由でしか書けないため、`agent-status.sh`（Stop hook）は値を集めて記録を促すだけで、書き方は `agent-status` スキルにある
- **マシンごとの設定**: シートの URL を `~/.config/dotfiles/agent-status-sheet` の 1 行目に書く。URL はアカウント固有の値なので、このリポジトリには入れない。ファイルが無いマシンでは hook は何もしない
- **`claude -p`（ヘッドレス実行）では記録しない。** `-p` は最後のメッセージだけを出力するので、記録のために続けたターンが本来の答えを置き換えてしまう（`ask()` などが壊れる）。hook は `CLAUDE_CODE_ENTRYPOINT` が `sdk-cli` のときに黙る（2026-11-25 に確かめた時点で、`-p` では `sdk-cli`、対話のセッションでは `cli` だった）
- **シートの構成**: `active`（いまの作業）・`deactivated`（完了から一定時間たった作業）・`設定`（回収と放置の時間）の 3 枚。列と状態の値はスキルを参照
- **読み方**
  - `完了` の行の `deactivated` への移動と、更新の無い行の `放置` への変更は、どれかのセッションが記録したときにしか起きない。誰も記録しないあいだは状態が古いまま残るので、状態と合わせて最終更新も見る
  - `放置` は、落ちたセッションと、返答を待ったまま止まっている生きたセッションを区別しない
  - Claude でマージ後の片付けをせず、GitHub 上でだけマージした作業は `PR 待ち` のまま残る。自動では片付けないので、不要になった行は人が消す

## skills/

`<name>/SKILL.md` の形式。詳細は各 SKILL.md の frontmatter を参照。

| スキル | 用途 |
| --- | --- |
| `claude-add-config` | ~/.claude/ への設定追加と symlink 同期 |
| `claude-env-audit` | Claude Code 環境の定期監査 |
| `claude-learn` | 会話で得た学びをメモリ / CLAUDE.md / スキルへ反映 |
| `complexity` | 計算量を O 記法で解析・比較 |
| `daily-recap` | 特定日の作業サマリ |
| `def` | Backlog チケットから実装方針をまとめる |
| `impl` | チケット ID から feature ブランチを作って実装開始 |
| `mb-reorder-params` | Metabase カードのパラメータ並び替え |
| `pr-format` | PR タイトル・本文のフォーマット |
| `pr-selfcheck` | PR を出す前に diff を走査し、レビュー負荷を上げる要因を本文の追記案にする |
| `qa-test-request` | QA にチケットのコメントで UI テストを依頼する文面（準備データ・テスト項目・依頼）を作る |

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
- 導入には `gh` の認証が要る。未認証でも `gh skill install` は動くが、GitHub API の未認証レート制限（IP 単位で 60 req/h）にすぐ当たる。スキル 1 つにつきファイル数だけ blob を引くため、1 つ導入し終える前に 403 になり不完全なスキルが残る。`install_external_skills` は `gh auth token` で未認証を検出したら導入を丸ごと飛ばし、`notice()` で `gh auth login` を末尾に案内する
- 導入に失敗したときは `~/.claude/skills/<skill>/SKILL.md` を消してから `[failed]` を出す。`gh skill install` は途中で落ちても SKILL.md だけは書いていることがあり、残すと frontmatter の `github-ref` が pin と一致して次回以降「導入済み」と判定され、壊れたスキルが固定されるため。消せば次回 `--force` で入り直し、それまでの間 Claude Code に読み込まれることもなくなる
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
