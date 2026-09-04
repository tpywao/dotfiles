# Dotfiles Repository Context

このドキュメントは、ユーザーの dotfiles（~/.dotfiles）リポジトリの作業ガイドです。

## プロジェクト概要
- **用途**: macOS + Linux 向けの個人用 dotfiles リポジトリ
- **管理対象**: zsh, git, nix, Homebrew, karabiner, fzf など
- **主な構成**:
  - `zsh/`: zsh 設定（$ZDOTDIR 配下）
  - `git/`: git 設定（gitconfig, gitignore）
  - `nix/`: Nix/NixOS 設定（flake.nix, flake.lock）
  - `brew/`: Homebrew パッケージリスト（Brewfile 群）
  - `karabiner/`: Karabiner-Elements 設定（キーボード）
  - `fzf/`: fzf 設定ファイル
  - `claude/`: Claude Code 関連設定（hooks, skills など）

## インストーラの構成

`install.sh` はディレクトリ単位に分割されている。

- ルートの `install.sh`: 専用ディレクトリを持たない設定（`vimrc`, `tmux.conf`, `screenrc`, `sqliterc`, `direnvrc`, `editorconfig`, bash 用の `bashrc` / `aliases.bash`）の symlink と、各ディレクトリの `install.sh` の実行
  - `editorconfig`（ドットなし）が `~/.editorconfig` へ配布する設定。`.editorconfig`（ドットあり）はこのリポジトリ自身に効かせる設定で、配布対象ではない
- 各ディレクトリの `install.sh`（`git/`, `docker/`, `sheldon/`, `karabiner/`, `ghostty/`, `nix/`, `brew/`, `claude/`）: そのディレクトリに関する処理。ルートがこの順で実行する
- `zsh/install.sh` はループに入れず、`$SHELL` が zsh のときだけ case 分岐から実行する（`fish/`・bash 用のリンクも同じ分岐にある）
- `utils/install-common.sh`: 各 `install.sh` が source する共通部（`link_config()` と `utils/utils.bash` の読み込み）
  - `link_config()` はリンクの有無だけでなく**リンク先**を検証し、違う先を指していれば張り替える。リンク先に実体があるときは、ファイルは内容が一致すれば置き換え・分岐していれば `.presymlink.<ts>` へ退避、ディレクトリは内容を比較せず常に退避する。親ディレクトリの作成も関数内で行うので、呼び出し側に `mkdir -p` は要らない

規約:

- 各 `install.sh` は先頭で `DOTFILES` を自前で解決して `utils/install-common.sh` を source する。単体でも実行できる（例: `./claude/install.sh`）
- ルートは `sh "$DOTFILES/<dir>/install.sh" || exit $?` で呼ぶ。**各サブは末尾で明示的に `exit 0` する**。これが無いと最後のコマンド（`home-manager switch`、`brew bundle`、`ln` など）の失敗がそのままスクリプトの終了ステータスになり、後続のディレクトリが丸ごとスキップされる（分割前は 1 プロセスで、失敗しても後続が走っていた）
- 意図的に全体を止めたいときだけ `exit 1` する（現状は `nix/install.sh` の `DOTFILES_MACHINE` 未設定のみ）
- `link_config()` を `utils/utils.bash` に置かない。`utils.bash` は `zsh/.zshenv` から全 zsh 起動で source されるため、インストール時にしか使わない関数を常駐させない
- サブプロセスなので、サブ側の環境変数・PATH の変更はルートへ届かない。Nix を初めて入れた回に `claude/install.sh` が `jq` / `gh` を見つけられるよう、ルートは `nix` と `brew` の間で `nix-daemon.sh` を読み込む
- `fish/` と `fzf/` はディレクトリごとリンク先（`~/.config/fish`, `~/.fzf`）へ symlink するため、中に `install.sh` を置くとインストーラまでリンク先に配られる。この 2 つはルートの `install.sh` でリンクする
- `claude/install.sh` と `claude/Skillfile` は `link_claude_files` の `find` で除外している。除外しないと `~/.claude/` へリンクされる

## 作業時の注意事項

### 実装開始時のブランチ運用
実装を開始するときは、以下の手順で作業環境を用意してから着手する:

1. `git fetch` でリモートブランチを最新に更新する
2. 新規ブランチを `origin/main` から作成する
3. その新規ブランチの worktree を作成し（EnterWorktree ツールまたは `git worktree add`）、worktree 側で実装する

理由: 古いローカル main や現在の作業ブランチを起点にしないこと、メインの作業ツリーの状態を汚さないことを保証するため。

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

### Nix/Flake 管理
- `flake.nix`: Nix パッケージと home-manager の定義
- `flake.lock`: Nix flake の依存関係ロック（自動生成）
  - **編集禁止**: 手書き編集しないでください
  - 更新方法: `nix flake update` コマンド
- `nix flake check --impure` で構文確認可
  - `--impure` 必須: `nix/home.nix` が `builtins.getEnv` で `USER` / `HOME` を取得しているため、pure 評価では両者が空文字列になり `home.homeDirectory` の型エラー（`is not of type 'absolute path'`）で失敗する
  - `flake check` だけでなく `nix build` / `home-manager switch --flake .#$DOTFILES_MACHINE --impure` など評価を伴うコマンドすべてに `--impure` が要る
- **マシンごとの構成**: `homeConfigurations` はマシンごとにエントリを持ち（例: `work-mac`）、共通の `home.nix` ＋マシン固有モジュール（例: `work-mac.nix`、`common.nix` を imports）を組み合わせる。適用先は環境変数 `DOTFILES_MACHINE` で選択し、dotfiles 管理外の `~/.local/zsh/*.zsh` で export する。**未設定時に別マシンの構成へフォールバックすることはない**（fail-fast）。`nix/install.sh` は `~/.local/zsh/*.zsh` に保存済みの有効な export があればそれを使い、無ければ対話実行時のみ選択メニューを提示して `~/.local/zsh/machine.zsh` に永続化、非対話実行ではエラーで止まる（`home-manager switch` 単体も未設定はエラー）。マシン追加手順は `nix/README.md` を参照
  - `home.packages` はリスト型オプションで、複数モジュールの定義は自動的に concat（マージ）される（後勝ち上書きではない）。マシン固有パッケージは `work-mac.nix` に追加分だけ列挙する（`packages.nix` を再 import すると二重登録になる）
  - 共通パッケージは `nix/packages.nix`、マシン固有は `nix/work-mac.nix` に書く

### Brewfile 管理
- `brew/Brewfile`: macOS Homebrew パッケージリスト
- `brew/Brewfile.gui`: GUI アプリケーションリスト
- 更新方法:
  - `brew bundle dump --file=brew/Brewfile` で現在のパッケージをダンプ
  - 手動編集後、`brew bundle install --file=brew/Brewfile` でインストール

### git 設定
- `git/gitconfig`: グローバル git 設定
- `git/gitignore`: グローバル gitignore
- ローカル git 設定（.gitconfig.local）と結合される
- **編集時の確認**: `git config --list` で反映を確認

### Claude Code 設定
- `claude/`: Claude Code 関連（hooks, skills など）
- グローバル `~/.claude/` へ **symlink** で同期する。**編集は必ず dotfiles 側で行う**（`~/.claude/` 側は参照専用。Claude Code は symlink 経由の書き込みを拒否する）
- `settings.json` だけはリンクしない。Claude Code 自身が書き込むファイルのため、`claude/install.sh` の `merge_claude_settings` が dotfiles 側の共有キーのみを既存の設定へ上書きする。マシン固有キー（`effortLevel` / `modelSettings` / `autoMode`）は dotfiles 側に書かない
- 仕組みの詳細は `claude/README.md`
- `claude/hooks/block-dangerous.sh` を変更したら `sh tests/claude/block-dangerous_test.sh` を流す。止めるべきコマンドと通すべきコマンドの両方をケースにしてある

### AI ツール環境（ai-tools）
- **ディレクトリ**: `ai-tools/`（dotfiles で管理。`flake.nix` からは `path:./ai-tools` で相対参照する）
- **flake.nix**: Node.js + 2つの開発ツール（ccusage, codegraph）を定義
- **常設**: ai-tools は home-manager に統合済み。`home-manager switch` すると codegraph/ccusage が `~/.nix-profile/bin` に入り**常に PATH 上**にある（`nix develop` は不要）
- **パッケージング方式**: `ai-tools/flake.nix` は `buildNpmPackage` + `package-lock.json` で 2 ツールを単一 derivation として提供（lockfile ベースの固定・オフラインビルド。#15/#20 でサプライチェーン対策として npx 方式から移行）
  - 依存取得は `fetchNpmDeps`（fixed-output derivation）による hash 検証つき。推移的依存まで lockfile で固定され、実行時にレジストリへアクセスしない
  - `npmFlags = [ "--ignore-scripts" ]`: install スクリプト（npm マルウェアの主要経路）は実行しない。外さないこと
  - **`runCommand`+`npm install` に戻さないこと**: Nix ビルドサンドボックスはネットワーク不可で、空の derivation を「成功」として生成してしまう（失敗が握りつぶされる）。`fetchNpmDeps` は fixed-output derivation なのでネットワーク可
  - **ツールの更新手順**: `ai-tools/package.json` のバージョンを上げ → `cd ai-tools && npm install --ignore-scripts` で lockfile を再生成 → `flake.nix` の `npmDepsHash` を再計算（いったん `lib.fakeHash` にして `nix build` し、hash mismatch エラーの `got:` の値を転記）。`npmDepsFetcherVersion` を変えた場合も hash の再計算が必要
- **使用方法**: 下記「AI ツール（ccusage, codegraph）」セクションを参照

## AI ツール（ccusage, codegraph）

このリポジトリでは 2 つの AI 関連ツールを Nix flake で一元管理しています。

### セットアップ

home-manager に統合済みのため、通常は追加セットアップ不要。`home-manager switch --flake .#$DOTFILES_MACHINE --impure` で 2 ツールが `~/.nix-profile/bin` に入り、以降どのシェルでもそのまま使える。

（`ai-tools/flake.nix` には dev shell も残っているが、ツールを使うだけなら `cd` や `nix develop` は不要）

### 各ツールの使用方法

#### 1. ccusage — Claude Code トークン使用量・コスト分析

Claude Code の利用状況・トークン消費量・コストを追跡。

```bash
ccusage daily          # 日単位の使用量表示
ccusage weekly         # 週単位の集計
ccusage monthly        # 月単位の集計
ccusage daily --since 2026-05-01      # 特定日以降を表示
ccusage daily --json > usage.json      # JSON でエクスポート
ccusage claude monthly                 # Claude のみ抽出
```

#### 2. codegraph — ローカルコード知識グラフ構築

プロジェクトのコード知識グラフをローカルインデックス化し、Claude Code と連携。セマンティック検索で関連コードを素早く検索可能。

初回セットアップ（プロジェクトごと）：

```bash
codegraph install         # Claude Code 等のエージェントに MCP サーバーを統合
cd ~/my-project
codegraph init            # プロジェクトの .codegraph/ を初期化
```

日常的な使用：

```bash
# init 後は自動で Claude Code がグラフを活用
codegraph sync      # 差分同期（通常はこれ）
codegraph index     # フル再構築（コード大幅変更時。rebuild というサブコマンドは無い）
codegraph status    # インデックス状態の確認
```

効果: Claude Code が関数の呼び出し元検索などを可能に。トークン消費削減（全コード送信不要）

## よく使うコマンド
```bash
# Nix 環境の更新
nix flake update

# Nix 環境のチェック（--impure 必須: getEnv "USER" のため）
nix flake check --impure

# Brewfile の更新
brew bundle dump --file=brew/Brewfile --force

# git 設定確認
git config --list --local
git config --global --list

# zsh 設定の再読み込み
exec zsh
```

## 保守性のルール
1. 自動生成ファイル（flake.lock など）は手書き編集しない
2. 設定変更後は実際に機能するか確認（exec zsh など）
3. 新しい dotfiles はインストーラに追加（対象ディレクトリの `install.sh`。無ければルートの `install.sh`）
4. コミットメッセージは `feat(component):` 形式（詳細は「コミットメッセージと main の履歴」）
5. テストは対象コードの隣ではなく `tests/<component>/` に置く（例: `tests/claude/`）。`claude/` 配下に置くと `link_claude_files` が `~/.claude/` へ配ってしまい、除外の追加が必要になる

## 参考資料
- [README.md](../README.md)
- ユーザーメモリ: zsh の $ZDOTDIR 設定
