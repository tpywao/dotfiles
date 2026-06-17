#! /bin/sh
DOTFILES=`cd $(dirname $0) && pwd -P`
shell=${1:-$SHELL}

# OS 判定関数 (is_mac, is_wsl, is_linux)
. "$DOTFILES/utils/utils.bash"

hardlink() {
  file=$1
  link=$2
  if [ "$file" -ef "$link" ]; then
    printf "\033[0;36m[linked]\033[0m %s\n" "$link"
  elif [ ! -e "$link" ]; then
    echo "-----> Hardlinking your new $link"
    ln "$file" "$link"
  fi
}

symlink() {
  file=$1
  link=$2
  if [ -L "$link" ]; then
    printf "\033[0;36m[linked]\033[0m %s\n" "$link"
  elif [ ! -e "$link" ]; then
    echo "-----> Symlinking your new $link"
    ln -si $file $link
  fi
}

case $shell in
  *fish )
    symlink $DOTFILES/fish ~/.config/fish
    ;;
  *zsh )
    symlink $DOTFILES/zsh/.zshenv ~/.zshenv
    ;;
  *bash )
    symlink $DOTFILES/bashrc ~/.bashrc
    symlink $DOTFILES/aliases.bash ~/.aliases.bash
    ;;
esac

# EditorConfig
symlink $DOTFILES/.editorconfig ~/.editorconfig

# vim
symlink $DOTFILES/vimrc ~/.vimrc

# git
symlink $DOTFILES/git/gitconfig ~/.gitconfig
if [ ! -e "$HOME/.gitconfig.local" ]; then
  echo ""
  echo "📝 Note: Consider creating ~/.gitconfig.local for machine-specific settings"
  echo "   Example:"
  echo "   git config --file ~/.gitconfig.local user.name \"Your Name\""
  echo "   git config --file ~/.gitconfig.local user.email \"your.email@example.com\""
  echo ""
fi

# docker
symlink $DOTFILES/docker/config.json ~/.docker/config.json

# tmux
symlink $DOTFILES/tmux.conf ~/.tmux.conf

# screen
symlink $DOTFILES/screenrc ~/.screenrc

# sqlite
symlink $DOTFILES/sqliterc ~/.sqliterc

# direnv
symlink $DOTFILES/direnvrc ~/.direnvrc

# fzf
symlink $DOTFILES/fzf ~/.fzf

# sheldon
mkdir -p "$HOME/.config/sheldon"
symlink $DOTFILES/sheldon/plugins.toml ~/.config/sheldon/plugins.toml

# Nix config
mkdir -p "$HOME/.config/nix"
symlink $DOTFILES/nix/nix.conf ~/.config/nix/nix.conf

# Karabiner-Elements (薙刀式 complex modifications) - macOS only
if is_mac; then
  mkdir -p "$HOME/.config/karabiner/assets/complex_modifications"
  symlink $DOTFILES/karabiner/Naginata.json ~/.config/karabiner/assets/complex_modifications/Naginata.json
fi

# Nix + home-manager
if ! command -v nix > /dev/null 2>&1; then
  NIX_INSTALL_CMD="curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
  echo "Nix is not installed."
  echo "  $NIX_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$NIX_INSTALL_CMD"
    # Load Nix into the current shell session after installation
    NIX_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    [ -f "$NIX_PROFILE" ] && . "$NIX_PROFILE"
  else
    echo "Skipping Nix installation."
  fi
fi

if command -v nix > /dev/null 2>&1; then
  if ! command -v home-manager > /dev/null 2>&1; then
    echo "-----> Applying home-manager for the first time"
    nix run home-manager -- switch --flake "$DOTFILES#$(whoami)" --impure
  else
    echo "-----> Switching home-manager"
    home-manager switch --flake "$DOTFILES#$(whoami)" --impure
  fi
fi

# Homebrew casks
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
  if [ -f "$DOTFILES/Brewfile" ]; then
    echo "-----> Installing casks from Brewfile"
    brew bundle --file="$DOTFILES/Brewfile"
  fi
fi

# Claude Code
link_claude_md() {
  find "$DOTFILES/claude" -type f | while read -r src; do
    rel="${src#$DOTFILES/claude/}"
    dst="$HOME/.claude/$rel"
    mkdir -p "$(dirname "$dst")"
    hardlink "$src" "$dst"
  done
}

if ! command -v claude > /dev/null 2>&1; then
  CLAUDE_INSTALL_CMD="curl -fsSL https://claude.ai/install.sh | bash"
  echo "Claude Code is not installed."
  echo "  $CLAUDE_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$CLAUDE_INSTALL_CMD"
    link_claude_md
  else
    echo "Skipping Claude Code installation."
  fi
else
  link_claude_md
fi

exec $SHELL
