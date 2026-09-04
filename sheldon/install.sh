#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

mkdir -p "$HOME/.config/sheldon"
symlink $DOTFILES/sheldon/plugins.toml ~/.config/sheldon/plugins.toml
