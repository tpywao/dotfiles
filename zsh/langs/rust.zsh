export CARGO_ROOT="$HOME/.cargo"
if [ -d "$CARGO_ROOT" ]; then
  path=(
        $CARGO_ROOT/bin(N-/)
        $path
        )
  SCCACHE_PATH=$(which sccache)
  if [ -f $SCCACHE_PATH ]; then
    export RUST_WRAPPER=$SCCACHE_PATH
  fi
fi
