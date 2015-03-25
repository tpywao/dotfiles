# history setting
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
HISTIGNORE='ls:ll:la:lla:cls:fg:fg :bg:bg :srcbash:man :irb'

# alias setting
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# local setting
export PATH="$HOME/local/bin:$PATH"

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
function proml {
  PS1="\[\e[0;32m\]\u@\h\[\e[m\]:\[\e[0;33m\]\W\[\e[0;31m\]\$(parse_git_branch)\[\e[m\]\$ "
}
proml

export PROMPT_COMMAND='echo -ne "\033]0;${USERNAME}@${HOSTNAME}: ${PWD}\007"'

