#!/bin/bash
# PreToolUse hook (Bash): PR を作る前に pr-selfcheck スキルの実行を促す。
# 30 分の窓のうち最初の 1 件だけを exit 2 で止める（stderr に書いた理由が Claude に渡る）。
# マーカーはこのスクリプト自身が作るため、再実行は必ず通りループしない。
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
