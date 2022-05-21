export RBENV_ROOT="$HOME/.rbenv"
if [ -d "$RBENV_ROOT" ]; then
  path=(
        $RBENV_ROOT/bin(N-/)
        $path
        )
  eval "$(rbenv init --no-rehash - zsh)"
  case $OSTYPE in
    darwin*)
      . "$(brew --cellar)/rbenv/$(brew list rbenv --versions | awk '{print $NF}')/completions/rbenv.zsh"
      ;;
    linux*)
      . $RBENV_ROOT/completions/rbenv.zsh
      ;;
  esac
fi
