#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")" && pwd -P)
. "$DOTFILES/utils/install-common.sh"
shell=${1:-$SHELL}

case $shell in
  *fish )
    # fish/ はディレクトリごと ~/.config/fish へリンクするため、fish/install.sh を
    # 置くとインストーラまでリンク先に配られる。ここでリンクする
    symlink $DOTFILES/fish ~/.config/fish
    ;;
  *zsh )
    sh "$DOTFILES/zsh/install.sh" || exit $?
    ;;
  *bash )
    symlink $DOTFILES/bashrc ~/.bashrc
    symlink $DOTFILES/aliases.bash ~/.aliases.bash
    ;;
esac

# 専用ディレクトリを持たない、リポジトリ直下の設定ファイル
symlink $DOTFILES/.editorconfig ~/.editorconfig
symlink $DOTFILES/vimrc ~/.vimrc
symlink $DOTFILES/tmux.conf ~/.tmux.conf
symlink $DOTFILES/screenrc ~/.screenrc
symlink $DOTFILES/sqliterc ~/.sqliterc
symlink $DOTFILES/direnvrc ~/.direnvrc

# fzf/ も fish/ と同じくディレクトリごとリンクするため、ここでリンクする
symlink $DOTFILES/fzf ~/.fzf

# 各ディレクトリの install.sh。それぞれ単体でも実行できる (例: ./git/install.sh)
for dir in git docker sheldon karabiner ghostty nix brew claude; do
  sh "$DOTFILES/$dir/install.sh" || exit $?
done

exec $SHELL
