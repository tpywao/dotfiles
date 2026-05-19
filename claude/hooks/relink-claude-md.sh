#!/bin/bash
# PostToolUse hook (Edit|Write): re-hardlink CLAUDE.md between ~/.claude and ~/.dotfiles
# after either side is edited. Claude's Edit/Write use atomic save (tmpfile + rename),
# which breaks hardlinks on every edit; this script restores the link by mtime.
set -u

EDITED=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null < /dev/stdin)
[ -z "$EDITED" ] && exit 0

case "$EDITED" in
  */CLAUDE.md) ;;
  *) exit 0 ;;
esac

A="$HOME/.claude/CLAUDE.md"
B="$HOME/.dotfiles/claude/CLAUDE.md"

[ -f "$A" ] || exit 0
[ -f "$B" ] || exit 0

if [ "$A" -ef "$B" ]; then
  exit 0
fi

if [ "$A" -nt "$B" ]; then
  SRC="$A"; DST="$B"
else
  SRC="$B"; DST="$A"
fi

/bin/rm -- "$DST" && ln "$SRC" "$DST"
