#!/bin/bash
# PostToolUse hook (Edit|Write): re-hardlink any ~/.claude/<path> file that has a
# counterpart at ~/.dotfiles/claude/<path>. Claude's Edit/Write use atomic save
# (tmpfile + rename), which breaks hardlinks on every edit; this script restores
# the link by mtime so both copies stay in sync.
set -u

EDITED=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null < /dev/stdin)
[ -z "$EDITED" ] && exit 0

case "$EDITED" in
  "$HOME/.claude/"*)
    rest="${EDITED#$HOME/.claude/}"
    OTHER="$HOME/.dotfiles/claude/$rest"
    ;;
  "$HOME/.dotfiles/claude/"*)
    rest="${EDITED#$HOME/.dotfiles/claude/}"
    OTHER="$HOME/.claude/$rest"
    ;;
  *)
    exit 0
    ;;
esac

[ -f "$EDITED" ] || exit 0
[ -f "$OTHER" ] || exit 0

if [ "$EDITED" -ef "$OTHER" ]; then
  exit 0
fi

if [ "$EDITED" -nt "$OTHER" ]; then
  SRC="$EDITED"; DST="$OTHER"
else
  SRC="$OTHER"; DST="$EDITED"
fi

/bin/rm -- "$DST" && ln "$SRC" "$DST"
