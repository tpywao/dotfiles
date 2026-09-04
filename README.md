# dotfiles

zsh / git / Nix (home-manager) / Homebrew / Claude Code などの設定を 1 つのリポジトリで管理し、`install.sh` で各設定ファイルへ symlink を張って反映する個人用 dotfiles。

CLI ツールは Nix で宣言的に、GUI アプリは Homebrew で管理し、マシンごとに変わる値はリポジトリ管理外へ逃がす構成になっている。

- [対応環境](#対応環境)
- [管理対象](#管理対象)
- [必要なもの](#必要なもの)
- [インストール](#インストール)
- [リポジトリ構成](#リポジトリ構成)
- [インストール後の手動作業](#インストール後の手動作業)
- [設計方針](#設計方針)
- [よく使うコマンド](#よく使うコマンド)
- [トラブルシューティング](#トラブルシューティング)
- [マシンを追加する](#マシンを追加する)
- [ライセンス](#ライセンス)

## 対応環境

レイヤーごとに対応範囲が違う。

| レイヤー | 対応 |
| --- | --- |
| `install.sh` の symlink 群 | macOS / Linux / WSL（`utils/utils.bash` の `is_mac` / `is_wsl` / `is_linux` で分岐） |
| Nix + home-manager | **Apple Silicon の macOS のみ**（`flake.nix` の `system = "aarch64-darwin"` 固定）。他のアーキテクチャ・OS で使うには `system` の変更が必要 |
| Homebrew（`brew/Brewfile*`） | macOS |
| Karabiner-Elements / Ghostty の設定 | macOS のみリンクされる |
| `ahk/`（AutoHotkey） | Windows。`install.sh` の対象外で、手動配置 |

シェルは zsh を主対象にしている（fish / bash も `install.sh` に分岐はあるが、設定の充実度は zsh とは差がある）。

## 管理対象

| ディレクトリ / ファイル | 内容 |
| --- | --- |
| [`zsh/`](zsh/README.md) | zsh 設定一式。`~/.zshenv` だけを symlink し、以降は `$ZDOTDIR` 配下から読む |
| [`git/`](git/README.md) | グローバル `gitconfig`、フックスクリプト置き場 |
| [`nix/`](nix/README.md) | home-manager の設定。共通パッケージ（`packages.nix`）とマシン固有モジュール |
| [`ai-tools/`](ai-tools/README.md) | AI 関連 CLI を `buildNpmPackage` で固定して提供する子 flake |
| [`claude/`](claude/README.md) | Claude Code の設定（CLAUDE.md、settings.json、hooks、skills、agents） |
| `brew/` | Homebrew の管理リスト（`Brewfile` = CLI 例外 / `Brewfile.gui` = 常用 GUI / `Brewfile.gui.opt` = オプション GUI） |
| [`ahk/`](ahk/README.md) | Windows 用 AutoHotkey 設定 |
| `fzf/`、`sheldon/`、`ghostty/`、`karabiner/`、`tmux.conf`、`vimrc` ほか | 各ツールの設定ファイル |

Nix で入る CLI ツールの一覧は [`nix/packages.nix`](nix/packages.nix) を参照（`bat` / `eza` / `fd` / `ripgrep` / `fzf` / `delta` / `gh` / `jq` / `zoxide` / `uv` / `nodejs` など）。

## 必要なもの

事前に必要なもの:

- `git`（clone に `gh` を使う場合は `gh` も）
- `curl`（Nix / Homebrew / Claude Code のインストーラを取得する）

未導入なら `install.sh` が y/N で確認したうえでインストールするもの:

- Nix（Determinate Systems のインストーラ）
- Homebrew
- Claude Code

任意（無い場合は該当ステップをスキップする）:

- `jq` — `~/.claude/settings.json` と `~/.docker/config.json` のマージに使う
- `gh` — `claude/Skillfile` に書かれた外部スキルの導入に使う

## インストール

clone 先は任意の場所でよい。`install.sh` は自身の位置から `$DOTFILES` を算出し、zsh 側も `~/.zshenv`（symlink）の実体パスから `$ZDOTDIR` と `$DOTFILES` を逆算するため、特定のパスに固定する必要はない。以下は `~/.dotfiles` に置く例。

1. clone する

   ```sh
   gh repo clone tpywao/dotfiles ~/.dotfiles -- --depth 1 --branch main
   ```

2. インストーラを実行する

   ```sh
   ~/.dotfiles/install.sh
   ```

`install.sh` は実行中のシェルを置き換えない。完了したら新しいシェルを開く（同じシェルで済ませたい場合は `exec $SHELL`）。

`install.sh` は冪等で、張り済みの symlink は `[linked]` と表示してスキップする。設定を更新したあとに何度でも再実行してよい。

### install.sh が行うこと

ルートの `install.sh` は、専用ディレクトリを持たない設定を自分でリンクし、あとは各ディレクトリの `install.sh` を順に呼ぶ。サブは単体でも実行できる（例: `./claude/install.sh` で Claude Code の設定だけ張り直す）。

1. シェル別の symlink（zsh なら `zsh/install.sh` が `~/.zshenv`、fish なら `~/.config/fish`、bash なら `~/.bashrc`）
2. リポジトリ直下の設定を symlink（editorconfig / vim / tmux / screen / sqlite / direnv / fzf）
3. `git/` `docker/` `sheldon/` `karabiner/` `ghostty/` の各 `install.sh`（Karabiner-Elements と Ghostty は macOS のみ。`docker/config.json` はリンクせず `jq` で `~/.docker/config.json` へマージ）
4. `nix/install.sh` — nix.conf をリンク。Nix が無ければインストールを確認 → `DOTFILES_MACHINE` を解決 → `home-manager switch --flake "$DOTFILES#$DOTFILES_MACHINE" --impure`
5. `brew/install.sh` — Homebrew が無ければインストールを確認 → `brew bundle --file=brew/Brewfile`
6. `claude/install.sh` — Claude Code が無ければインストールを確認 → `claude/` 配下を `~/.claude/` へ symlink、`settings.json` のみ `jq` でマージ、`claude/Skillfile` の外部スキルを `gh skill install --pin` で導入

### DOTFILES_MACHINE

適用する home-manager の構成（`flake.nix` の `homeConfigurations` のエントリ名）を環境変数 `DOTFILES_MACHINE` で選ぶ。**未設定のときに別マシンの構成へフォールバックすることはない**。

`nix/install.sh` は次の順で解決する。

1. 環境変数 `DOTFILES_MACHINE`
2. `~/.local/zsh/*.zsh` に保存済みの `export DOTFILES_MACHINE=...`（`flake.nix` に存在する値であること）
3. 対話実行（stdin が tty）なら選択メニューを提示し、選んだ値を `~/.local/zsh/machine.zsh` へ保存する
4. 非対話実行（パイプ・CI）はメニューを出さずエラー終了する

したがって非対話で流す場合は事前に export しておく。

```sh
export DOTFILES_MACHINE=work-mac
~/.dotfiles/install.sh
```

詳細は [nix/README.md](nix/README.md) を参照。

### 更新

```sh
cd $DOTFILES
git pull
./install.sh   # 新しい symlink やパッケージの追加を反映する
```

## リポジトリ構成

```
.
├── install.sh              セットアップ用インストーラ（冪等）。各ディレクトリの install.sh を呼ぶ
├── flake.nix / flake.lock  home-manager の flake（system は aarch64-darwin 固定）
├── brew/                   Homebrew の管理リスト（Brewfile / Brewfile.gui / Brewfile.gui.opt）
├── nix/                    home-manager 設定（home.nix, common.nix, packages.nix, <machine>.nix）
├── ai-tools/               AI CLI ツールを固定する子 flake（buildNpmPackage）
├── zsh/                    $ZDOTDIR 配下の zsh 設定
├── git/                    gitconfig と git hooks
├── claude/                 Claude Code の設定（~/.claude/ へ symlink）と Skillfile
├── fish/                   fish の設定
├── fzf/                    fzf のウィジェット関数
├── sheldon/                zsh プラグイン定義（plugins.toml）
├── ghostty/                Ghostty の設定（macOS）
├── karabiner/              Karabiner-Elements の complex modifications（薙刀式・macOS）
├── ahk/                    Windows 用 AutoHotkey 設定
├── utils/                  シェル共通のユーティリティ（OS 判定関数、インストーラ共通部）
├── docker/                 Docker CLI の config.json
├── cargo/                  プロキシ環境向け cargo 設定
├── docs/                   設計メモ
├── Dockerfile/             用途別 Dockerfile 置き場
└── tmux.conf, vimrc, screenrc, sqliterc, direnvrc, ssh_config, bashrc, ...
```

## インストール後の手動作業

`install.sh` が面倒を見ない部分。

- **git のユーザー情報** — `~/.gitconfig.local` に書く（`gitconfig` から `[include]` で読まれる）

  ```sh
  git config --file ~/.gitconfig.local user.name "Your Name"
  git config --file ~/.gitconfig.local user.email "your.email@example.com"
  ```

- **GUI アプリ** — `install.sh` は `brew/Brewfile` しか流さない

  ```sh
  brew bundle --file=brew/Brewfile.gui
  brew bundle --file=brew/Brewfile.gui.opt   # 必要なときだけ
  ```

- **Claude Code のプラグイン** — marketplace の登録までは `settings.json` の同期で入るが、プラグイン本体は自動インストールされない。起動時に表示される `claude plugin install <name>` を一度実行する
- **git hooks** — `git/hooks/` はどこからも配線されていない。使うなら対象リポジトリの `.git/hooks/` へコピーするか `core.hooksPath` を向ける
- **AutoHotkey** — `ahk/` は Windows 側で手動配置する

## 設計方針

- **zsh は `~/.zshenv` だけを張る** — その中で `$ZDOTDIR` をこのリポジトリの `zsh/` に向け、`no_global_rcs` も設定する。したがって `~/.zshrc` は読まれない
- **CLI は Nix、GUI は Homebrew** — CLI ツールは `nix/packages.nix` で宣言的に固定する。nixpkgs に無い CLI だけ例外的に `brew/Brewfile` の formula で入れる
- **マシン固有の値はリポジトリの外へ** — `DOTFILES_MACHINE` は `~/.local/zsh/*.zsh`、git のユーザー情報は `~/.gitconfig.local`。リポジトリ側にはマシン・個人に固有の文言を置かない
- **マシン構成の取り違えを防ぐため fail-fast** — `DOTFILES_MACHINE` 未設定時に既定の構成へ倒さない。設定し忘れたマシンに別マシンの構成が黙って当たるのを防ぐ
- **アプリ自身が書き込む設定ファイルはリンクせずマージ** — Claude Code の `settings.json` と Docker の `config.json` は、アプリがマシン固有の値（モデル設定、認証情報の保存先など）を書き込む。リンクを張るとその値が dotfiles 側へ流れ込み、dotfiles 側の内容で置き換えると失われるため、共有したいキーだけを `jq` で既存の設定へ上書きする（[claude/README.md](claude/README.md)）
- **外部スキルは vendoring しない** — 実体をリポジトリに取り込まず、`claude/Skillfile` にリリースタグを pin してマニフェスト管理する
- **npm 由来のツールは lockfile で固定してオフラインビルド** — `ai-tools/` は `buildNpmPackage` + `--ignore-scripts` で、install スクリプトを実行せず推移的依存まで固定する（[ai-tools/README.md](ai-tools/README.md)）

## よく使うコマンド

```sh
# 設定の反映（冪等。symlink の追加・Claude 設定の同期・外部スキル導入）
./install.sh

# home-manager の適用（--impure 必須）
home-manager switch --flake "$DOTFILES#$DOTFILES_MACHINE" --impure

# flake の更新と検証
nix flake update
nix flake check --impure
nix build ".#homeConfigurations.$DOTFILES_MACHINE.activationPackage" --no-link --impure

# Homebrew
brew bundle --file=brew/Brewfile
brew bundle check --file=brew/Brewfile.gui

# zsh 設定の再読み込み
exec zsh
```

`hms`（home-manager switch）や `nfu`（nix flake update）などの略語は `zsh/abbr.zsh` に定義してある。

## トラブルシューティング

- **`Username could not be determined` で Nix の評価が落ちる**
  `--impure` を付ける。`nix/home.nix` が `builtins.getEnv "USER"` を使うため、pure 評価では失敗する。`flake check` / `build` / `home-manager switch` のいずれにも必要。

- **`~/.zshrc` を編集しても反映されない**
  読まれていない。`$ZDOTDIR`（= `zsh/`）配下の `.zshrc` を編集する（[zsh/README.md](zsh/README.md)）。

- **`DOTFILES_MACHINE is not set` で `install.sh` が止まる**
  非対話実行では選択メニューを出さずエラー終了する。事前に `export DOTFILES_MACHINE=<machine>` するか、対話実行して選択する。

- **新しいマシンで `home-manager` コマンドが無い**
  初回だけ `nix run` 経由で実行する。以降は `programs.home-manager.enable` により PATH に入る。

  ```sh
  nix run home-manager -- switch --flake "$DOTFILES#$DOTFILES_MACHINE" --impure
  ```

- **`[skipped] ... (jq が無い)` と出る**
  `jq` を入れてから `install.sh` を再実行する。Claude Code か Docker の共有設定が反映されていない。

- **`[skipped] 外部スキルの導入 (gh が無い)` と出る**
  `gh` を入れてから `install.sh` を再実行する。

- **設定ファイルの隣に `*.presymlink.<timestamp>` が残っている**
  symlink 化の際に、リンク先に内容の違う実体があったファイル・ディレクトリの退避。中身を確認したうえで手で削除する。

## マシンを追加する

1. `nix/<machine>.nix` を作成する（`common.nix` を imports し、そのマシン固有のパッケージ・設定を書く）
2. `flake.nix` の `homeConfigurations` に `<machine> = mkHome ./nix/<machine>.nix;` を追加する
3. 新しいマシンの `~/.local/zsh/` で `export DOTFILES_MACHINE=<machine>` を設定する

詳細と注意点は [nix/README.md](nix/README.md) を参照。

## ライセンス

[MIT](LICENSE)
