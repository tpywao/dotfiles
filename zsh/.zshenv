# lang
export LANG=ja_JP.UTF-8
export LESSCHARSET=utf-8

# local
export LOCAL_ROOT=$HOME/.local
export EDITOR=vim
export REPOSITORIES_HOME="$LOCAL_ROOT/src/repositories"
# path to dotfiles dir
export DOTFILES=$HOME/.dotfiles
# path to .zshrc
export ZDOTDIR=$DOTFILES/zsh

# path
typeset -U path PATH cdpath fpath manpath
setopt no_global_rcs
path=(
      $LOCAL_ROOT/bin(N-/)
      /usr/local/bin(N-/)
      /usr/bin(N-/)
      /bin(N-/)
      $path
      )
fpath=(
       $HOME/.completions(N-/)
       $ZDOTDIR/completions(N-/)
       $fpath
       )

source $ZDOTDIR/utils.zsh
if is_mac; then
  source $ZDOTDIR/mac.zsh
elif is_wsl; then
  source $ZDOTDIR/wsl.zsh
fi

# direnv
if is_cmd_exists direnv; then
  eval "$(direnv hook zsh)"
fi
