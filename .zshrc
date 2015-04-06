# Setting
setopt print_eight_bit
setopt prompt_subst
autoload -Uz colors; colors
setopt no_beep
setopt no_tify
setopt noflow_control

# history
HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=100000
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

# auto complete
autoload -Uz compinit; compinit
setopt correct
setopt auto_list
setopt auto_menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# cd
setopt auto_cd
alias ...='../..'
alias ....='../../..'
setopt auto_pushd

# vcs
autoload -Uz vcs_info
zstyle ":vcs_info:*" enable git svn
zstyle ":vcs_info:*" formats "(%s)-[%b]"
autoload -Uz is-at-least
if is-at-least 4.3.10; then
  ## git
  zstyle ":vcs_info:git:*" check-for-changes true
  # formats %c staged, %u unstaged
  zstyle ":vcs_info:git:*" stagedstr "%F{yellow}!"
  zstyle ":vcs_info:git:*" unstagedstr "%F{red}+"
  zstyle ":vcs_info:git:*" formats "%F{green}%S%c%u(%b)%f"
  zstyle ":vcs_info:git:*" actionformats "%F{red}%S [%a]%c%u(%b)%f"
  # zstyle ":vcs_info:git:*" formats "%F{green}%S (%b)%f"
  # zstyle ":vcs_info:git:*" actionformats "%S [%a](%b)"
fi

function vcs_prompt_info() {
  [[ -n "$vcs_info_msg_0_" ]] && echo -n " $vcs_info_msg_0_"
}


# prompt
PROMPT="%F{yellow}%n@%m%f:%F{green}%~%f"
PROMPT+="
"
PROMPT+="%# "
## right
RPROMPT=""
RPROMPT+="\$(vcs_prompt_info)"


# alias
## ls
alias -g ls='ls -F'
alias    ll='ls -l'
alias    la='ls -a'
alias    lh='ls -d .*'
alias    lla='ls -la'
alias    llh='ls -ld .*'
##
alias -g L=' | less'
alias -g G=' | grep'
alias    mkdir='mkdir -p'


# keybind
bindkey -e
## cursor
bindkey "^F" forward-char
bindkey "^B" backward-char
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
## delete
bindkey "^H" backward-delete-char
bindkey "^D" delete-char-or-list
bindkey "^W" backward-kill-word
bindkey "^K" kill-line
bindkey "^U" kill-whole-line
## history
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^S' history-incremental-pattern-search-forward
##
bindkey "^G" send-break
bindkey "^M" accept-line
bindkey "^L" clear-screen
bindkey "^Z" undo
bindkey "^[[Z" reverse-menu-complete


# pre
precmd () { vcs_info }