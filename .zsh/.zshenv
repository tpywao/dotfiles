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
      /bin(N-/)
      /usr/bin(N-/)
      /usr/local/bin(N-/)
      $path
      )
fpath=(
       $ZDOTDIR/zsh-completions/src(N-/)
       $fpath
       )

# rbenv
if [ -d $HOME/.rbenv ]; then
  path=(
        $HOME/.rbenv/bin(N-/)
        $path
        )
  eval "$(rbenv init --no-rehash - zsh)"
  . $HOME/.rbenv/completions/rbenv.zsh
fi
