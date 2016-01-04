# lang
export LANG=ja_JP.UTF-8

# path to .zshrc
export ZDOTDIR=$HOME/.dotfiles/.zsh

# gem
export GEM_HOME="$HOME/.gem"

# path
typeset -U path PATH cdpath fpath manpath
path=(
      # local
      $HOME/local/bin(N-/)
      $GEM_HOME/bin(N-/)
      /usr/local/bin(N-/)
      /usr/bin(N-/)
      /bin(N-/)
      $path
      )
fpath=(
       $ZDOTDIR/zsh-completions/src(N-/)
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
