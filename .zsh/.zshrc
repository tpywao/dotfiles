# Setting
# autoload
# -U unalias, -z type zsh
autoload -Uz colors; colors
autoload -Uz add-zsh-hook
setopt print_eight_bit
setopt prompt_subst
setopt no_tify
setopt noflow_control

# history
HISTFILE=$HOME/.zsh_history
HISTSIZE=20000
SAVEHIST=100000
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_no_store

# auto complete
autoload -Uz compinit; compinit
setopt correct
setopt no_beep
setopt auto_list
setopt auto_menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# cd
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups

# vcs
autoload -Uz vcs_info
zstyle ":vcs_info:*" enable git svn
zstyle ":vcs_info:*" formats "(%s)-[%b]"
autoload -Uz is-at-least
if is-at-least 4.3.10; then
  ## git
  zstyle ":vcs_info:git:*" check-for-changes true
  # formats %c staged, %u unstaged
  zstyle ":vcs_info:git:*" stagedstr "%F{yellow}+"
  zstyle ":vcs_info:git:*" unstagedstr "%F{magenta}-"
  zstyle ":vcs_info:git:*" formats "%F{green}(%b%f%c%u%F{green})[%S/]%f"
  zstyle ":vcs_info:git:*" actionformats "%F{red}[%a](%b%f%c%u%f%F{red})[%S/]%f"
  # zstyle ":vcs_info:git:*" formats "%F{green}(%b)[%S/]%f"
  # zstyle ":vcs_info:git:*" actionformats "%F{red}[%a](%b)[%S/]%f"
fi

function vcs_prompt_info() {
  [[ -n "$vcs_info_msg_0_" ]] && echo -n " $vcs_info_msg_0_"
}


# prompt
function remote_host_name_color() {
  [[ -n $SSH_TTY ]] && echo -n "%f%F{cyan}"
}
## default
PROMPT="%F{yellow}%n@"
PROMPT+="\$(remote_host_name_color)%m%f"
PROMPT+="\$(vcs_prompt_info)"
PROMPT+="
"
PROMPT+="%# "
## right
RPROMPT="[%~]"
# RPROMPT+="\$(vcs_prompt_info)"


# alias
## ls
alias ls='ls -F'
alias ll='ls -l'
alias la='ls -a'
alias lh='ls -d .*'
alias lla='ls -la'
alias llh='ls -ld .*'
##
alias vi='vim'
alias srczsh="exec $SHELL"
alias mkdir='mkdir -p'
## global
alias -g L=' | less'
alias -g G=' | grep'


# keybind
bindkey -e
# ^ ctrl, ^[ alt, ^[[Z shift+tab
## cursor
bindkey "^F" forward-char
bindkey "^B" backward-char
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^[f" forward-word
bindkey "^[b" backward-word
## delete
bindkey "^H" backward-delete-char
bindkey "^D" delete-char-or-list
bindkey "^W" backward-kill-word
bindkey "^K" kill-line
bindkey "^U" kill-whole-line
## input
bindkey "^M" accept-line
bindkey "^Y" yank
bindkey "^Z" undo
bindkey "^[[Z" reverse-menu-complete
## history
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
bindkey "^R" history-incremental-pattern-search-backward
bindkey "^S" history-incremental-pattern-search-forward
##
bindkey "^L" clear-screen

# hook
add-zsh-hook precmd vcs_info
