# Dotfiles Repository Context

このドキュメントは、ユーザーの dotfiles（~/.dotfiles）リポジトリの作業ガイドです。

## プロジェクト概要
- **用途**: macOS + Linux 向けの個人用 dotfiles リポジトリ
- **管理対象**: zsh, git, nix, Homebrew, karabiner, fzf など

## インストーラの構成

`install.sh` はディレクトリ単位に分割されている。

- ルートの `install.sh`: 専用ディレクトリを持たない設定（`vimrc`, `tmux.conf`, `screenrc`, `sqliterc`, `direnvrc`, `editorconfig`, bash 用の `bashrc` / `aliases.bash`）の symlink と、各ディレクトリの `install.sh` の実行
  - `editorconfig`（ドットなし）が `~/.editorconfig` へ配布する設定。`.editorconfig`（ドットあり）はこのリポジトリ自身に効かせる設定で、配布対象ではない
- 各ディレクトリの `install.sh`（`git/`, `sheldon/`, `karabiner/`, `ghostty/`, `nix/`, `brew/`, `docker/`, `claude/`）: そのディレクトリに関する処理。ルートがこの順で実行する
  - **順序の制約は「`nix/` より後に `docker/` と `claude/`」だけ。** この 2 つは設定を `jq` でマージし、`jq` は `nix/packages.nix` で入る（前に置くと jq が無いマシンの初回実行でマージがスキップされ、2 回目まで反映されない）。残りのディレクトリの順序に意味は無い
  - `docker/` と `claude/` の前で `nix-daemon.sh` を読み込む必要があるため、ループが 2 つに分かれている。**後半のループには制約のある 2 つだけを置く**（制約の無いものを混ぜると、そこにいる理由をコメントで説明できなくなる）
- `zsh/install.sh` はループに入れず、`$SHELL` が zsh のときだけ case 分岐から実行する（`fish/`・bash 用のリンクも同じ分岐にある）
- `utils/install-common.sh`: 各 `install.sh` が source する共通部（`link_config()`、`merge_config()`、`log_tag()` と `utils/utils.bash` の読み込み）
  - `link_config()` はリンクの有無だけでなく**リンク先**を検証し、違う先を指していれば張り替える。リンク先に実体があるときは、ファイルは内容が一致すれば置き換え・分岐していれば `.presymlink.<ts>` へ退避、ディレクトリは内容を比較せず常に退避する。親ディレクトリの作成も関数内で行うので、呼び出し側に `mkdir -p` は要らない
  - `merge_config <src> <dst> [<jq フィルタ>]` は JSON の共有キーだけを既存の設定へ上書き適用する（下の「アプリ自身が書き込む設定ファイル」を参照）。フィルタは `.[0]` を `dst`、`.[1]` を `src` として受け取り、既定は再帰マージ（`.[0] * .[1]`）
    - マージ結果を確定させる前に「`dst` にあって結果に無い配列要素」を洗い出し、見つかれば `[dropped]` で列挙して `.premerge.<ts>` へ退避する。`src` と突き合わせるのではなく**マージ結果**と突き合わせるので、呼び出し側が渡すフィルタが何をするかに依存しない
  - `utils/install-common.sh` を変更したら `sh tests/utils/link-config_test.sh` と `sh tests/utils/merge-config_test.sh` を流す。前者はリンク先の状態ごとに 6 経路、後者は `dst` の状態・フィルタの有無・配列要素の消失検出で 13 ケースあり、出力タグ・マージ後の内容・退避の中身をケースにしてある
- 出力の書式は 2 系統に分ける。**対象ごとの結果**は `log_tag <色> <[タグ]> <対象>` でタグ付き 1 行にする（`[linked]` / `[new]` / `[relinked]` / `[replaced]` / `[dropped]` / `[backup]` / `[merged]` / `[installed]` / `[skipped]` / `[unlinked]` / `[failed]`）。色はシアン=変化なし、緑=新規、黄=既存を動かした、赤=失敗。**対象を持たない進行ログ**（`-----> Switching home-manager` など）は `----->` のままにする

規約:

- 各 `install.sh` は先頭で `DOTFILES` を自前で解決して `utils/install-common.sh` を source する。単体でも実行できる（例: `./claude/install.sh`）
- ルートは `sh "$DOTFILES/<dir>/install.sh" || exit $?` で呼ぶ。**各サブは末尾で明示的に `exit 0` する**。これが無いと最後のコマンド（`home-manager switch`、`brew bundle`、`ln` など）の失敗がそのままスクリプトの終了ステータスになり、後続のディレクトリが丸ごとスキップされる（分割前は 1 プロセスで、失敗しても後続が走っていた）
- 意図的に全体を止めたいときだけ `exit 1` する（現状は `nix/install.sh` の `DOTFILES_MACHINE` 未設定のみ）
- `link_config()` を `utils/utils.bash` に置かない。`utils.bash` は `zsh/.zshenv` から全 zsh 起動で source されるため、インストール時にしか使わない関数を常駐させない
- サブプロセスなので、サブ側の環境変数・PATH の変更はルートへ届かない。Nix を初めて入れた回に `docker/install.sh` と `claude/install.sh` が `jq` / `gh` を見つけられるよう、ルートは `nix` の直後に `nix-daemon.sh` を読み込む
- `fish/` と `fzf/` はディレクトリごとリンク先（`~/.config/fish`, `~/.fzf`）へ symlink するため、中に `install.sh` を置くとインストーラまでリンク先に配られる。この 2 つはルートの `install.sh` でリンクする
- `claude/install.sh` と `claude/Skillfile` は `link_claude_files` の `find` で除外している。除外しないと `~/.claude/` へリンクされる
- **アプリ自身が書き込む設定ファイルは `link_config()` ではなく `merge_config()` を使う。** リンクを張るとアプリが書いたマシン固有の値が dotfiles 側へ流れ込み、逆に dotfiles 側の内容で置き換えるとその値が失われる。dotfiles 側は共有したいキーだけを持ち、`dst` にしか無いキーは触らない。該当するのは `claude/settings.json`、`claude/mcp-servers.json`、`docker/config.json` の 3 つ
  - `claude/settings.json`: Claude Code が `model` / `effortLevel` / `autoMode` を書き込む。`hooks` だけは dotfiles を唯一の正として差し替えたいので、`merge_claude_settings` が `merge_config` へフィルタを渡す（`jq` の `*` は再帰マージだけで削除を表現できず、dotfiles 側で消した hook が既存の設定に残ってしまう）
  - `claude/mcp-servers.json`: 配布先は `~/.claude.json`（Claude Code がセッション状態やプロジェクト履歴を書き込む）。dotfiles 側はマシン間で共有したい `mcpServers` のエントリだけを持ち、フィルタは既定のまま（差し替えるとマシン固有のサーバーが消える）。dotfiles 側で消したサーバーは各マシンで `claude mcp remove` する
  - `docker/config.json`: Docker Desktop が `credsStore` / `currentContext` / `plugins` / `features` を書き込む。dotfiles 側が持つのは `detachKeys` だけで、フィルタは既定のまま
  - **配列は再帰マージされず `src` の内容で置換される。** `jq` の `*` はオブジェクトだけを再帰マージするため、`dst` にしか無い配列要素は失われる。アプリが書き込む値が配列に入るキー（`permissions.allow` に「常に許可」で追加されたルールなど）がこれに該当する。`merge_config` は消える要素を確定前に洗い出して `[dropped]` で列挙し、マージ前の `dst` を `.premerge.<ts>` へ退避する。復旧の選択肢は 2 つ
    - **恒久化**: 残したい要素を dotfiles 側の `src` に追記して再実行する。dotfiles 側が正なので全マシンへ配布される
    - **その場の復旧**: `.premerge.<ts>` を `dst` へ戻す。ただし dotfiles 側の更新も巻き戻り、次の実行で再び `[dropped]` になる
    - そのマシンだけで使いたい許可は、グローバルではなくプロジェクトの `.claude/settings.local.json` に置く（`merge_config` の対象外なので消えない）
  - `merge_config` は以前のバージョンが張った symlink を見つけたら、内容を実体へコピーし直してからマージする（リンクのまま書き込むと `src` を書き換えるため）。これらのファイルを新たに symlink 管理へ戻さないこと

## 作業時の注意事項

### 実装開始時のブランチ運用
新規ブランチは必ず `origin/main` から作成する（`git fetch` 後）。古いローカル main や現在の作業ブランチを起点にしない。worktree を切ってから着手する手順そのものはユーザーメモリ側の規則が正本。

### コミットメッセージと main の履歴

コミットメッセージは `feat(component):` 形式で記述する。サブジェクトは日本語で書く。

- `type`: 履歴で使われているのは `feat` / `fix` / `docs` / `chore` / `perf` / `refactor`
- `component`: 変更対象の領域名。`claude` / `zsh` / `install` / `nix` / `ai-tools` / `ghostty` / `utils`

**main の履歴は PR タイトルから生成される（squash）。** このリポジトリは squash マージのみを許可し（`allow_merge_commit` / `allow_rebase_merge` はいずれも false）、squash コミットのタイトルは PR タイトルから生成される（`squash_merge_commit_title: PR_TITLE`）。そのためブランチ側のコミットメッセージは main の履歴に残らず、main の文面を決めるのは PR タイトルである。PR タイトルの形式は `pr-format` スキル（日本語1行・50 字以内・プレフィックスなし）が正本。

`feat(component):` 形式は、PR レビュー時にコミット単位で変更の目的を追うために維持する。main の履歴を Conventional Commits に揃えたい場合は、この CLAUDE.md ではなく `pr-format` スキル側の規約を変える必要がある。

### 固有文言の禁止
- このリポジトリに追加するファイル（skills, hooks, 設定, ドキュメント等）には、**マシン・個人・勤務先プロジェクトに固有の文言を書かない**
  - 対象: ユーザー名、ホスト名、勤務先の社名・プロジェクト名・リポジトリ名、社内 URL など
  - 例示が必要な場合はプレースホルダや汎用名を使う（`<user>`, `~/dev/myrepo` など）。ホームディレクトリは `~` / `$HOME` で表記する
- 理由: このリポジトリは複数マシンで共用し、公開しても支障ない状態を保つため

### 重要: zsh 設定
- **重要**: ~/.zshrc は読まれません。$ZDOTDIR 配下（.dotfiles/zsh/）の設定を編集してください
- 設定値: $ZDOTDIR=~/.dotfiles/zsh, no_global_rcs
- zsh 設定ファイル: `zsh/.zshrc`, `zsh/.zprofile`, `zsh/.zlogout`
- `zsh/check.zsh` を変更したら `zsh tests/zsh/check_test.zsh` を流す。`git` をスタブに差し替えて「flake.lock のどのノードを何回・どの ref 指定で問い合わせるか」をケースにしてあり、ネットワークへは出ない
  - 末尾の `_dotfiles_check` 自動実行は `DOTFILES_CHECK_NO_AUTORUN` で抑止できる。テストが関数定義だけを読み込むためにある
  - `_dotfiles_check_nix_upstream_daily` の `ls-remote` には ref を `refs/heads/<ref>` / `refs/tags/<ref>` のフルパスで渡す。裸の ref 名だとサーバ側フィルタが効かず、ref 数の多いリポジトリ（nixpkgs）1 件で 100 秒以上かかり起動がブロックされる

### Nix/Flake 管理
- `flake.lock` は自動生成。手書き編集せず `nix flake update` で更新する
- `nix flake check --impure` で構文確認可
  - `--impure` 必須: `nix/home.nix` が `builtins.getEnv` で `USER` / `HOME` を取得しているため、pure 評価では両者が空文字列になり `home.homeDirectory` の型エラー（`is not of type 'absolute path'`）で失敗する
  - `flake check` だけでなく `nix build` / `home-manager switch --flake .#$DOTFILES_MACHINE --impure` など評価を伴うコマンドすべてに `--impure` が要る

### git 設定
- ローカル git 設定（.gitconfig.local）と結合される

### Claude Code 設定
- `claude/`: Claude Code 関連（hooks, skills など）
- グローバル `~/.claude/` へ **symlink** で同期する。**編集は必ず dotfiles 側で行う**（`~/.claude/` 側は参照専用。Claude Code は symlink 経由の書き込みを拒否する）
- `settings.json` だけはリンクしない。Claude Code 自身が書き込むファイルのため、`claude/install.sh` の `merge_claude_settings`（共通部の `merge_config` を `hooks` 差し替えのフィルタ付きで呼ぶ）が dotfiles 側の共有キーのみを既存の設定へ上書きする。マシン固有キー（`effortLevel` / `modelSettings` / `autoMode`）は dotfiles 側に書かない
- MCP サーバーをマシン間で共有するには `claude/mcp-servers.json` に書く。`merge_claude_mcp_servers` が `~/.claude.json` へ再帰マージする。マシン固有のサーバーや API キー等のマシン側追記キーは保持される。API キーの値は dotfiles 側に書かない
- 仕組みの詳細は `claude/README.md`
- `claude/hooks/block-dangerous.sh` を変更したら `sh tests/claude/block-dangerous_test.sh` を流す。止めるべきコマンドと通すべきコマンドの両方をケースにしてある

### AI ツール環境（ai-tools）
- ccusage / codegraph を Nix flake で提供する。パッケージング方式と更新手順は `ai-tools/CLAUDE.md`

## 保守性のルール
1. 新しい dotfiles はインストーラに追加（対象ディレクトリの `install.sh`。無ければルートの `install.sh`）
2. コミットメッセージは `feat(component):` 形式（詳細は「コミットメッセージと main の履歴」）
3. テストは対象コードの隣ではなく `tests/<component>/` に置く（例: `tests/claude/`）。`claude/` 配下に置くと `link_claude_files` が `~/.claude/` へ配ってしまい、除外の追加が必要になる

## 参考資料
- [README.md](../README.md)
