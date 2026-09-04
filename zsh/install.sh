#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# .zshenv だけをリンクする。以降の設定は .zshenv が設定する
# $ZDOTDIR (= $DOTFILES/zsh) から直接読まれる
symlink $DOTFILES/zsh/.zshenv ~/.zshenv
