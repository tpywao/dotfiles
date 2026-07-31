# HOMEBREW_PREFIX は brew shellenv 自身が export するので、
# 設定済みならネストしたシェルでは brew の外部プロセス起動を省略できる
if [[ -z $HOMEBREW_PREFIX && -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Homebrew (cask管理のために維持)
if is_cmd_exists brew; then
  BREW_PREFIX=$(brew --prefix)
  fpath=(
    $BREW_PREFIX/share/zsh/site-functions(N-/)
    $fpath
  )
fi

# iterm2
# https://iterm2.com/documentation-shell-integration.html
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" || true
