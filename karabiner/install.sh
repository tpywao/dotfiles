#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# 薙刀式 complex modifications - macOS only
is_mac || exit 0

mkdir -p "$HOME/.config/karabiner/assets/complex_modifications"
symlink $DOTFILES/karabiner/Naginata.json ~/.config/karabiner/assets/complex_modifications/Naginata.json
