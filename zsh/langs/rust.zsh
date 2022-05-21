export CARGO_ROOT="$HOME/.cargo"
if [ -d "$CARGO_ROOT" ]; then
  path=(
        $CARGO_ROOT/bin(N-/)
        $path
        )
fi
