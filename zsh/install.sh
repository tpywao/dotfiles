#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# .zshenv だけをリンクする。以降の設定は .zshenv が設定する
# $ZDOTDIR (= $DOTFILES/zsh) から直接読まれる
link_config "$DOTFILES/zsh/.zshenv" "$HOME/.zshenv"

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
