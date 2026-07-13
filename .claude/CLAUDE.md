# Dotfiles Repository Context

このドキュメントは、ユーザーの dotfiles（~/.dotfiles）リポジトリの作業ガイドです。

## プロジェクト概要
- **用途**: macOS + Linux 向けの個人用 dotfiles リポジトリ
- **管理対象**: zsh, git, nix, Brewfile, karabiner, fzf など
- **主な構成**:
  - `zsh/`: zsh 設定（$ZDOTDIR 配下）
  - `git/`: git 設定（gitconfig, gitignore）
  - `nix/`: Nix/NixOS 設定（flake.nix, flake.lock）
  - `Brewfile`: macOS Homebrew パッケージリスト
  - `karabiner/`: Karabiner-Elements 設定（キーボード）
  - `fzf/`: fzf 設定ファイル
  - `claude/`: Claude Code 関連設定（hooks, skills など）

## 作業時の注意事項

### 重要: zsh 設定
- **重要**: ~/.zshrc は読まれません。$ZDOTDIR 配下（.dotfiles/zsh/）の設定を編集してください
- 設定値: $ZDOTDIR=~/.dotfiles/zsh, no_global_rcs
- zsh 設定ファイル: `zsh/.zshrc`, `zsh/.zprofile`, `zsh/.zlogout`

### Nix/Flake 管理
- `flake.nix`: Nix パッケージと home-manager の定義
- `flake.lock`: Nix flake の依存関係ロック（自動生成）
  - **編集禁止**: 手書き編集しないでください
  - 更新方法: `nix flake update` コマンド
- `nix flake check` で構文確認可

### Brewfile 管理
- `Brewfile`: macOS Homebrew パッケージリスト
- `Brewfile.gui`: GUI アプリケーションリスト
- 更新方法:
  - `brew bundle dump --file=Brewfile` で現在のパッケージをダンプ
  - 手動編集後、`brew bundle install` でインストール

### git 設定
- `git/gitconfig`: グローバル git 設定
- `git/gitignore`: グローバル gitignore
- ローカル git 設定（.gitconfig.local）と結合される
- **編集時の確認**: `git config --list` で反映を確認

### Claude Code 設定
- `claude/`: Claude Code 関連（hooks, skills など）
- グローバル ~/.claude/ との hardlink で同期
- Edit/Write 後に自動で hardlink が再同期される

## よく使うコマンド
```bash
# Nix 環境の更新
nix flake update

# Nix 環境のチェック
nix flake check

# Brewfile の更新
brew bundle dump --file=Brewfile --force

# git 設定確認
git config --list --local
git config --global --list

# zsh 設定の再読み込み
exec zsh
```

## 保守性のルール
1. 自動生成ファイル（flake.lock など）は手書き編集しない
2. 設定変更後は実際に機能するか確認（exec zsh など）
3. 新しい dotfiles は install.sh に追加
4. git commit 時は `feat(component):` 形式で記述

## 参考資料
- [README.md](../README.md)
- ユーザーメモリ: zsh の $ZDOTDIR 設定
