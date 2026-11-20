#! /bin/sh
# claude/hooks/push-reminder.sh の判定をケースごとに検証する。
#
#   sh tests/claude/push-reminder_test.sh
#
# hook は stdin から {"cwd":...,"stop_hook_active":...} を読み、push を促すときだけ
# additionalContext を出力する。どの経路でも exit 0 で終わる（ターンを終えられなく
# してはいけないため）。リポジトリは mktemp の下に作り、origin は手元の bare リポジトリ。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
HOOK="$DOTFILES/claude/hooks/push-reminder.sh"

pass_count=0
fail_count=0

# assert <remind|silent> <cwd> <stop_hook_active> <ラベル>
assert() {
  out=$(jq -n --arg cwd "$2" --argjson active "$3" '{cwd: $cwd, stop_hook_active: $active}' | sh "$HOOK" 2>&1)
  status=$?
  if [ "$status" -ne 0 ]; then
    fail_count=$((fail_count + 1))
    printf 'FAIL  %s: exit status %s\n' "$4" "$status"
    return
  fi

  actual=silent
  if [ -n "$out" ]; then
    if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "Stop" and (.hookSpecificOutput.additionalContext | contains("未 push"))' >/dev/null 2>&1; then
      actual=remind
    else
      actual="invalid: $out"
    fi
  fi

  if [ "$actual" = "$1" ]; then
    pass_count=$((pass_count + 1))
  else
    fail_count=$((fail_count + 1))
    printf 'FAIL  %s: expected=%s actual=%s\n' "$4" "$1" "$actual"
  fi
}

T=$(mktemp -d)
trap 'rm -r "$T"' EXIT

export GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

git init -q --bare "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2>/dev/null
cd "$T/repo" || exit 1
git commit -q --allow-empty -m init
git push -q origin main 2>/dev/null
git remote set-head origin main

# new_worktree <名前> <ブランチ>
new_worktree() {
  git worktree add -q -b "$2" "$T/$1" origin/main 2>/dev/null
}

new_worktree pushed feat/pushed
git -C "$T/pushed" commit -q --allow-empty -m pushed
git -C "$T/pushed" push -q origin feat/pushed 2>/dev/null

new_worktree unpushed feat/unpushed
git -C "$T/unpushed" commit -q --allow-empty -m one
git -C "$T/unpushed" push -q origin feat/unpushed 2>/dev/null
git -C "$T/unpushed" commit -q --allow-empty -m two

new_worktree never feat/never
git -C "$T/never" commit -q --allow-empty -m never

new_worktree empty feat/empty

git worktree add -q --detach "$T/detached" origin/main 2>/dev/null
git -C "$T/detached" commit -q --allow-empty -m detached

git -C "$T/repo" commit -q --allow-empty -m on-default

git init -q "$T/noorigin"
git -C "$T/noorigin" commit -q --allow-empty -m local

mkdir "$T/plain"

assert remind "$T/unpushed" false "push 済みのブランチに積んだ未 push のコミット"
assert remind "$T/never" false "一度も push していないブランチのコミット"
assert silent "$T/pushed" false "すべて push 済み"
assert silent "$T/empty" false "コミットの無い新しいブランチ"
assert silent "$T/unpushed" true "促した後のターン終わり（stop_hook_active）"
assert silent "$T/repo" false "origin のデフォルトブランチ"
assert silent "$T/noorigin" false "origin の無いリポジトリ"
assert silent "$T/detached" false "detached HEAD"
assert silent "$T/plain" false "git の外"
assert silent "$T/missing" false "存在しない cwd"

printf '%d passed, %d failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
