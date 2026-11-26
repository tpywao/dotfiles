# Dotfiles Repository Context

このドキュメントは、ユーザーの dotfiles（~/.dotfiles）リポジトリの作業ガイドです。

## プロジェクト概要
- **用途**: macOS + Linux 向けの個人用 dotfiles リポジトリ

## 必ず守ること

どのファイルを触るときにも効き、破ると取り返しにくい規則。ほかの節より先に読む。

### 固有文言の禁止
- このリポジトリに追加するファイル（skills, hooks, 設定, ドキュメント等）には、**マシン・個人・勤務先プロジェクトに固有の文言を書かない**
  - 対象: ユーザー名、ホスト名、勤務先の社名・プロジェクト名・リポジトリ名、社内 URL など
  - 例示が必要な場合はプレースホルダや汎用名を使う（`<user>`, `~/dev/myrepo` など）。ホームディレクトリは `~` / `$HOME` で表記する
- 理由: このリポジトリは複数マシンで共用し、公開しても支障ない状態を保つため

### `install.sh` を worktree から実行しない
`~/` に張る symlink と home-manager の flake 参照が worktree を指すため、worktree を消すとリンクが軒並み壊れる（`~/.zshenv` を含む）。`refuse_worktree()` が検出して中断する。動作確認はマージ後にメインの作業ツリーから行う。

## インストーラの構成

`install.sh` はディレクトリ単位に分割されている。

- ルートの `install.sh`: 専用ディレクトリを持たない設定（`vimrc`, `tmux.conf`, `screenrc`, `sqliterc`, `direnvrc`, `editorconfig`, bash 用の `bashrc` / `aliases.bash`）の symlink と、各ディレクトリの `install.sh` の実行
  - `editorconfig`（ドットなし）が `~/.editorconfig` へ配布する設定。`.editorconfig`（ドットあり）はこのリポジトリ自身に効かせる設定で、配布対象ではない
- 各ディレクトリの `install.sh`（`git/`, `sheldon/`, `karabiner/`, `ghostty/`, `nix/`, `brew/`, `macos/`, `docker/`, `claude/`）: そのディレクトリに関する処理。ルートがこの順で実行する
  - **順序の制約は「`nix/` より後に `docker/`・`claude/`・`macos/`」だけ。** `docker/` と `claude/` は設定を `jq` でマージし、`jq` は `nix/packages.nix` で入る（前に置くと jq が無いマシンの初回実行でマージがスキップされ、2 回目まで反映されない）。`macos/` は ことえりの候補ウィンドウに `nix/firge.nix` が入れるフォントを指定するため、前に置くと初回実行でフォントが無いまま設定が入る。残りのディレクトリの順序に意味は無い
  - `docker/` と `claude/` の前で `nix-daemon.sh` を読み込む必要があるため、ループが 2 つに分かれている。**後半のループには `jq` が要る 2 つだけを置く**（それ以外を混ぜると、そこにいる理由をコメントで説明できなくなる）。`nix/` より後という制約しか無い `macos/` は前半のループの末尾で足りる
- `zsh/install.sh` はループに入れず、`$SHELL` が zsh のときだけ case 分岐から実行する（`fish/`・bash 用のリンクも同じ分岐にある）
- `utils/install-common.sh`: 各 `install.sh` が source する共通部（`link_config()`・`merge_config()`・`log_tag()`・`notice()` など）。**`install.sh` か `utils/` を変更するときは、先に `utils/AGENTS.md`（共通部の関数の挙動・出力の書式・テスト・`[dropped]` からの復旧）を読む**

規約:

- 各 `install.sh` は先頭で `DOTFILES` を自前で解決して `utils/install-common.sh` を source する。単体でも実行できる（例: `./claude/install.sh`）
- ルートは `sh "$DOTFILES/<dir>/install.sh" || exit $?` で呼ぶ。**各サブは末尾で明示的に `exit 0` する**。これが無いと最後のコマンド（`home-manager switch`、`brew bundle`、`ln` など）の失敗がそのままスクリプトの終了ステータスになり、後続のディレクトリが丸ごとスキップされる（分割前は 1 プロセスで、失敗しても後続が走っていた）
- 意図的に全体を止めたいときだけ `exit 1` する（現状は `refuse_worktree()` と `nix/install.sh` の `DOTFILES_MACHINE` 未設定のみ）
- サブプロセスなので、サブ側の環境変数・PATH の変更はルートへ届かない。Nix を初めて入れた回に `docker/install.sh` と `claude/install.sh` が `jq` / `gh` を見つけられるよう、ルートは `nix` の直後に `nix-daemon.sh` を読み込む
- `fish/` と `fzf/` はディレクトリごとリンク先（`~/.config/fish`, `~/.fzf`）へ symlink するため、中に `install.sh` を置くとインストーラまでリンク先に配られる。この 2 つはルートの `install.sh` でリンクする
- `claude/install.sh` と `claude/Skillfile` は `link_claude_files` の `find` で除外している。除外しないと `~/.claude/` へリンクされる
- **アプリ自身が書き込む設定ファイルは `link_config()` ではなく `merge_config()` を使う。** リンクを張るとアプリが書いたマシン固有の値が dotfiles 側へ流れ込み、逆に dotfiles 側の内容で置き換えるとその値が失われる。dotfiles 側は共有したいキーだけを持ち、`dst` にしか無いキーは触らない。該当するのは `claude/settings.json`、`claude/mcp-servers.json`、`docker/config.json`、`karabiner/profile-defaults.json` の 4 つ
  - `claude/settings.json`: Claude Code が `model` / `effortLevel` / `autoMode` を書き込む。`hooks` は dotfiles が配った hook だけを入れ替え、他のアプリが足した hook は残す。仕組みは `claude/README.md` の「settings.json をマージ方式にしている理由」
  - `claude/mcp-servers.json`: 配布先は `~/.claude.json`（Claude Code がセッション状態やプロジェクト履歴を書き込む）。詳細は `claude/README.md` の「mcpServers の共有（mcp-servers.json）」
  - `docker/config.json`: Docker Desktop が `credsStore` / `currentContext` / `plugins` / `features` を書き込む。dotfiles 側が持つのは `detachKeys` だけで、フィルタは既定のまま
  - `karabiner/profile-defaults.json`: 配布先は `~/.config/karabiner/karabiner.json`。詳細は `karabiner/AGENTS.md` を参照
  - **配列は再帰マージされず `src` の内容で置換される。** `dst` にしか無い配列要素（`permissions.allow` に「常に許可」で追加されたルールなど）は失われる。消える要素は `[dropped]` で列挙され、マージ前の `dst` は `.premerge.<ts>` に退避される。復旧手順は `utils/AGENTS.md`
  - `merge_config` は以前のバージョンが張った symlink を見つけたら、内容を実体へコピーし直してからマージする（リンクのまま書き込むと `src` を書き換えるため）。これらのファイルを新たに symlink 管理へ戻さないこと

## 作業時の注意事項

### 実装開始時のブランチ運用
新規ブランチは必ず `origin/main` から作成する（`git fetch` 後）。古いローカル main や現在の作業ブランチを起点にしない。worktree を切ってから着手する手順そのものはユーザーメモリ側の規則が正本。

### 効くか分からない設定を試すとき
`link_config()` で symlink 配布している設定（`ghostty/config` など）が実際に効くかを確かめたいときは、例外的に main の作業ツリーで先に書き換えて試す。配布先はメインのチェックアウトを指しているため、worktree 側を書き換えても反映されない。

1. main の作業ツリーで書き換え、アプリで効くことを確認する（効かなければ `git restore` で戻して終わり）
2. 差分を worktree へ移してコミットし、PR にする
3. main の作業ツリーの未コミット分はマージまで残す（消すとマージまで設定が元に戻る）
4. マージ後、main で `git pull` する前に `git restore <ファイル>` で未コミット分を捨てる。残っていると同じファイルへの変更として pull が止まる

`merge_config()` で配る設定（`claude/settings.json` など）はコピーなので、書き換えただけでは反映されない。この手順の対象外。

worktree にあるスキル・エージェント定義の変更は、`~/.claude/` のリンクを試すあいだだけ worktree へ向けて試す。手順と注意点は `claude/README.md` の「worktree にあるスキル・エージェント定義の変更を試す」。

### コミットメッセージと main の履歴

コミットメッセージは `feat(component):` 形式で記述する。サブジェクトは日本語で書く。

- `type`: 履歴で使われているのは `feat` / `fix` / `docs` / `chore` / `perf` / `refactor`
- `component`: 変更対象の領域名。`claude` / `zsh` / `install` / `nix` / `ai-tools` / `ghostty` / `utils` / `macos`

**ブランチ側のコミットがそのまま main の履歴に残る。** このリポジトリが許可するのは merge commit だけで（`allow_merge_commit: true`、`allow_squash_merge` と `allow_rebase_merge` はいずれも false）、マージすると `Merge pull request #<n> from <ブランチ>` の merge commit（`merge_commit_title: MERGE_MESSAGE`）が積まれ、その下にブランチ側のコミットが並ぶ。PR タイトルは main の履歴には現れない。

そのため main の履歴の読みやすさを決めるのはコミットメッセージである。`feat(component):` 形式とコミットの分割は、PR レビューでコミット単位に変更の目的を追うためだけでなく、後から履歴を辿るときにも効く。PR タイトルの形式は `pr-format` スキル（日本語1行・50 字以内・プレフィックスなし）が正本で、こちらは PR 一覧とレビュー時の見出しとして機能する。

`(#112)` のように PR 番号がサブジェクト末尾に付いたコミットは squash マージ時代のもの。運用を切り替える前の履歴なので、新しいコミットで真似しない。

### 重要: zsh 設定
- **重要**: ~/.zshrc は読まれません。$ZDOTDIR 配下（.dotfiles/zsh/）の設定を編集してください
- 設定値: $ZDOTDIR=~/.dotfiles/zsh, no_global_rcs
- `zsh/` 配下のスクリプト（`check.zsh`・`load-log.zsh`）を変更するときは、先に `zsh/AGENTS.md`（対応するテストと挙動の制約）を読む

### Nix/Flake 管理
- `nix/` 配下を変更するときは、先に `nix/AGENTS.md`（マシンごとの構成、パッケージの置き場所）を読む
- `flake.lock` は自動生成。手書き編集せず `nix flake update` で更新する
- `nix flake check --impure` で構文確認可
  - `--impure` 必須: `nix/home.nix` が `builtins.getEnv` で `USER` / `HOME` を取得しているため、pure 評価では両者が空文字列になり `home.homeDirectory` の型エラー（`is not of type 'absolute path'`）で失敗する
  - `flake check` だけでなく `nix build` / `home-manager switch --flake .#$DOTFILES_MACHINE --impure` など評価を伴うコマンドすべてに `--impure` が要る
- **このリポジトリを shallow clone で置かない。** nix が flake の `revCount` を得られず `getting Git object '<sha>': object not found` で失敗する。判定と解消は `nix/AGENTS.md`

### Claude Code 設定
- グローバル `~/.claude/` へ **symlink** で同期する。**編集は必ず dotfiles 側で行う**（`~/.claude/` 側は参照専用。Claude Code は symlink 経由の書き込みを拒否する）
- `settings.json` だけはリンクしない。Claude Code 自身が書き込むファイルのため、`claude/install.sh` の `merge_claude_settings`（共通部の `merge_config` を `hooks` 用のフィルタ付きで呼ぶ）が dotfiles 側の共有キーのみを既存の設定へ上書きする。マシン固有キー（`effortLevel` / `modelSettings` / `autoMode`）は dotfiles 側に書かない
- MCP サーバーをマシン間で共有するには `claude/mcp-servers.json` に書く。`merge_claude_mcp_servers` が `~/.claude.json` へ再帰マージする。マシン固有のサーバーや API キー等のマシン側追記キーは保持される。API キーの値は dotfiles 側に書かない
- 外部スキルの導入は `claude/Skillfile` に行を追加して `./claude/install.sh` を実行する。**`npx skills add` は使わない**（`find-skills` スキルの手順はこれを指示するが従わない）。`find-skills` は探索にだけ使い、見つけた `<owner>/<repo> <skill> <tag>` は Skillfile へ書く
- 仕組みの詳細は `claude/README.md`
- このリポジトリ自身の指示ファイルは `AGENTS.md`（ルート・`ai-tools/`・`nix/`・`macos/`・`karabiner/`・`brew/`・`zsh/`・`utils/`）。**ルートに `CLAUDE.md` / `.claude/CLAUDE.md` / `CLAUDE.local.md` を置かない。** cwd かその親にどれか 1 つでもあると、Claude Code は `AGENTS.md` を読まなくなる
  - `claude/CLAUDE.md` はグローバル指示（`~/.claude/CLAUDE.md`）の配布元で、例外的に `CLAUDE.md` の名前を持つ。`claude/` を cwd にしてセッションを始めるとこれがプロジェクトの `CLAUDE.md` として数えられ、ルートの `AGENTS.md` が読まれないので、セッションはリポジトリのルートで始める
  - サブディレクトリの `AGENTS.md` は、ルートで起動したセッションに自動では載らないことがある。Claude Code はそのディレクトリのファイルを Read したときに読み足すが、Codex は起動時にルートから cwd までの分しか読まない。サブディレクトリに `AGENTS.md` を足したら、ルートのこのファイルの該当節から名指しで参照する

### AI ツール環境（ai-tools）
- ccusage / codegraph を Nix flake で提供する。パッケージング方式と更新手順は `ai-tools/AGENTS.md`

### macOS システム設定（macos）
- `macos/` 配下を変更するときは、先に `macos/AGENTS.md`（`defaults` の型・bool の書き方・入れてはいけない値・テスト）を読む

### Karabiner-Elements 設定（karabiner）
- `karabiner/` 配下を変更するときは、先に `karabiner/AGENTS.md`（`karabiner.json` を symlink 管理できない理由・`profile-defaults.json` が持つキー・テスト）を読む

### Homebrew（brew）
- `brew/` 配下を変更するとき、cask の版を上げたくないとき、cask のアップグレードが途中で止まってアプリが消えたときは、先に `brew/AGENTS.md`（`brew upgrade` を止める方法・途中で止まったときの復旧手順）を読む

## 保守性のルール
1. 新しい dotfiles はインストーラに追加（対象ディレクトリの `install.sh`。無ければルートの `install.sh`）
2. コミットメッセージは `feat(component):` 形式（詳細は「コミットメッセージと main の履歴」）
3. テストは対象コードの隣ではなく `tests/<component>/` に置く（例: `tests/claude/`）。`claude/` 配下に置くと `link_claude_files` が `~/.claude/` へ配ってしまい、除外の追加が必要になる
4. スクリプトや設定を変更したら、対応するテストを流す。テストは `tests/<component>/<名前>_test.sh`（zsh のものは `.zsh`）で、`<名前>` は対象のスクリプト名か関数名を kebab-case にしたもの（`claude/hooks/block-dangerous.sh` → `block-dangerous_test.sh`、`merge_claude_settings` → `merge-claude-settings_test.sh`）。1 本のテストが複数の関数を見ていたり、実物の設定ファイル（`claude/settings.json` など）から期待値を取っていたりするので、名前で見つからなくても `rg -l '<関数名かファイル名>' tests/` で探して、当たったものを流す

## 参考資料
- [README.md](README.md)
