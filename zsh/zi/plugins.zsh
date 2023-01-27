zi wait lucid light-mode for \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  zsh-users/zsh-syntax-highlighting

# zi wait lucid light-mode for \
#   at

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
