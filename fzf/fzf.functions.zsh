function cli-select-src() {
  local selected_dir=$(ghq list | fzf --reverse --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd $(ghq root)/${selected_dir}"
    zle accept-line
  fi
  zle redisplay
}
zle -N cli-select-src
bindkey '^@' cli-select-src

alias -g B='`git branch | fzf --reverse --ansi | sed -e "s/^\*[ ]*//g"`'

function cli-select-history() {
  BUFFER=$(fc -l -r -n 1 | fzf --reverse --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N cli-select-history
bindkey '^r' cli-select-history

function cli-find-file() {
  local source_files
  local selected_files
  echo -n 'searching...'
  # git managed
  if git rev-parse 2> /dev/null; then
    source_files=$(git ls-files)
  # default
  else
    source_files=$(find . -type f)
  fi
  selected_files=$(echo $source_files | fzf --reverse --prompt "[find file]:")

  BUFFER="${BUFFER}$(echo $selected_files | tr '\n' ' ')"
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N cli-find-file
bindkey '^q' cli-find-file

function cli-select-ps() {
  BUFFER=$(ps aux | fzf --reverse | awk '{print $2}')
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N cli-select-ps
bindkey '^^' cli-select-ps

function cli-select-tmux-session() {
  if [ -n "$TMUX" ]; then
    return
  fi

  local res=$(tmux list-sessions 2> /dev/null \
    | fzf --reverse --exit-0 --prompt "[select tmux session]:" \
    | awk -F':' '{print $1}')
  if [ -n "$res" ]; then
    tmux attach-session -t $res
  fi
}
cli-select-tmux-session

