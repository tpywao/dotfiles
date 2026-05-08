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

# zsh-abbr
ABBR_USER_ABBREVIATIONS_FILE=$ZDOTDIR/abbr.zsh

# sheldon
if is_cmd_exists sheldon; then
  echo "sheldon: loading plugins..."
  # ".autocomplete:async:wait:N: write error: bad file descriptor" が頻発する場合に有効化
  # zstyle ':autocomplete:*' async false
  eval "$(sheldon source)"
fi

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


# history
HISTFILE=$HOME/.zsh_history
HISTSIZE=20000
SAVEHIST=100000
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_no_store
setopt share_history
setopt extended_history

# auto complete
fpath=(
  $HOME/.completions(N-/)
  $fpath
)
setopt correct
setopt no_beep
setopt auto_list
setopt auto_menu
setopt magic_equal_subst
setopt extendedglob
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# cd
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

# hook
add-zsh-hook precmd vcs_info

# fzf
if is_cmd_exists fzf; then
  source $HOME/.fzf/fzf.functions.zsh
fi

# zoxide
if is_cmd_exists zoxide; then
  eval "$(zoxide init zsh)"
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

# Docker
fpath=(/Users/ogiso/.docker/completions $fpath)

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/keybinds.zsh
source $ZDOTDIR/check.zsh
