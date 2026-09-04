#! /bin/sh
# claude/hooks/block-dangerous.sh の判定をケースごとに検証する。
#
#   sh tests/claude/block-dangerous_test.sh
#
# hook は stdin から {"tool_input":{"command":...}} を読み、ブロック時に exit 2 を返す。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
HOOK="$DOTFILES/claude/hooks/block-dangerous.sh"

pass_count=0
fail_count=0

# assert <block|allow> <コマンド文字列>
assert() {
  expected=$1
  cmd=$2

  printf '%s' "$cmd" | jq -R '{tool_input:{command:.}}' | sh "$HOOK" > /dev/null 2>&1
  status=$?
  if [ "$status" -eq 2 ]; then
    actual=block
  else
    actual=allow
  fi

  if [ "$actual" = "$expected" ]; then
    pass_count=$((pass_count + 1))
  else
    fail_count=$((fail_count + 1))
    printf 'FAIL  expected=%s actual=%s  %s\n' "$expected" "$actual" "$cmd"
  fi
}

# --- 強制プッシュ: 止めるもの ---
assert block 'git push --force'
assert block 'git push -f'
assert block 'git push origin main --force'
assert block 'git push -f origin main'
assert block 'echo start && git push -f'
# 区切り文字が直後に来ても終端として扱う（空白・行末しか見ないと素通しになる）
assert block 'git push --force; echo done'
assert block 'git push --force && echo done'
assert block 'git push -f | tee push.log'
# --force-with-lease を併記しても --force が効くので止める
assert block 'git push --force-with-lease --force'
# --force-with-lease が別のサブコマンドにあっても素通しにしない
assert block 'git push --force; echo --force-with-lease'

# --- 強制プッシュ: 通すもの ---
assert allow 'git push'
assert allow 'git push origin main'
assert allow 'git push --force-with-lease'
assert allow 'git push --force-with-lease origin main'
# 別コマンドの -f が git push と同居しても誤検知しない
assert allow 'shellcheck -f gcc install.sh; git push'
assert allow 'git push; shellcheck -f gcc install.sh'
assert allow 'rg -f patterns.txt . && git push'
assert allow 'git push | tail -3'

# --- 他の判定の回帰 ---
assert block 'rm -rf /tmp/example'
assert block 'git clean -f'
assert block 'git branch -D topic'
assert block 'git reset --hard'
assert allow 'git branch -d topic'
assert allow 'git status'
assert allow 'rm /tmp/example'

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
