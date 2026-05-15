#!/bin/bash
# SessionStart hook: inject branch + working-tree state as additional context.
# stdout is concatenated into Claude's context per the SessionStart hook spec.
set -u

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
STATUS=$(git status --short 2>/dev/null)

echo "## Git session context"
echo "- branch: ${BRANCH:-unknown}"
if [ -n "$STATUS" ]; then
  echo "- working tree:"
  printf '%s\n' "$STATUS" | sed 's/^/    /'
else
  echo "- working tree: clean"
fi
