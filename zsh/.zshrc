# Setting
setopt print_eight_bit
setopt prompt_subst
setopt no_tify
setopt noflow_control
# autoload
# -U unalias, -z type zsh
autoload -Uz colors; colors
autoload -Uz add-zsh-hook
autoload -Uz select-word-style
select-word-style bash

# zi
source $ZDOTDIR/zi/main.zsh

# direnv
if is_cmd_exists direnv; then
  eval "$(direnv hook zsh)"
fi

# local
path=(
  $LOCAL_ROOT/bin(N-/)
  $path
)

# programming languages
LANGS_ROOT=$ZDOTDIR/langs;
source $LANGS_ROOT/rust.zsh;
# source $LANGS_ROOT/ruby.zsh;
# source $LANGS_ROOT/python.zsh;
# source $LANGS_ROOT/go.zsh;
# source $LANGS_ROOT/node.zsh;


# history
HISTFILE=$HOME/.zsh_history
HISTSIZE=20000
SAVEHIST=100000
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_no_store

# auto complete
fpath=(
  $HOME/.completions(N-/)
  $fpath
)
source $ZDOTDIR/completion.zsh
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

source $ZDOTDIR/aliases.zsh

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
# https://github.com/zsh-users/zsh-autosuggestions/issues/678
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(history-beginning-search-backward-end history-beginning-search-forward-end)
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
# fzfのコマンドで上書きされるためコメントアウト
# bindkey "^R" history-incremental-pattern-search-backward
# bindkey "^S" history-incremental-pattern-search-forward
##
bindkey "^L" clear-screen

# hook
add-zsh-hook precmd vcs_info

# fzf
if is_cmd_exists fzf; then
  source $HOME/.fzf/fzf.functions.zsh
fi

# Google Cloud SDK
if is_cmd_exists gcloud; then
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
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/ogiso/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
