#! /bin/sh
# utils/install-common.sh の refuse_worktree をケースごとに検証する。
#
#   sh tests/utils/refuse-worktree_test.sh
#
# 一時ディレクトリに git リポジトリと worktree を作り、install.sh と同じ形で共通部を
# source する入口を置いて実行する。実際の ~/ もこのリポジトリも触らない。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)

# このテスト自身が worktree の中で流れていても、下の検証には影響させない
unset DOTFILES_ALLOW_WORKTREE

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_status <期待する終了ステータス> <実際> <ラベル>
assert_status() {
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "$3: expected=$1 actual=$2"
  fi
}

# assert_contains <期待する部分文字列> <実際の文字列> <ラベル>
assert_contains() {
  case "$2" in
    *"$1"*) pass ;;
    *) fail "$3: expected=$1 actual=$2" ;;
  esac
}

T=$(cd "$(mktemp -d)" && pwd -P)

# put_entry <ディレクトリ>: 共通部を置き、それを source する入口を作る
put_entry() {
  mkdir -p "$1/utils"
  cp "$DOTFILES/utils/install-common.sh" "$DOTFILES/utils/utils.bash" "$1/utils/"
  cat > "$1/entry.sh" <<'EOF'
#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")" && pwd -P)
. "$DOTFILES/utils/install-common.sh"
echo reached
EOF
}

MAIN="$T/main"
mkdir -p "$MAIN"
put_entry "$MAIN"
git init -q "$MAIN"
(
  cd "$MAIN" || exit 1
  git add .
  git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null commit -q -m init
  git worktree add -q "$T/wt" -b wt
)

# メインの作業ツリー
out=$(sh "$MAIN/entry.sh" 2>&1)
assert_status 0 $? "メインの作業ツリーでは止めない"
assert_contains reached "$out" "メインの作業ツリーで続行する"

# worktree
out=$(sh "$T/wt/entry.sh" 2>&1)
assert_status 1 $? "worktree では止める"
assert_contains "cd $MAIN " "$out" "メインの作業ツリーのパスを示す"
case "$out" in
  *reached*) fail "worktree では後続を実行しない" ;;
  *) pass ;;
esac

# worktree + 明示の許可
out=$(DOTFILES_ALLOW_WORKTREE=1 sh "$T/wt/entry.sh" 2>&1)
assert_status 0 $? "許可すれば止めない"
assert_contains reached "$out" "許可すれば続行する"

# git 管理外
OUTSIDE="$T/outside"
mkdir -p "$OUTSIDE"
put_entry "$OUTSIDE"
out=$(sh "$OUTSIDE/entry.sh" 2>&1)
assert_status 0 $? "git 管理外では止めない"
assert_contains reached "$out" "git 管理外で続行する"

# git が無い環境（コマンドが見つからないときと同じ 127 を返すスタブで代える）
STUB="$T/stub"
mkdir -p "$STUB"
printf '#! /bin/sh\nexit 127\n' > "$STUB/git"
chmod +x "$STUB/git"
out=$(PATH="$STUB:$PATH" sh "$T/wt/entry.sh" 2>&1)
assert_status 0 $? "git が無ければ止めない"
assert_contains reached "$out" "git が無くても続行する"

/bin/rm -r -- "$T"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
