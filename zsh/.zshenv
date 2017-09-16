# lang
export LANG=ja_JP.UTF-8

# local
LOCAL_ROOT=$HOME/local
# ghq and etc.
export REPOSITORIES_HOME="$LOCAL_ROOT/src/repositories"
export GHQ_ROOT=$REPOSITORIES_HOME
# path to dotfiles dir
export DOTFILES=$HOME/.dotfiles
# path to .zshrc
export ZDOTDIR=$DOTFILES/zsh

# path
typeset -U path PATH cdpath fpath manpath
setopt no_global_rcs
path=(
      # local
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

# rbenv
export RBENV_ROOT="$HOME/.rbenv"
if [ -d $RBENV_ROOT ]; then
  path=(
        $RBENV_ROOT/bin(N-/)
        $path
        )
  eval "$(rbenv init --no-rehash - zsh)"
  . $RBENV_ROOT/completions/rbenv.zsh
fi

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
if [ -d $PYENV_ROOT ]; then
  path=(
        $PYENV_ROOT/bin(N-/)
        $path
        )
  eval "$(pyenv init --no-rehash - zsh)"
  # eval "$(pyenv virtualenv-init - zsh)"
  pyenv virtualenvwrapper_lazy
  . $PYENV_ROOT/completions/pyenv.zsh
  if type pip > /dev/null 2>&1; then
    eval "$(pip completion --zsh)"
  fi
fi

# golang
export GOROOT="/usr/local/go"
export GOPATH="/usr/local/gocode"
if [ -d $GOROOT ] && [ -d $GOPATH ]; then
  path=(
        $GOPATH/bin(N-/)
        $GOROOT/bin(N-/)
        $path
        )
  export GO15VENDOREXPERIMENT=1
  export PROJECT_HOME=$REPOSITORIES_HOME
fi

# nodebrew
# https://github.com/hokaccha/nodebrew
export NODEBREW_ROOT="$HOME/.nodebrew"
if [ -d $NODEBREW_ROOT ]; then
  path=(
        $NODEBREW_ROOT/current/bin(N-/)
        $path
        )
fi

export DIRENV_ROOT="$HOME/.direnv"
if [ -d $DIRENV_ROOT ]; then
  export EDITOR=vim
  eval "$(direnv hook zsh)"
fi

