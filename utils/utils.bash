#!/bin/bash
string_contain() {
  string=$1
  pattern=$2
  # -z 空文字
  [ -z "$string" ] || {
    # ${target##*}
    [ -z "${string##*$pattern*}" ] && [ -n "$string" ]
  }
}
is_cmd_exists() {
  command -v $1 >/dev/null 2>&1
}

# os
is_wsl() {
  is_cmd_exists wslpath
}
is_mac() {
  string_contain $OSTYPE darwin
}
is_linux() {
  string_contain $OSTYPE linux
}
