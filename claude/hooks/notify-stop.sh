#!/usr/bin/env bash
# Stop フック: 作業完了を macOS 通知（バナー＋サウンド）で知らせる。
# terminal-notifier があれば -activate で「クリック→実行中アプリ（iTerm2/VSCode 等）を前面化」。
# 無ければ osascript にフォールバック（クリック先は変えられない）。
input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')

project=$(basename "${cwd:-$PWD}")
branch=$(git -C "${cwd:-$PWD}" rev-parse --abbrev-ref HEAD 2>/dev/null)

# 直近の assistant メッセージの先頭非空行を要約として使う
summary=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  summary=$(jq -rs '
    map(select(.type=="assistant")) | last
    | (.message.content[]? | select(.type=="text") | .text) // empty
  ' "$transcript" 2>/dev/null | grep -v '^[[:space:]]*$' | head -1)
fi
[ -z "$summary" ] && summary="作業が完了しました"
summary=$(printf '%s' "$summary" | cut -c1-150)

title="Claude Code: $project"
[ -n "$branch" ] && title="$title ($branch)"

# 実行中アプリの bundle-id（クリック時の遷移先）。プロセスツリーから継承される。
app="${__CFBundleIdentifier}"

if command -v terminal-notifier >/dev/null 2>&1; then
  args=(-title "$title" -message "$summary" -sound Glass -group claude-code-stop)
  [ -n "$app" ] && args+=(-activate "$app")
  terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
else
  s=$(printf '%s' "$summary" | tr -d '"\\')
  t=$(printf '%s' "$title" | tr -d '"\\')
  osascript -e "display notification \"$s\" with title \"$t\" sound name \"Glass\"" 2>/dev/null || true
fi
