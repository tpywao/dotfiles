# lang
export LANG=ja_JP.UTF-8

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

# use brew formula(ex. keg-only)
HOMEBREW_NO_INSTALL_CLEANUP=1
BREW_PREFIX=$(brew --prefix)
AVR_GCC_HOME=$BREW_PREFIX/opt/avr-gcc@8
LLVM_HOME=$BREW_PREFIX/opt/llvm
OPENSSL_HOME=$BREW_PREFIX/opt/openssl
ZLIB_HOME=$BREW_PREFIX/opt/zlib
BZIP2_HOME=$BREW_PREFIX/opt/bzip2
BISON_HOME=$BREW_PREFIX/opt/bison
# POSTGRES12_HOME=$BREW_PREFIX/opt/postgresql@12

path=(
      $BREW_PREFIX/opt/mysql@5.7/bin(N-/)
      $BREW_PREFIX/opt/mysql-client/bin(N-/)
      # $POSTGRES12_HOME/bin(N-/)
      $OPENSSL_HOME/bin(N-/)
      $BZIP2_HOME/bin(N-/)
      $BISON_HOME/bin(N-/)
      $path
      )
# export CFLAGS="-I/usr/local/include -L/usr/local/lib -I$(xcrun --show-sdk-path)/usr/include $CFLAGS"
export CFLAGS="-I/usr/local/include -L/usr/local/lib -I$OPENSSL_HOME/include $CFLAGS"
export CPPFLAGS="-I$OPENSSL_HOME/include -I$LLVM_HOME/include -I$ZLIB_HOME/include -I$BZIP2_HOME/include $CPPFLAGS"
export LIBRARY_PATH="/usr/local/lib:$OPENSSL_HOME/lib"
# export LD_LIBRARY_PATH="/usr/local/lib:$OPENSSL_HOME/lib"
# export CPATH="-I$OPENSSL_HOME/include:$CPATH"
export LDFLAGS="-L$AVR_GCC_HOME/lib -L$OPENSSL_HOME/lib -L$LLVM_HOME/lib -L$ZLIB_HOME/lib -L$BZIP2_HOME/lib -L$BISON_HOME/lib $LDFLAGS"
export PKG_CONFIG_PATH="$OPENSSL_HOME/lib/pkgconfig:$ZLIB_HOME/lib/pkgconfig"


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
  eval "$(pyenv init --path)"
  eval "$(pyenv init --no-rehash -)"
  PYENV_INSTALLED_DIR=$(brew --prefix pyenv)
  . $PYENV_INSTALLED_DIR/completions/pyenv.zsh
  # . $PYENV_ROOT/completions/pyenv.zsh
  if type pip > /dev/null 2>&1; then
    eval "$(pip completion --zsh)"
  fi
  export WORKON_HOME="$HOME/.virtualenvs"
  # export CLOUDSDK_PYTHON=~/.pyenv/shims/python3
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
