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

fpath=(
       $BREW_PREFIX/share/zsh-completions(N-/)
       $fpath
       )

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

# asdf
ASDF_PATH=$BREW_PREFIX/opt/asdf
ASDF_ROOT=$HOME/.asdf
if [ -d "$ASDF_PATH" -a -d "$ASDF_PATH" ]; then
  source $ASDF_PATH/libexec/asdf.sh
  path=(
    $ASDF_ROOT/shims(N-/)
    $path
  )
  fpath=(
    ${ASDF_DIR}/completions(N-/)
    $fpath
  )
fi
