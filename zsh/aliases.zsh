# ls
if is_cmd_exists exa; then
  alias ls='exa -F'
else
  alias ls='ls -F'
fi
alias ll='ls -l'
alias la='ls -a'
alias lh='ls -d .*'
alias lla='ls -la'
alias llh='ls -ld .*'
# variables
if is_cmd_exists bat; then
  alias less='bat'
else
  alias less='less -R'
fi
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

if is_wsl; then
  # https://zenn.dev/kondounagi/scraps/184c884b5804a4
  alias pbcopy="clip.exe"
  alias pbpaste="powershell.exe -Command Get-Clipboard"
elif is_linux; then
  alias pbcopy="xsel --clipboard --input"
  alias pbpaste="xsel --clipboard --output"
fi

# global
alias -g L=' | less'
alias -g G=' | grep'
alias -g TF=' && echo t || echo f'
alias -g F=' | fzf --reverse --select-1 --exit-0'
alias -g C=' | pbcopy'
alias -g CC=' | (v=$(cat); echo -n $v) | pbcopy'
