#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# 薙刀式 complex modifications - macOS only
is_mac || exit 0

link_config "$DOTFILES/karabiner/Naginata.json" "$HOME/.config/karabiner/assets/complex_modifications/Naginata.json"

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
