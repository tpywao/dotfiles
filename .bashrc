# history setting
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
HISTIGNORE='ls:ll:la:lla:cls:fg:fg :bg:bg :srcbash:man :irb'

# alias setting
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
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

function parse_git_branch {
  git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
function precmd() {
  PROMPT="\u@\h:\W\$(parse_git_branch) \$ "
}
PS1="\[\e[0;33m\]\u@\h\[\e[00m\]:\[\e[0;32m\]\W\[\e[0;31m\]\$(parse_git_branch)\[\e[00m\]\$ "
