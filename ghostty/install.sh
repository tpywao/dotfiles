#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# macos-option-as-alt は macOS 専用設定のため macOS のみ
is_mac || exit 0

mkdir -p "$HOME/.config/ghostty"
symlink $DOTFILES/ghostty/config ~/.config/ghostty/config
