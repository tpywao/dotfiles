# utils
string_contain() {
  [ -z "$1" ] || {
    [ -z "${1##*$2*}" ] && [ -n "$1" ]
  }
}
is_cmd_exists() {
  type $1 > /dev/null 2>&1
}

# os
is_wsl() {
  [ -n "$(which wslpath)" ]
}
is_mac() {
  string_contain $OSTYPE darwin
}
is_linux() {
  string_contain $OSTYPE linux
}
