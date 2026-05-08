_dotfiles_check() {
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  local cache_file="$cache_dir/dotfiles-check-date"
  local today
  today=$(date +%Y-%m-%d)
  [[ -f "$cache_file" && "$(< "$cache_file")" == "$today" ]] && return

  local dotfiles="$HOME/.dotfiles"
  local updates=()

  # nix: flake.lock が home-manager profile より新しければ switch が必要
  local hm_profile="/nix/var/nix/profiles/per-user/$USER/home-manager"
  if [[ -f "$dotfiles/flake.lock" && -e "$hm_profile" ]]; then
    zmodload zsh/stat
    local flake_mtime hm_mtime
    flake_mtime=$(stat -f %m "$dotfiles/flake.lock")
    hm_mtime=$(zstat -L +mtime "$hm_profile" 2>/dev/null)
    if [[ -n "$hm_mtime" ]] && (( flake_mtime > hm_mtime )); then
      updates+=('nix     → nix run home-manager -- switch --flake "$HOME/.dotfiles#$(whoami)" --impure --no-update-lock-file')
    fi
  fi

  # sheldon: plugins.toml が plugins.lock より新しければ lock が必要
  local plugins_toml="$dotfiles/sheldon/plugins.toml"
  local plugins_lock="$HOME/.local/share/sheldon/plugins.lock"
  if [[ -f "$plugins_toml" && -f "$plugins_lock" && "$plugins_toml" -nt "$plugins_lock" ]]; then
    updates+=("sheldon → sheldon lock --update")
  fi

  # brew: Brewfile に未インストールのパッケージがあれば bundle install が必要
  if [[ -f "$dotfiles/Brewfile" ]] && (( $+commands[brew] )); then
    if ! brew bundle check --file="$dotfiles/Brewfile" --no-upgrade &>/dev/null; then
      updates+=("brew    → brew bundle install --file=$dotfiles/Brewfile")
    fi
  fi

  if (( ${#updates[@]} > 0 )); then
    print -P "%F{yellow}[dotfiles] 更新が必要:%f"
    for u in "${updates[@]}"; do
      print -P "  %F{cyan}$u%f"
    done
  fi

  mkdir -p "$cache_dir"
  print "$today" > "$cache_file"
}

_dotfiles_check
