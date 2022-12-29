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
source $ZDOTDIR/compinit.zsh
setopt correct
setopt no_beep
setopt auto_list
setopt auto_menu
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# pipenv
# # .zshenv に書いても動かないが...こっちに書くとなぜかちゃんと動く...
# if type pipenv > /dev/null 2>&1; then
#   export PIPENV_VENV_IN_PROJECT=true
#   # pipenv --completion
#   _pipenv() {
#     eval $(env COMMANDLINE="${words[1,$CURRENT]}" _PIPENV_COMPLETE=complete-zsh  pipenv)
#   }
#   compdef _pipenv pipenv
#   export PIPENV_VENV_IN_PROJECT=true
# fi

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
  # for git aliased by github/hub
  # zstyle ":vcs_info:git:*" command =git
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
PROMPT+="%F{blue}[%~]%f"
PROMPT+="
"
PROMPT+="%# "
## right
# commented because: https://github.com/Guake/guake/issues/823
# RPROMPT="[%~]"

# alias
## ls
alias ls='ls -F'
alias ll='ls -l'
alias la='ls -a'
alias lh='ls -d .*'
alias lla='ls -la'
alias llh='ls -ld .*'
##
alias vi=vim
alias less='less -R'
alias screen='screen -U'
alias mkdir='mkdir -p'
function mkcd () {
  mkdir "$@" && cd $_
}
function cd () {
  # avoid `not a directory`
  # FIXME: directory name starts with `-`
  local a args=() dir=()

  for a in $@; do
    if [ ${#a} -ne 1 -a "${a:0:1}" = "-" ]; then
      args+=($a)
      continue
    fi

    if ! [ -d $a ]; then
      # 末尾から後方最短一致
      a=${a%/*}
    fi
    dir+=($a)
  done

  # echo $args -- $dir
  builtin cd $args -- $dir
}
# type hub >/dev/null 2>&1  && eval "$(hub alias -s)"

if is_wsl; then
  # https://zenn.dev/kondounagi/scraps/184c884b5804a4
  alias pbcopy="clip.exe"
  alias pbpaste="powershell.exe -Command Get-Clipboard"
elif is_linux; then
  alias pbcopy="xsel --clipboard --input"
  alias pbpaste="xsel --clipboard --output"
fi

## global
alias -g L=' | less'
alias -g G=' | grep'
alias -g TF=' && echo t || echo f'
alias -g F=' | fzf --reverse --select-1 --exit-0'
alias -g C=' | pbcopy'
alias -g CC=' | (v=$(cat); echo -n $v) | pbcopy'

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

# fzf
if [ -d $HOME/.fzf ]; then
  [ -f $HOME/.fzf/.fzf.zsh ] && source $HOME/.fzf/.fzf.zsh
  [ -f $HOME/.fzf/fzf.functions.zsh ] && source $HOME/.fzf/fzf.functions.zsh
fi

# Google Cloud SDK
if type gcloud > /dev/null 2>&1; then
  GOOGLE_CLOUD_SDK_ROOT=$(gcloud info --format='value(installation.sdk_root)')
  # The next line updates PATH for the Google Cloud SDK.
  GOOGLE_CLOUD_SDK_PATH=$GOOGLE_CLOUD_SDK_ROOT/path.zsh.inc
  if [ -f "$GOOGLE_CLOUD_SDK_PATH" ]; then
    source "$GOOGLE_CLOUD_SDK_PATH"
  fi

  # The next line enables shell command completion for gcloud.
  GOOGLE_CLOUD_SDK_COMPLETION=$GOOGLE_CLOUD_SDK_ROOT/completion.zsh.inc
  if [ -f "$GOOGLE_CLOUD_SDK_COMPLETION" ]; then
    source "$GOOGLE_CLOUD_SDK_COMPLETION"
  fi
fi

# zinit
source $ZDOTDIR/zinit.zsh
