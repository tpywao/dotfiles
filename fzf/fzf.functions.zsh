function fzf-select-src() {
  local repo=$(ghq list | fzf --reverse --query "$LBUFFER")
  if [ -n "$repo" ]; then
    # `ghq look` は新規シェルを開くため、遅いので使わない
    for ghq_root in $(ghq root --all); do
      local dir="${ghq_root}/${repo}"
      if [ -d $dir ]; then
        BUFFER="cd ${dir}"
        zle accept-line
      fi
    done
  fi
  zle redisplay
}
zle -N fzf-select-src

alias -g B='`git branch | fzf --reverse --ansi | sed -e "s/^\*[ ]*//g"`'

function fzf-select-history() {
  BUFFER=$(fc -l -r -n 1 | fzf --reverse --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N fzf-select-history

function fzf-find-file() {
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
zle -N fzf-find-file

function fzf-select-abbr() {
  local selected key
  # abbr list は `"key"="expansion"` 形式。一覧で展開後も見えるので略語を忘れたとき思い出せる
  selected=$(abbr list | fzf --reverse --query "$LBUFFER" --prompt "[abbr]: ") || return
  # キーは "dc" のようにクォートされるので外してから expand に渡す
  key="${selected%%=*}"
  key="${key//\"/}"
  if [ -n "$key" ]; then
    # 値の parse はせず abbr expand に任せる（クォートやネストも正確に展開される）
    BUFFER="$(abbr expand "$key")"
    CURSOR=$#BUFFER
  fi
  zle redisplay
}
zle -N fzf-select-abbr

function fzf-select-ps() {
  BUFFER=$(ps aux | fzf --reverse | awk '{print $2}')
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N fzf-select-ps

function fzf-select-tmux-session() {
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
# fzf-select-tmux-session
