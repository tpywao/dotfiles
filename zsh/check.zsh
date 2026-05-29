_dotfiles_days_since() {
  local f="$1"
  [[ ! -f "$f" ]] && { echo 999; return; }
  local epoch
  epoch=$(date -j -f "%Y-%m-%d" "$(< "$f")" "+%s" 2>/dev/null)
  [[ -z "$epoch" ]] && { echo 999; return; }
  echo $(( ($(date +%s) - epoch) / 86400 ))
}

_dotfiles_check_sheldon_weekly() {
  local cache_dir="$1" today="$2"
  local weekly_file="$cache_dir/sheldon-update-date"
  local plugins_lock="$HOME/.local/share/sheldon/plugins.lock"

  (( $+commands[sheldon] )) || return
  (( $(_dotfiles_days_since "$weekly_file") >= 7 )) || return

  print -Pn "%F{blue}[dotfiles] sheldon: アップデートチェック中...%f"

  local lock_before lock_after
  [[ -f "$plugins_lock" ]] && lock_before=$(md5 -q "$plugins_lock" 2>/dev/null)
  if ! sheldon lock --update &>/dev/null; then
    print -Pn "\r\033[K"
    return
  fi

  [[ -f "$plugins_lock" ]] && lock_after=$(md5 -q "$plugins_lock" 2>/dev/null)
  print "$today" > "$weekly_file"
  print -Pn "\r\033[K"
  [[ "$lock_before" != "$lock_after" ]] || return

  print -P "%F{yellow}[dotfiles] sheldon プラグインが更新されました。exec zsh で反映できます%f"
}

_dotfiles_check_brew_weekly() {
  local cache_dir="$1" today="$2"
  local weekly_file="$cache_dir/brew-update-date"

  (( $+commands[brew] )) || return
  (( $(_dotfiles_days_since "$weekly_file") >= 7 )) || return

  print -Pn "%F{blue}[dotfiles] brew: アップデートチェック中...%f"

  if ! brew update --quiet &>/dev/null; then
    print -Pn "\r\033[K"
    return
  fi

  local outdated
  outdated=$(brew outdated --quiet 2>/dev/null)
  print "$today" > "$weekly_file"
  print -Pn "\r\033[K"
  [[ -n "$outdated" ]] || return

  print -P "%F{yellow}[dotfiles] brew に更新があります: brew upgrade%f"
  while IFS= read -r pkg; do
    print -P "  %F{cyan}$pkg%f"
  done <<< "$outdated"
}

_dotfiles_check_nix_daily() {
  local dotfiles="$1"
  local flake_lock="$dotfiles/flake.lock"
  local hm_profile="/nix/var/nix/profiles/per-user/$USER/home-manager"

  [[ -f "$flake_lock" && -e "$hm_profile" ]] || return

  zmodload zsh/stat
  local flake_mtime hm_mtime
  flake_mtime=$(stat -f %m "$flake_lock")
  hm_mtime=$(zstat -L +mtime "$hm_profile" 2>/dev/null)
  [[ -n "$hm_mtime" ]] && (( flake_mtime > hm_mtime )) || return

  echo 'nix     → nix run home-manager -- switch --flake "$DOTFILES#$(whoami)" --impure --no-update-lock-file'
}

_dotfiles_check_nix_upstream_daily() {
  local dotfiles="$1"
  local flake_lock="$dotfiles/flake.lock"

  [[ -f "$flake_lock" ]] || return
  (( $+commands[jq] && $+commands[git] )) || return

  local has_update=0
  local name owner repo ref locked remote url
  while IFS=$'\t' read -r name owner repo ref locked; do
    [[ -n "$owner" && -n "$repo" && -n "$locked" ]] || continue
    url="https://github.com/$owner/$repo.git"
    remote=$(GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=5 \
      git ls-remote "$url" "${ref:-HEAD}" 2>/dev/null | awk 'NR==1{print $1}')
    [[ -n "$remote" ]] || continue
    [[ "$remote" != "$locked" ]] && has_update=1
  done < <(jq -r '.nodes | to_entries[] | .value.locked as $l | select($l.type=="github") | [.key, $l.owner, $l.repo, (.value.original.ref // ""), $l.rev] | @tsv' "$flake_lock")

  (( has_update )) && echo "nix     → nix flake update  (上流に新しいコミットあり)"
}

_dotfiles_check_sheldon_daily() {
  local dotfiles="$1"
  local plugins_toml="$dotfiles/sheldon/plugins.toml"
  local plugins_lock="$HOME/.local/share/sheldon/plugins.lock"

  [[ -f "$plugins_toml" && -f "$plugins_lock" && "$plugins_toml" -nt "$plugins_lock" ]] || return

  echo "sheldon → sheldon lock --update"
}

_dotfiles_check_brew_daily() {
  local dotfiles="$1"

  [[ -f "$dotfiles/Brewfile" ]] && (( $+commands[brew] )) || return
  brew bundle check --file="$dotfiles/Brewfile" --no-upgrade &>/dev/null && return

  echo "brew    → brew bundle install --file=$dotfiles/Brewfile"
}

_dotfiles_check() {
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  local cache_file="$cache_dir/dotfiles-check-date"
  local dotfiles="${DOTFILES:-$HOME/.dotfiles}"
  local today
  today=$(date +%Y-%m-%d)

  mkdir -p "$cache_dir"

  _dotfiles_check_sheldon_weekly "$cache_dir" "$today"
  _dotfiles_check_brew_weekly    "$cache_dir" "$today"

  [[ -f "$cache_file" && "$(< "$cache_file")" == "$today" ]] && return

  local updates=()
  local msg

  msg=$(_dotfiles_check_nix_daily          "$dotfiles") && [[ -n "$msg" ]] && updates+=("$msg")
  msg=$(_dotfiles_check_nix_upstream_daily "$dotfiles") && [[ -n "$msg" ]] && updates+=("$msg")
  msg=$(_dotfiles_check_sheldon_daily "$dotfiles") && [[ -n "$msg" ]] && updates+=("$msg")
  msg=$(_dotfiles_check_brew_daily    "$dotfiles") && [[ -n "$msg" ]] && updates+=("$msg")

  if (( ${#updates[@]} > 0 )); then
    print -P "%F{yellow}[dotfiles] 更新が必要:%f"
    for u in "${updates[@]}"; do
      print -P "  %F{cyan}$u%f"
    done
  fi

  print "$today" > "$cache_file"
}

_dotfiles_check
