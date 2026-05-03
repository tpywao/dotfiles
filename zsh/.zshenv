# lang
export LANG=ja_JP.UTF-8
export LESSCHARSET=utf-8

export EDITOR=vim
# path to .zshrc
ZSHENV=$(readlink $HOME/.zshenv)
export ZDOTDIR=${ZSHENV%/*}
# path to dotfiles dir
export DOTFILES=${ZDOTDIR%/*}
# local
export LOCAL_ROOT=$HOME/.local
export REPOSITORIES_HOME="$LOCAL_ROOT/src/repositories"

# path
typeset -U path PATH fpath FPATH cdpath manpath
setopt no_global_rcs
path=(
  $HOME/.nix-profile/bin(N-/)
  /nix/var/nix/profiles/default/bin(N-/)
  /usr/local/bin(N-/)
  /usr/bin(N-/)
  /bin(N-/)
  $path
)

source $DOTFILES/utils/utils.bash
if is_mac; then
  source $ZDOTDIR/mac.zsh
elif is_wsl; then
  source $ZDOTDIR/wsl.zsh
fi
