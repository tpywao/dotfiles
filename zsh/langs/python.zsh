export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  path=(
        $PYENV_ROOT/bin(N-/)
        $PYENV_ROOT/shims(N-/)
        $path
        )

  pyenv () {
    unfunction "$0"
    source <$(pyenv init --no-rehash -)
    PYENV_INSTALLED_DIR=$(brew --prefix pyenv)
    source $PYENV_INSTALLED_DIR/completions/pyenv.zsh
    # . $PYENV_ROOT/completions/pyenv.zsh
    if type pip > /dev/null 2>&1; then
      source <$(pip completion --zsh)
    fi
    $0 "$@"
  }
  # export CLOUDSDK_PYTHON=~/.pyenv/shims/python3
fi
