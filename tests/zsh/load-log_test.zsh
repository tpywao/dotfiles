#! /usr/bin/env zsh
# zsh/load-log.zsh の _load_begin / _load_end を検証する。
#
#   zsh tests/zsh/load-log_test.zsh
#
# _load_begin / _load_end は対話シェルでしか出力しない。非対話で起動された場合は
# 対話シェル（-i）かつ設定ファイル無効（-f）で自分を再実行する。-f があるので
# $ZDOTDIR の設定は読まれず、副作用はない。
[[ -o interactive ]] || exec zsh -if "$0" "$@"

DOTFILES=${0:A:h:h:h}

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_eq <期待値> <実際値> <ラベル>
assert_eq() {
  if [[ "$1" == "$2" ]]; then
    pass
  else
    fail "$3: expected=$1 actual=$2"
  fi
}

# assert_match <期待するグロブ> <実際値> <ラベル>
assert_match() {
  if [[ "$2" == ${~1} ]]; then
    pass
  else
    fail "$3: expected to match=$1 actual=$2"
  fi
}

tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT

source "$DOTFILES/zsh/load-log.zsh"

# 関数はメインシェルで実行してファイルへ落とす。コマンド置換で包むと
# サブシェルになり、_load_begin が置いた状態が _load_end へ渡らない。
run() {
  "$@" > "$tmp/out" 2>&1
}

# 直前の run の出力
readout() {
  print -r -- "$(< "$tmp/out")"
}

# --- 語を指定しない場合は loading / loaded ---
run _load_begin foo
assert_eq "foo: loading..." "$(readout)" "既定の開始ログ"

run _load_end
assert_match "foo: loaded \(<->ms\)" "$(readout)" "既定の終了ログ"

# --- 語を指定した場合はその語を使う ---
run _load_begin bar checking checked
assert_eq "bar: checking..." "$(readout)" "指定した開始語"

run _load_end
assert_match "bar: checked \(<->ms\)" "$(readout)" "指定した終了語"

# --- 名前にコロンを含んでもそのまま出す ---
run _load_begin "check:nix-upstream" checking checked
assert_eq "check:nix-upstream: checking..." "$(readout)" "名前にコロンを含む場合"

run _load_end
assert_match "check:nix-upstream: checked \(<->ms\)" "$(readout)" "名前にコロンを含む場合の終了ログ"

# --- 非対話シェルでは何も出さない ---
cat > "$tmp/quiet.zsh" <<QUIET
source "$DOTFILES/zsh/load-log.zsh"
_load_begin foo checking checked
_load_end
QUIET
out=$(zsh -f "$tmp/quiet.zsh" 2>&1)
assert_eq "" "$out" "非対話では無出力"

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
