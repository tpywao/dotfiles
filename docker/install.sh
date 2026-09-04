#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

mkdir -p "$HOME/.docker"
symlink "$DOTFILES/docker/config.json" "$HOME/.docker/config.json"

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
