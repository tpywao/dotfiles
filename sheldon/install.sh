#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

link_config "$DOTFILES/sheldon/plugins.toml" "$HOME/.config/sheldon/plugins.toml"

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
