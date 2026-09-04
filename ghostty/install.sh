#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# Ghostty / cmux 用の設定。macos-option-as-alt は macOS 専用設定のため macOS のみ
is_mac || exit 0

mkdir -p "$HOME/.config/ghostty"
symlink $DOTFILES/ghostty/config ~/.config/ghostty/config

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
