# for multi account?
if [ -d "${HOME}/homebrew" ]; then
  eval "$(~/homebrew/bin/brew shellenv)"
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
