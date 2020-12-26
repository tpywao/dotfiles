# lang
export LANG=ja_JP.UTF-8

# build
export CFLAGS="-I$(xcrun --show-sdk-path)/usr/include -I/usr/local/include -L/usr/local/lib $CFLAGS"

# local
LOCAL_ROOT=$HOME/local
export EDITOR=vim
# golang etc.
export REPOSITORIES_HOME="$LOCAL_ROOT/src/repositories"
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
       /usr/local/share/zsh-completions(N-/)
       $fpath
       )

# use brew keg-only formula
BREW_PREFIX=$(brew --prefix)
OPENSSL_HOME=$BREW_PREFIX/opt/openssl
path=(
      $BREW_PREFIX/opt/mysql@5.7/bin(N-/)
      $BREW_PREFIX/opt/mysql-client/bin(N-/)
      $OPENSSL_HOME/bin(N-/)
      $path
      )
export LIBRARY_PATH="$OPENSSL_HOME/lib:$LIBRARY_PATH"
export LD_LIBRARY_PATH="$OPENSSL_HOME/lib:$LD_LIBRARY_PATH"
export CPATH="-I$OPENSSL_HOME/include:$CPATH"
export LDFLAGS="-I$OPENSSL_HOME/include -L$OPENSSL_HOME/lib $LDFLAGS"
export CPPFLAGS="-I$OPENSSL_HOME/include $CPPFLAGS"
export PKG_CONFIG_PATH="$OPENSSL_HOME/lib/pkgconfig:$PKG_CONFIG_PATH"


# rust
export CARGO_ROOT="$HOME/.cargo"
if [ -d "$CARGO_ROOT" ]; then
  path=(
        $CARGO_ROOT/bin(N-/)
        $path
        )
fi

# rbenv
# export RBENV_ROOT="$HOME/.rbenv"
if [ -d "$RBENV_ROOT" ]; then
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
if [ -d "$PYENV_ROOT" ]; then
  path=(
        $PYENV_ROOT/bin(N-/)
        $path
        )
  eval "$(pyenv init --no-rehash - zsh)"
  PYENV_INSTALLED_DIR=$(brew --prefix pyenv)
  . $PYENV_INSTALLED_DIR/completions/pyenv.zsh
  # . $PYENV_ROOT/completions/pyenv.zsh
  if type pip > /dev/null 2>&1; then
    eval "$(pip completion --zsh)"
  fi
  export WORKON_HOME="$HOME/.virtualenvs"
  export CLOUDSDK_PYTHON=~/.pyenv/shims/python2
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
# if [ -d "$GOROOT" ] && [ -d "$GOPATH" ]; then
export GOPATH_PACKAGES="$HOME/go/packages"
export GOPATH_WORKSPACE="$HOME/go/workspace"
export GOPATH=$GOPATH_PACKAGES:$GOPATH_WORKSPACE
if [ -d "$GOPATH_PACKAGES" -a -d "$GOPATH_WORKSPACE" ]; then
  path=(
        $GOPATH_PACKAGES/bin(N-/)
        $GOPATH_WORKSPACE/bin(N-/)
        $BREW_PREFIX/libexec(N-/)
        $path
        )
  export GO15VENDOREXPERIMENT=1
  export PROJECT_HOME=$REPOSITORIES_HOME
fi

# nodebrew
# https://github.com/hokaccha/nodebrew
# export NODEBREW_ROOT="$HOME/.nodebrew"
if [ -d "$NODEBREW_ROOT" ]; then
  path=(
        $NODEBREW_ROOT/current/bin(N-/)
        $path
        )
fi

# direnv
if type direnv > /dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Android Studio
export ANDROID_SDK_HOME=/Volumes/extssd/Android
export ANDROID_SDK_ROOT=/Volumes/extssd/Android/sdk
export ANDROID_EMULATOR_HOME=/Volumes/extssd/Android/Emulator
export ANDROID_AVD_HOME=/Volumes/extssd/Android/Emulator/avd
