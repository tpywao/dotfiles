# zinit-annex-rustでインストールする
# export CARGO_ROOT="$HOME/.cargo"
if [[ -v RUSTUP_HOME && -v CARGO_HOME ]]; then
  # path=(
  #       $CARGO_ROOT/bin(N-/)
  #       $path
  #       )
  # ziでsccacheをインストールするときにRUST_WRAPPERを設定する
  # SCCACHE_PATH=$(which sccache)
  # echo sccache_path: $SCCACHE_PATH
  # if [ -f $SCCACHE_PATH ]; then
  #   export RUST_WRAPPER=$SCCACHE_PATH
  # fi
fi
