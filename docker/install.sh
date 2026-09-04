#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

symlink $DOTFILES/docker/config.json ~/.docker/config.json
