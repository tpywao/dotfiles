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
export LD_LIBRARY_PATH="/usr/local/lib:$OPENSSL_HOME/lib"
# export CPATH="-I$OPENSSL_HOME/include:$CPATH"
export LDFLAGS="-L$AVR_GCC_HOME/lib -L$OPENSSL_HOME/lib -L$LLVM_HOME/lib -L$ZLIB_HOME/lib -L$BZIP2_HOME/lib -L$BISON_HOME/lib $LDFLAGS"
export PKG_CONFIG_PATH="$OPENSSL_HOME/lib/pkgconfig:$ZLIB_HOME/lib/pkgconfig"


LANGS_ROOT=$ZDOTDIR/langs;
source $LANGS_ROOT/rust.zsh;
# source $LANGS_ROOT/ruby.zsh;
source $LANGS_ROOT/python.zsh;
# source $LANGS_ROOT/go.zsh;
# source $LANGS_ROOT/node.zsh;

# asdf
if [ -d "$ASDF_DIR" ]; then
  . $ASDF_DIR/asdf.sh
  fpath=(
    ${ASDF_DIR}/completions(N-/)
    $fpath
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
