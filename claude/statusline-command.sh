#!/bin/bash
# Claude Code statusLine
#
# 1行目: モデル名 + reasoning effort、リポジトリ名 + 現在の git ブランチ
# 2行目: コンテキスト使用量ゲージ、レートリミット (5h/7d) の使用率とリセット時刻
#
# 参照した stdin JSON フィールド:
#   .model.display_name / .model.id
#   .effort.level                              (reasoning effort 対応モデルのみ存在)
#   .workspace.repo.owner / .name               (GitHub 等の remote がある場合のみ存在)
#   .workspace.current_dir / .cwd
#   .context_window.used_percentage             (最初のメッセージ送信前は null)
#   .rate_limits.five_hour.used_percentage / .resets_at   (Claude.ai サブスクのみ、初回応答後)
#   .rate_limits.seven_day.used_percentage / .resets_at
#
# 備考(JSON に無く代替/フォールバックしている情報):
#   - 通常セッションの stdin JSON にはブランチ名フィールドが無いため git コマンドで取得する
#     (worktree.branch は --worktree セッション限定、workspace.git_worktree は worktree 名のみ)
#   - workspace.repo が無い場合は git remote origin から owner/repo を推測し、
#     それも無ければディレクトリ名で代替する
#   - reasoning effort / rate_limits はフィールド自体が存在しない場合、
#     その部分の表示を単に省略する(代替できる情報が無いため)

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

model_name=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown model"')
effort=$(echo "$input" | jq -r '.effort.level // empty')

owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty')
reponame=$(echo "$input" | jq -r '.workspace.repo.name // empty')
if [ -n "$owner" ] && [ -n "$reponame" ]; then
  repo="$owner/$reponame"
else
  remote_url=$(git -C "$cwd" --no-optional-locks remote get-url origin 2>/dev/null)
  if [ -n "$remote_url" ]; then
    repo=$(echo "$remote_url" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')
  else
    repo=$(basename "$cwd")
  fi
fi

branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

# ---------- 1行目: model / effort / repo / branch ----------
line1=$(printf '\033[1;36m%s\033[0m' "$model_name")
[ -n "$effort" ] && line1="$line1 $(printf '\033[2m[%s]\033[0m' "$effort")"
if [ -n "$repo" ] || [ -n "$branch" ]; then
  line1="$line1 $(printf '\033[2m|\033[0m')"
  [ -n "$repo" ] && line1="$line1 $(printf '\033[33m%s\033[0m' "$repo")"
  [ -n "$branch" ] && line1="$line1 $(printf '\033[32m(%s)\033[0m' "$branch")"
fi

# ---------- 2行目: context ゲージ + レートリミット ----------
bar_width=10

make_gauge() {
  # $1: percentage (0-100, 小数可)
  local pct="$1" filled color bar i
  filled=$(awk -v p="$pct" -v w="$bar_width" 'BEGIN{v=int((p*w/100)+0.5); if(v<0)v=0; if(v>w)v=w; print v}')
  if awk -v p="$pct" 'BEGIN{exit !(p>=85)}'; then
    color="31" # red
  elif awk -v p="$pct" 'BEGIN{exit !(p>=60)}'; then
    color="33" # yellow
  else
    color="32" # green
  fi
  bar=""
  i=0
  while [ "$i" -lt "$bar_width" ]; do
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}#"
    else
      bar="${bar}-"
    fi
    i=$((i + 1))
  done
  printf '\033[%sm[%s]\033[0m %s%%' "$color" "$bar" "$(awk -v p="$pct" 'BEGIN{printf "%.0f", p}')"
}

fmt_time() {
  # $1: unix epoch (秒), $2: date フォーマット (省略時 +%H:%M) -> フォーマット済み文字列 (ローカルタイム)
  local epoch="$1" fmt="${2:-+%H:%M}"
  date -r "$epoch" "$fmt" 2>/dev/null || date -d "@$epoch" "$fmt" 2>/dev/null
}

fmt_remaining() {
  # $1: unix epoch (秒) -> リセットまでの残り時間 (例: 2d14h / 14h32m / 32m)
  # 負値 (リセット済みの古い値) は 0m にクランプする
  local epoch="$1"
  awk -v epoch="$epoch" -v now="$(date +%s)" 'BEGIN {
    diff = epoch - now
    if (diff < 0) diff = 0
    days = int(diff / 86400)
    hours = int((diff % 86400) / 3600)
    minutes = int((diff % 3600) / 60)
    if (days > 0) printf "%dd%dh", days, hours
    else if (hours > 0) printf "%dh%dm", hours, minutes
    else printf "%dm", minutes
  }'
}

ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx_used" ]; then
  line2="Context: $(make_gauge "$ctx_used")"
else
  line2="Context: N/A"
fi

five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$five_used" ]; then
  five_str=$(printf '5h: \033[2m%.0f%%\033[0m' "$five_used")
  [ -n "$five_reset" ] && five_str="$five_str ($(fmt_time "$five_reset"))"
  line2="$line2 $(printf '\033[2m|\033[0m') $five_str"
fi

seven_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
if [ -n "$seven_used" ]; then
  seven_str=$(printf '7d: \033[2m%.0f%%\033[0m' "$seven_used")
  [ -n "$seven_reset" ] && seven_str="$seven_str ($(fmt_remaining "$seven_reset"))"
  line2="$line2 $(printf '\033[2m|\033[0m') $seven_str"
fi

printf '%s\n%s' "$line1" "$line2"
