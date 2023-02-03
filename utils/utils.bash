#!/bin/bash
string_contain() {
  [ -z "$1" ] || {
    [ -z "${1##*$2*}" ] && [ -n "$1" ]
  }
}
is_cmd_exists() {
  command -v $1 > /dev/null 2>&1
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
