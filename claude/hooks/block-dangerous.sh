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

# フラグは git push と同じサブコマンド内にあるものだけを見る ([^|;&]* が区切りで止まる)。
# コマンド文字列全体から探すと、無関係な -f (shellcheck -f など) と同居しただけで誤検知する。
# --force-with-lease は --force の直後が - なので終端に合わず、このパターンには掛からない。
if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+push[[:space:]]+[^|;&]*(--force|-f)([[:space:]]|[|;&]|$)'; then
  block "git push --force (use --force-with-lease)"
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

exit 0
