zi wait lucid light-mode for \
  atinit"zicompinit; zicdreplay" \
  zdharma-continuum/fast-syntax-highlighting \
  marlonrichert/zsh-autocomplete

# rust
zi for \
  id-as"rust" \
  wait"0" \
  as"null" \
  lucid \
  rustup \
  sbin"bin/*" \
  atclone'rustup completions zsh > _rustup' \
  atload'[[ ! -f ${ZI[COMPLETIONS_DIR]}/_cargo ]] && zi creinstall rust' \
  atload'export CARGO_HOME=$PWD RUSTUP_HOME=$PWD/rustup' \
  z-shell/0
zi for \
  id-as'rust-sccache' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!sccache' \
  as"command" \
  pick"bin/sccache" \
  atload'export RUST_WRAPPER=$(which sccache)' \
  z-shell/0
zi for \
  id-as'rust-cargo-make' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!cargo-make' \
  as"command" \
  pick"bin/(cargo-make|makers)" \
  z-shell/0
zi for \
  id-as'rust-exa' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!exa' \
  as"command" \
  pick"bin/exa" \
  z-shell/0
zi for \
  id-as'rust-fd-find' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!fd-find' \
  as"command" \
  pick"bin/fd" \
  z-shell/0
zi for \
  id-as'rust-ripgrep' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!ripgrep' \
  as"command" \
  pick"bin/rg" \
  z-shell/0
zi for \
  id-as'rust-git-delta' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!git-delta' \
  as"command" \
  pick"bin/delta" \
  z-shell/0
zi for \
  id-as'rust-evcxr_repl' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!evcxr_repl' \
  as"command" \
  pick"bin/evcxr" \
  z-shell/0
zi for \
  id-as'rust-evcxr_jupyter' \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  cargo'!evcxr_jupyter' \
  as"command" \
  pick"bin/evcxr_jupyter" \
  z-shell/0

# CLI
zi from"gh-r" as"program" mv"direnv* -> direnv" pick"direnv" for \
  direnv/direnv
