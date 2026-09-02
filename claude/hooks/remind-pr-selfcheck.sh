#!/bin/bash
# PreToolUse hook for Bash: remind to run the pr-selfcheck skill before opening a PR.
# Denies the first `gh pr create` in a 30-minute window (exit 2 surfaces the reason
# to Claude), then lets a retry through so it cannot loop.
set -u

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null < /dev/stdin)
[ -z "$COMMAND" ] && exit 0

printf '%s' "$COMMAND" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create\b' || exit 0

MARKER="${TMPDIR:-/tmp}/claude-pr-selfcheck-reminded"

if [ -f "$MARKER" ] && [ -n "$(find "$MARKER" -mmin -30 2>/dev/null)" ]; then
  exit 0
fi

touch "$MARKER"

cat >&2 <<'MSG'
Reminder from ~/.claude/hooks/remind-pr-selfcheck.sh: pr-selfcheck が未実行の可能性があります。

PR を作る前に pr-selfcheck スキルを実行し、レビュー負荷を上げる要因を本文へ反映してください
（分割候補 / 旧→新の対応表 / 失敗経路の分岐表 / 閾値の一覧 / 未検証の経路 / 読む順番）。

すでに実行済み、または不要と判断した場合は、同じコマンドをもう一度実行すれば通ります。
MSG
exit 2
