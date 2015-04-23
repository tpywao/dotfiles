# lang
export LANG=ja_JP.UTF-8

# path to .zshrc
export ZDOTDIR=$HOME/.dotfiles/.zsh

# gem
export GEM_HOME="$HOME/.gem"

# path
typeset -U path cdpath fpath manpath
path=(
      /bin(N-/)
      /usr/bin(N-/)
      /usr/local/bin(N-/)
      $path
      # local
      $HOME/local/bin(N-/)
      $GEM_HOME/bin(N-/)
      )
fpath=(
       $ZDOTDIR/zsh-completions/src(N-/)
       $fpath
       )

# rbenv
if [ -d $HOME/.rbenv ]; then
  path=(
        $path
        $HOME/.rbenv/bin(N-/)
        )
  eval "$(rbenv init --no-rehash - zsh)"
fi
