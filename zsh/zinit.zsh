### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

path=(
      $ZPFX/bin(N-/)
      $path
      )

# plugins
zi wait lucid light-mode for \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# rust
zi for \
  id-as"rust" \
  wait"0" \
  as"null" \
  lucid \
  rustup \
  sbin"bin/*" \
  atload'[[ ! -f ${ZINIT[COMPLETIONS_DIR]}/_rustup ]] && rustup completions zsh > ${ZINIT[COMPLETIONS_DIR]}/_rustup' \
  atload'[[ ! -f ${ZINIT[COMPLETIONS_DIR]}/_cargo ]] && zi creinstall rust' \
  atload'export CARGO_HOME=$PWD RUSTUP_HOME=$PWD/rustup' \
    zdharma-continuum/null
zi for \
  wait='[[ -v CARGO_HOME && -v RUSTUP_HOME ]]' \
  lucid \
  id-as'rust-cargo-make' \
  cargo'!cargo-make' \
    zdharma-continuum/null

# completions
zi wait lucid as"completion" blockf light-mode for \
  https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker \
  https://github.com/sagiegurari/cargo-make/raw/master/extra/shell/makers-completion.bash
zi wait lucid as"completion" blockf light-mode for \
    zsh-users/zsh-completions
# なんかうまく動かん
# zi as-id"_git_bash" wait silent atclone"zstyle ':completion:*:*:git:*' script git-completion.bash" atpull"%atclone" for \
#    https://raw.github.com/git/git/master/contrib/completion/git-completion.bash
# zi as-id"_git" wait lucid as"completion" blockf mv"git-completion.zsh -> _git" pick"_git" for \
#   https://raw.github.com/git/git/master/contrib/completion/git-completion.zsh
