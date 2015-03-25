alias ls='ls -F'
alias ll='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lh='ls -d .*'
alias llh='ls -ld .*'

if [ -f $HOME/local/bin/vim ]; then
  alias vi='$HOME/local/bin/vim'
fi

alias srcbash='source ~/.bashrc'
alias psgrep='ps aux | grep'
alias hist='history | tail -10'
alias histgrep='history | grep'

