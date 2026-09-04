#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

symlink "$DOTFILES/git/gitconfig" "$HOME/.gitconfig"

if [ ! -e "$HOME/.gitconfig.local" ]; then
  echo ""
  echo "📝 Note: Consider creating ~/.gitconfig.local for machine-specific settings"
  echo "   Example:"
  echo "   git config --file ~/.gitconfig.local user.name \"Your Name\""
  echo "   git config --file ~/.gitconfig.local user.email \"your.email@example.com\""
  echo ""
fi

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
