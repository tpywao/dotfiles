is_wsl() {
  [ -n "$(which wslpath)" ]
}

is_mac() {
  stringContain $OSTYPE darwin
}

is_linux() {
  stringContain $OSTYPE linux
}
