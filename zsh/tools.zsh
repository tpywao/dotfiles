# WIP
# install tools

# CLI tools
# exa
# bat
# fzf
# gh

# GUI tools
# raycast
# rectangle
# alacritty or warp

if is_mac; then
  if !is_cmd_exists brew; then
    echo 'need `brew`' 1>&2
    echo https://docs.brew.sh/Installation
    exit 1
  fi
  brew install exa bat fzf gh
  brew install --cask raycast rectangle
elif is_wsl; then
elif is_linux; then
fi
