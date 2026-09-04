#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

if ! command -v brew > /dev/null 2>&1; then
  BREW_INSTALL_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo "Homebrew is not installed."
  echo "  $BREW_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$BREW_INSTALL_CMD"
    # Load brew into the current shell session after installation
    [ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Skipping Homebrew installation."
  fi
fi

if command -v brew > /dev/null 2>&1; then
  if [ -f "$DOTFILES/brew/Brewfile" ]; then
    echo "-----> Installing casks from Brewfile"
    brew bundle --file="$DOTFILES/brew/Brewfile"
  fi
fi
