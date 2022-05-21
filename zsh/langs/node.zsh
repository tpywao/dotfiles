export NODEBREW_ROOT="$HOME/.nodebrew"
if [ -d "$NODEBREW_ROOT" ]; then
  path=(
        $NODEBREW_ROOT/current/bin(N-/)
        $path
        )
fi
