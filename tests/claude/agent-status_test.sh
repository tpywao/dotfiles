#! /bin/sh
# claude/hooks/agent-status.sh の判定をケースごとに検証する。
#
#   sh tests/claude/agent-status_test.sh
#
# hook は stdin から {"session_id":...,"cwd":...,"stop_hook_active":...} を読み、記録を促す
# ときだけ additionalContext を出力する。どの経路でも exit 0 で終わる（ターンを終えられなく
# してはいけないため）。リポジトリは mktemp の下に作り、origin は手元の bare リポジトリ。
# 設定・状態のディレクトリも mktemp の下へ向けるので、実際の ~/.config・~/.local/state は触らない。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
HOOK="$DOTFILES/claude/hooks/agent-status.sh"

pass_count=0
fail_count=0

T=$(mktemp -d)
trap 'rm -r "$T"' EXIT

export GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export XDG_CONFIG_HOME="$T/config"
export XDG_STATE_HOME="$T/state"
STATE_DIR="$XDG_STATE_HOME/dotfiles/agent-status"
mkdir -p "$XDG_CONFIG_HOME/dotfiles"
printf '%s\n' 'https://example.invalid/sheet' > "$XDG_CONFIG_HOME/dotfiles/agent-status-sheet"

git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

# payload <session_id> <cwd> [<stop_hook_active>]
payload() {
  jq -n --arg sid "$1" --arg cwd "$2" --argjson active "${3:-false}" \
    '{session_id: $sid, cwd: $cwd, stop_hook_active: $active}'
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$*"
}

pass() {
  pass_count=$((pass_count + 1))
}

# run_hook <stdin>（out と status を設定する）
run_hook() {
  out=$(printf '%s' "$1" | sh "$HOOK" 2>&1)
  status=$?
}

# assert_remind <ラベル> <stdin> [<additionalContext に含まれるべき行>...]
assert_remind() {
  label=$1
  run_hook "$2"
  shift 2
  if [ "$status" -ne 0 ]; then
    fail "$label: exit status $status"
    return
  fi
  ctx=$(printf '%s' "$out" | jq -er 'select(.hookSpecificOutput.hookEventName == "Stop") | .hookSpecificOutput.additionalContext' 2>/dev/null)
  if [ -z "$ctx" ]; then
    fail "$label: expected=remind actual=${out:-silent}"
    return
  fi
  case $ctx in
    *agent-status*) ;;
    *) fail "$label: agent-status スキルを名指ししていない"; return ;;
  esac
  for line in "$@"; do
    if ! printf '%s\n' "$ctx" | grep -Fx -- "$line" >/dev/null; then
      fail "$label: 行が無い: $line"
      printf '%s\n' "$ctx" | sed 's/^/      /'
      return
    fi
  done
  pass
}

# assert_silent <ラベル> <stdin>
assert_silent() {
  run_hook "$2"
  if [ "$status" -ne 0 ]; then
    fail "$1: exit status $status"
  elif [ -n "$out" ]; then
    fail "$1: expected=silent actual=$out"
  else
    pass
  fi
}

# --- リポジトリの用意 ---
git init -q --bare "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2>/dev/null
cd "$T/repo" || exit 1
git commit -q --allow-empty -m init
git push -q origin main 2>/dev/null
git remote set-head origin main
# worktree で main を開けるよう、メインの作業ツリーは別のブランチにしておく
git switch -q -c other
mkdir "$T/repo/sub"

# new_worktree <名前> <ブランチ>
new_worktree() {
  git worktree add -q -b "$2" "$T/$1" origin/main 2>/dev/null
}

new_worktree wt feat/x
git -C "$T/wt" commit -q --allow-empty -m 'wt commit'
mkdir "$T/wt/sub"

git worktree add -q "$T/onmain" main 2>/dev/null
git worktree add -q --detach "$T/detached" origin/main 2>/dev/null

new_worktree quote feat/quote
git -C "$T/quote" commit -q --allow-empty -m 'say "hi" \ back'

new_worktree thr feat/thr
new_worktree col feat/col

for form in scp https ssh; do
  git init -q "$T/url-$form"
  git -C "$T/url-$form" commit -q --allow-empty -m init
done
git -C "$T/url-scp" remote add origin git@github.com:o/r.git
git -C "$T/url-https" remote add origin https://github.com/o/r
git -C "$T/url-ssh" remote add origin ssh://git@github.com:22/o/r.git

git init -q "$T/nocommit"
mkdir "$T/plain"

# 7 日より古い別セッションの状態ファイル（掃除される）
mkdir -p "$STATE_DIR"
: > "$STATE_DIR/oldsession"
touch -t 202001010000 "$STATE_DIR/oldsession"

# --- 促す ---
assert_remind "一度も push していないブランチのコミット" "$(payload s-wt "$T/wt")" \
  "- シート: https://example.invalid/sheet" \
  "- セッション ID: s-wt" \
  "- ブランチ: feat/x" \
  "- 未 push 件数: 1" \
  "- 最新コミット件名: wt commit"
assert_remind "git の外" "$(payload s-plain "$T/plain")" \
  "- リポジトリ: plain" \
  "- ブランチ:" \
  "- 未 push 件数: 0" \
  "- 最新コミット件名:"

if printf '%s\n' "$ctx" | grep -E '^- 現在時刻（日本時間）: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' >/dev/null; then
  pass
else
  fail "現在時刻の行の書式"
fi
if printf '%s\n' "$ctx" | grep -E '^- マシン: .+$' >/dev/null; then
  pass
else
  fail "マシンの行が空"
fi

if [ -e "$STATE_DIR/oldsession" ]; then
  fail "7 日より古い状態ファイルが残っている"
else
  pass
fi

# --- 同じセッションでの間引き ---
assert_remind "初めてのターン終わり" "$(payload s-thr "$T/thr")" "- ブランチ: feat/thr"
assert_silent "同じ指紋で 30 分以内" "$(payload s-thr "$T/thr")"
git -C "$T/thr" commit -q --allow-empty -m 'thr commit'
assert_remind "指紋が変わった" "$(payload s-thr "$T/thr")" "- 未 push 件数: 1"
assert_silent "変わった後の同じ指紋" "$(payload s-thr "$T/thr")"
touch -t 202001010000 "$STATE_DIR/s-thr"
assert_remind "前回から 30 分以上たった" "$(payload s-thr "$T/thr")" "- ブランチ: feat/thr"

# --- 黙る ---
assert_silent "stop_hook_active" "$(payload s-active "$T/wt" true)"
# 関数の前に置いた代入が呼び出し後に残るかは sh の実装で違うので、明示的に戻す
XDG_CONFIG_HOME="$T/noconfig"
assert_silent "シートの設定が無い" "$(payload s-noconf "$T/wt")"
XDG_CONFIG_HOME="$T/config"
assert_silent "session_id にパス区切り" "$(payload ../escaped "$T/wt")"
if [ -e "$XDG_STATE_HOME/dotfiles/escaped" ] || [ -e "$STATE_DIR/../escaped" ]; then
  fail "状態ディレクトリの外にファイルができた"
else
  pass
fi
assert_silent "壊れた JSON" 'not json'
assert_silent "存在しない cwd" "$(payload s-missing "$T/missing")"

mkdir "$T/nojq" "$T/nogit"
ln -s "$(command -v jq)" "$T/nogit/jq"
for dir in nojq nogit; do
  out=$(payload "s-$dir" "$T/wt" | PATH="$T/$dir" /bin/sh "$HOOK" 2>&1)
  status=$?
  if [ "$status" -eq 0 ] && [ -z "$out" ]; then
    pass
  else
    fail "PATH に ${dir#no} が無い: status=$status out=$out"
  fi
done

# --- ブランチ列 ---
assert_remind "worktree の作業ブランチ" "$(payload b-wt "$T/wt")" "- ブランチ: feat/x"
assert_remind "worktree のサブディレクトリ" "$(payload b-wtsub "$T/wt/sub")" "- ブランチ: feat/x"
assert_remind "origin のデフォルトブランチ" "$(payload b-main "$T/onmain")" "- ブランチ:"
assert_remind "detached HEAD" "$(payload b-detached "$T/detached")" "- ブランチ:"
assert_remind "メインの作業ツリーのルート" "$(payload b-root "$T/repo")" "- ブランチ:"
assert_remind "メインの作業ツリーのサブディレクトリ" "$(payload b-rootsub "$T/repo/sub")" "- ブランチ:"

# --- リポジトリ列 ---
for form in scp https ssh; do
  assert_remind "origin の URL（${form}）" "$(payload "u-$form" "$T/url-$form")" "- リポジトリ: o/r"
done

# --- 壊れない ---
assert_remind "件名に引用符とバックスラッシュ" "$(payload q-quote "$T/quote")" \
  '- 最新コミット件名: say "hi" \ back'
assert_remind "コミットの無いリポジトリ" "$(payload q-nocommit "$T/nocommit")" "- 未 push 件数: 0"

# --- --collect ---
collected=$(cd "$T/col" && sh "$HOOK" --collect c-col 2>&1)
status=$?
if [ "$status" -eq 0 ] \
  && printf '%s\n' "$collected" | grep -Fx -- "- セッション ID: c-col" >/dev/null \
  && printf '%s\n' "$collected" | grep -Fx -- "- ブランチ: feat/col" >/dev/null; then
  pass
else
  fail "--collect: status=$status out=$collected"
fi
assert_silent "--collect の直後の同じ指紋" "$(payload c-col "$T/col")"
collected=$(cd "$T/col" && XDG_CONFIG_HOME="$T/noconfig" sh "$HOOK" --collect c-noconf 2>&1)
if [ -z "$collected" ]; then
  pass
else
  fail "--collect でシートの設定が無いのに出力した: $collected"
fi

printf '%d passed, %d failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
