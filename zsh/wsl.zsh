# https://zenn.dev/kaityo256/articles/open_command_on_wsl
function open() {
  if [ $# -eq 0 ]; then
    explorer.exe .
  elif [ $# -eq 1 -a -e $1 ]; then
    cmd.exe /c start $(wslpath -w $1) 2> /dev/null
  else
    echo "open: $1 : No such file or directory"
  fi
}
