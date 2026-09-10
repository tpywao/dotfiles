#! /bin/sh
# utils/install-common.sh の notice() をケースごとに検証する。
#
#   sh tests/utils/notice_test.sh
#
# $HOME は書き換えず、mktemp した一時ディレクトリだけを対象にする。
# DOTFILES_NOTICES の有無で出力先が分かれるため（ルートの install.sh 経由か、
# 各 install.sh の単体実行か）、経路ごとに「どちらへ出たか」を確認する。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_contains <期待する部分文字列> <実際の文字列> <ラベル>
assert_contains() {
  case "$2" in
    *"$1"*) pass ;;
    *) fail "$3: expected=$1 actual=$2" ;;
  esac
}

# assert_equals <期待する文字列> <実際の文字列> <ラベル>
assert_equals() {
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "$3: expected=$1 actual=$2"
  fi
}

T=$(mktemp -d)

# --- DOTFILES_NOTICES が無い（単体実行）: その場で標準出力へ出す ---
DOTFILES_NOTICES=
out=$(notice "すぐ出す文言")
assert_contains "すぐ出す文言" "$out" "単体実行の出力"

# --- DOTFILES_NOTICES がある（ルート経由）: 標準出力へは出さずファイルへ溜める ---
DOTFILES_NOTICES="$T/notices"
: > "$DOTFILES_NOTICES"
out=$(notice "後で出す文言")
assert_equals "" "$out" "ルート経由で標準出力へ漏れない"
assert_equals "後で出す文言" "$(cat "$DOTFILES_NOTICES")" "ファイルの内容"

# --- 複数回呼ぶと呼んだ順に追記される ---
notice "2 件目"
assert_equals "後で出す文言
2 件目" "$(cat "$DOTFILES_NOTICES")" "追記の順序"

# --- 複数行の文言は改行を保つ（コマンドを並べて案内するため） ---
: > "$DOTFILES_NOTICES"
notice "見出し:
  cmd --flag
  ./install.sh"
assert_equals "見出し:
  cmd --flag
  ./install.sh" "$(cat "$DOTFILES_NOTICES")" "複数行の保持"

# --- 一度も呼ばなければ空のまま（ルートが TODO 見出しを出さない条件） ---
: > "$DOTFILES_NOTICES"
if [ -s "$DOTFILES_NOTICES" ]; then
  fail "呼んでいないのに中身がある"
else
  pass
fi

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
