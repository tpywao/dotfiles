#! /bin/sh
# claude/hooks/inject-context.sh の出力をケースごとに検証する。
#
#   sh tests/claude/inject-context_test.sh
#
# hook は stdin から SessionStart の入力（{"session_id":...}）を読み、session_id と
# ブランチ・作業ツリーの状態を出力する。session_id は agent-status スキルが
# `agent-status.sh --collect <session_id>` に渡すのに使う。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
HOOK="$DOTFILES/claude/hooks/inject-context.sh"

pass_count=0
fail_count=0

T=$(mktemp -d)
trap 'rm -r "$T"' EXIT

export GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

git init -q "$T/repo"
git -C "$T/repo" commit -q --allow-empty -m init
mkdir "$T/plain"

# assert_lines <ラベル> <cwd> <stdin> <含まれるべき行>...
assert_lines() {
  label=$1
  out=$(cd "$2" && printf '%s' "$3" | sh "$HOOK" 2>&1)
  status=$?
  shift 3
  if [ "$status" -ne 0 ]; then
    fail_count=$((fail_count + 1))
    printf 'FAIL  %s: exit status %s\n' "$label" "$status"
    return
  fi
  for line in "$@"; do
    if ! printf '%s\n' "$out" | grep -Fx -- "$line" >/dev/null; then
      fail_count=$((fail_count + 1))
      printf 'FAIL  %s: 行が無い: %s\n' "$label" "$line"
      printf '%s\n' "$out" | sed 's/^/      /'
      return
    fi
  done
  pass_count=$((pass_count + 1))
}

assert_lines "git の中" "$T/repo" '{"session_id":"abc-123"}' \
  "- session_id: abc-123" \
  "- branch: main"
assert_lines "git の外でも session_id は出す" "$T/plain" '{"session_id":"abc-123"}' \
  "- session_id: abc-123"

out=$(cd "$T/plain" && printf '' | sh "$HOOK" 2>&1)
if [ $? -eq 0 ] && ! printf '%s\n' "$out" | grep 'session_id' >/dev/null; then
  pass_count=$((pass_count + 1))
else
  fail_count=$((fail_count + 1))
  printf 'FAIL  入力が空なら session_id の行を出さない: %s\n' "$out"
fi

printf '%d passed, %d failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
