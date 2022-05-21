export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  path=(
        $PYENV_ROOT/bin(N-/)
        $PYENV_ROOT/shims(N-/)
        $path
        )
  eval "`pip completion --zsh`"

  pyenv () {
    unfunction "$0"
    source <$(pyenv init --no-rehash -)
    source $PYENV_ROOT/completions/pyenv.zsh
    $0 "$@"
  }
  # export CLOUDSDK_PYTHON=~/.pyenv/shims/python3
fi
