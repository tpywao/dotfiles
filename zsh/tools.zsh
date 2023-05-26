# WIP
# install tools

# CLI tools
# bat
# fzf
# gh

# GUI tools
# raycast
# rectangle
# alacritty or warp

# bitwardenはsafariに拡張機能を設定したい場合、app store経由でインストールする必要がある
# https://bitwarden.com/help/install-safari-app-extension/

if is_mac; then
  if !is_cmd_exists brew; then
    echo 'need `brew`' 1>&2
    echo https://docs.brew.sh/Installation
    exit 1
  fi
  brew install bat fzf gh
  brew install --cask raycast rectangle
elif is_wsl; then
elif is_linux; then
fi
