#!/bin/bash
string_contain() {
  string=$1
  pattern=$2
  # -z 文字列長が 0 ならば真
  [ -z "$string" ] || {
    # 前方最長一致除去
    # 文字列長が 1 以上ならば真
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
