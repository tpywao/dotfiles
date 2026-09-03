#!/bin/bash
# PreToolUse hook for Bash: block obviously destructive commands.
# exit 2 + stderr message tells Claude Code to deny and surface the reason.
set -u

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null < /dev/stdin)
[ -z "$COMMAND" ] && exit 0

block() {
  echo "Blocked by ~/.claude/hooks/block-dangerous.sh: $1" >&2
  exit 2
}

if printf '%s' "$COMMAND" | grep -qE '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|-rf|-fr|-Rf|-fR)\b'; then
  block "rm -rf detected"
fi

if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+push\b'; then
  if printf '%s' "$COMMAND" | grep -qE '(--force(\s|$)|\s-f(\s|$))' \
    && ! printf '%s' "$COMMAND" | grep -q -- '--force-with-lease'; then
    block "git push --force (use --force-with-lease)"
  fi
fi

if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+(--[a-z-]+[[:space:]]+)*--hard\b'; then
  block "git reset --hard"
fi

if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+clean[[:space:]]+[^|;&]*-[a-zA-Z]*f'; then
  block "git clean -f"
fi

if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+branch[[:space:]]+[^|;&]*-D\b'; then
  block "git branch -D"
fi

# find は検索用途で許可しているが、-delete と -exec 系はファイル削除・任意コマンド実行の
# 経路になる。プレフィックス一致の allow ルールではこれらを弾けないためここで止める。
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|[:space:]])find[[:space:]][^;&|]*-(delete|exec|execdir|ok|okdir)\b'; then
  block "find -delete / -exec (use a read-only find, or ask the user to run it)"
fi

exit 0
