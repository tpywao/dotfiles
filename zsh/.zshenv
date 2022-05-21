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
       $fpath
       )

case $OSTYPE in
  darwin*)
    source $ZDOTDIR/darwin.zsh
    ;;
  linux*)
    ;;
esac

LANGS_ROOT=$ZDOTDIR/langs;
source $LANGS_ROOT/rust.zsh;
# source $LANGS_ROOT/ruby.zsh;
# source $LANGS_ROOT/python.zsh;
# source $LANGS_ROOT/go.zsh;
# source $LANGS_ROOT/node.zsh;

# direnv
if type direnv > /dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Android Studio
export ANDROID_SDK_HOME=/Volumes/extssd/Android
export ANDROID_SDK_ROOT=/Volumes/extssd/Android/sdk
export ANDROID_EMULATOR_HOME=/Volumes/extssd/Android/Emulator
export ANDROID_AVD_HOME=/Volumes/extssd/Android/Emulator/avd
