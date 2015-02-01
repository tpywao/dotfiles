# history setting
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
HISTIGNORE='ls:ll:la:lla:cls:fg:fg :bg:bg :srcbash:man :irb'

# alias setting
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_git ]; then
    . ~/.bash_git
fi

# rbenv setting
if [ -d ~/.rbenv ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init --no-rehash -)"
fi

# gem setting
export GEM_HOME="$HOME/.gem"
export PATH="$GEM_HOME/bin:$PATH"

# qt setting
export QT_SELECT=4


