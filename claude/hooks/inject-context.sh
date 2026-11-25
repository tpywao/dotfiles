#!/bin/bash
# SessionStart hook: inject session_id, branch and working-tree state as additional context.
# stdout is concatenated into Claude's context per the SessionStart hook spec.
# The session_id is what the agent-status skill passes to `agent-status.sh --collect`
# when recording without waiting for the Stop hook; the model has no other way to learn it.
set -u

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
  if [ -n "$SESSION_ID" ]; then
    echo "## Session"
    echo "- session_id: $SESSION_ID"
  fi
fi

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
