# 更新チェックの進行ログ。起動ログ（load-log.zsh）と同じ書式に揃え、
# どのチェックに何ミリ秒かかったかを起動ログの続きとして読めるようにする。
# 終了は _load_end をそのまま呼ぶ。
_check_begin() {
  _load_begin "check:$1" checking checked
}

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

  _check_begin sheldon-weekly

  local lock_before lock_after
  [[ -f "$plugins_lock" ]] && lock_before=$(md5 -q "$plugins_lock" 2>/dev/null)
  if ! sheldon lock --update &>/dev/null; then
    _load_end
    return
  fi

  [[ -f "$plugins_lock" ]] && lock_after=$(md5 -q "$plugins_lock" 2>/dev/null)
  print "$today" > "$weekly_file"
  _load_end
  [[ "$lock_before" != "$lock_after" ]] || return

  print -P "%F{yellow}[dotfiles] sheldon プラグインが更新されました。exec zsh で反映できます%f"
}

_dotfiles_check_brew_weekly() {
  local cache_dir="$1" today="$2"
  local weekly_file="$cache_dir/brew-update-date"

  (( $+commands[brew] )) || return
  (( $(_dotfiles_days_since "$weekly_file") >= 7 )) || return

  _check_begin brew-weekly

  if ! brew update --quiet &>/dev/null; then
    _load_end
    return
  fi

  local outdated
  outdated=$(brew outdated --quiet 2>/dev/null)
  print "$today" > "$weekly_file"
  _load_end
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

  echo 'nix     → nix run home-manager -- switch --flake "$DOTFILES#${DOTFILES_MACHINE:?see nix/README.md}" --impure --no-update-lock-file'
}

# _dotfiles_ls_remote <ls-remote に渡す引数...>
# 先頭 1 行の SHA だけを返す。取れなければ空。
_dotfiles_ls_remote() {
  GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=5 \
    git ls-remote "$@" 2>/dev/null | awk 'NR==1{print $1}'
}

_dotfiles_check_nix_upstream_daily() {
  local dotfiles="$1"
  local flake_lock="$dotfiles/flake.lock"

  [[ -f "$flake_lock" ]] || return
  (( $+commands[jq] && $+commands[git] )) || return

  local has_update=0
  local owner repo locked ref remote url
  # ref は tsv の最後に置く。tab は IFS の空白文字なので、空フィールドが途中に
  # あると read が後続を詰めてしまい、ref を持たないノードが取り落ちる。
  while IFS=$'\t' read -r owner repo locked ref; do
    [[ -n "$owner" && -n "$repo" && -n "$locked" ]] || continue
    url="https://github.com/$owner/$repo.git"
    if [[ -n "$ref" ]]; then
      # branch と tag のどちらかは lock から判別できないため、両方のフルパスを
      # 1 回の問い合わせに並べる。
      remote=$(_dotfiles_ls_remote "$url" "refs/heads/$ref" "refs/tags/$ref")
    else
      remote=$(_dotfiles_ls_remote "$url" HEAD)
    fi
    [[ -n "$remote" ]] || continue
    [[ "$remote" != "$locked" ]] && has_update=1
  done < <(jq -r '[.nodes[] | .locked as $l | select($l.type == "github")
      | { owner: $l.owner, repo: $l.repo, rev: $l.rev, ref: (.original.ref // "") }]
    | unique_by([.owner, .repo, .ref])[]
    | [.owner, .repo, .rev, .ref] | @tsv' "$flake_lock")

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

  [[ -f "$dotfiles/brew/Brewfile" ]] && (( $+commands[brew] )) || return
  brew bundle check --file="$dotfiles/brew/Brewfile" --no-upgrade &>/dev/null && return

  echo "brew    → brew bundle install --file=$dotfiles/brew/Brewfile"
}

# daily 群をまとめて走らせ、所要時間と更新メッセージを結果ファイルへ書く。
# 進行ログを出さないのは、バックグラウンドで走るためプロンプト表示に割り込むから。
# 代わりにどのチェックに何ミリ秒かかったかを残し、次回の起動で読めるようにする。
_dotfiles_check_daily_async() {
  local dotfiles="$1" cache_dir="$2" today="$3"
  local result_file="$cache_dir/dotfiles-check-result"
  local -a updates timings
  local name fn msg start

  zmodload zsh/datetime

  for name fn in \
    nix          _dotfiles_check_nix_daily \
    nix-upstream _dotfiles_check_nix_upstream_daily \
    sheldon      _dotfiles_check_sheldon_daily \
    brew         _dotfiles_check_brew_daily
  do
    start=$EPOCHREALTIME
    msg=$("$fn" "$dotfiles")
    timings+=("$(printf '%-14s %.0fms' "$name" $(( (EPOCHREALTIME - start) * 1000 )))")
    [[ -n "$msg" ]] && updates+=("$msg")
  done

  {
    print -P "%F{blue}[dotfiles] 前回のチェック ($today):%f"
    for name in "${timings[@]}"; do
      print -P "  %F{cyan}$name%f"
    done
    if (( ${#updates[@]} > 0 )); then
      print -P "%F{yellow}[dotfiles] 更新が必要:%f"
      for msg in "${updates[@]}"; do
        print -P "  %F{cyan}$msg%f"
      done
    fi
  } > "$result_file"
}

_dotfiles_check() {
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  local cache_file="$cache_dir/dotfiles-check-date"
  local result_file="$cache_dir/dotfiles-check-result"
  local dotfiles="${DOTFILES:-$HOME/.dotfiles}"
  local today
  today=$(date +%Y-%m-%d)

  mkdir -p "$cache_dir"

  # 前回バックグラウンドで走らせた daily チェックの結果を出す
  if [[ -f "$result_file" ]]; then
    cat "$result_file"
    rm -f "$result_file"
  fi

  _dotfiles_check_sheldon_weekly "$cache_dir" "$today"
  _dotfiles_check_brew_weekly    "$cache_dir" "$today"

  [[ -f "$cache_file" && "$(< "$cache_file")" == "$today" ]] && return

  # 日付は起動前に書く。バックグラウンドの完了を待たずに次のシェルが立ち上がっても
  # 同じチェックを二重に走らせないため。
  print -r -- "$today" > "$cache_file"

  # daily 群は GitHub 側の応答待ちで数分かかることがある。起動を止めないよう
  # バックグラウンドへ逃がす。&! はバックグラウンド実行と disown をまとめて行う。
  _dotfiles_check_daily_async "$dotfiles" "$cache_dir" "$today" &!
}

# テストから関数定義だけを読み込めるようにする
[[ -n "$DOTFILES_CHECK_NO_AUTORUN" ]] || _dotfiles_check
