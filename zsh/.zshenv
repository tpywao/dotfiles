# lang
export LANG=ja_JP.UTF-8
export LESSCHARSET=utf-8

export EDITOR=vim
# opt out of telemetry in tools that honor DO_NOT_TRACK; tools that ignore it still send
# (claude/settings.json sets it back to 0 for Claude Code; see claude/README.md)
export DO_NOT_TRACK=1
# path to .zshrc
ZSHENV=$(readlink $HOME/.zshenv)
export ZDOTDIR=${ZSHENV%/*}
# path to dotfiles dir
export DOTFILES=${ZDOTDIR%/*}

# load logging helpers
source $ZDOTDIR/load-log.zsh
# local
export LOCAL_ROOT=$HOME/.local
export REPOSITORIES_HOME="$LOCAL_ROOT/src/repositories"

# path
_load_begin nix
typeset -U path PATH fpath FPATH cdpath manpath
setopt no_global_rcs
fpath=(
  $HOME/.nix-profile/share/zsh/site-functions(N-/)
  /nix/var/nix/profiles/default/share/zsh/site-functions(N-/)
  $fpath
)
path=(
  $HOME/.nix-profile/bin(N-/)
  /nix/var/nix/profiles/default/bin(N-/)
  /usr/local/bin(N-/)
  /usr/bin(N-/)
  /bin(N-/)
  $path
)
_load_end

source $DOTFILES/utils/utils.bash
if is_mac; then
  source $ZDOTDIR/mac.zsh
elif is_wsl; then
  source $ZDOTDIR/wsl.zsh
fi
