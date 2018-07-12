# lang
export LANG=ja_JP.UTF-8

# local
LOCAL_ROOT=$HOME/local
export EDITOR=vim
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

# brew openssl
path=(
      /usr/local/opt/openssl/bin(N-/)
      $path
      )

# rust
export CARGO_ROOT="$HOME/.cargo"
if [ -d $CARGO_ROOT ]; then
  source $CARGO_ROOT/env
fi

# rbenv
export RBENV_ROOT="$HOME/.rbenv"
if [ -d $RBENV_ROOT ]; then
  path=(
        $RBENV_ROOT/bin(N-/)
        $path
        )
  eval "$(rbenv init --no-rehash - zsh)"
  case $OSTYPE in
    darwin*)
      . "$(brew --cellar)/rbenv/$(brew list rbenv --versions | awk '{print $NF}')/completions/rbenv.zsh"
      ;;
    linux*)
      . $RBENV_ROOT/completions/rbenv.zsh
      ;;
  esac
fi

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
if [ -d $PYENV_ROOT ]; then
  path=(
        $PYENV_ROOT/bin(N-/)
        $path
        )
  eval "$(pyenv init --no-rehash - zsh)"
  . $PYENV_ROOT/completions/pyenv.zsh
  if type pip > /dev/null 2>&1; then
    eval "$(pip completion --zsh)"
  fi
  export WORKON_HOME="$HOME/.virtualenvs"
fi

# golang
# case $OSTYPE in
#   darwin*)
#     # export GOROOT="/usr/local/Cellar/go/1.9/libexec"
#     # export GOROOT="/usr/local/Cellar/go/1.9"
#     ;;
#   linux*)
#     export GOROOT="/usr/local/go"
#     ;;
# esac
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

# direnv
if type direnv > /dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# heroku
if type heroku > /dev/null 2>&1; then
  HEROKU_AC_ZSH_SETUP_PATH=/Users/ke-ichi/Library/Caches/heroku/autocomplete/zsh_setup && test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH;
fi
