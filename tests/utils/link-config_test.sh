#! /bin/sh
# utils/install-common.sh の link_config() をケースごとに検証する。
#
#   sh tests/utils/link-config_test.sh
#
# $HOME は書き換えず、mktemp した一時ディレクトリだけを対象にする。
# link_config はリンク先の状態で 6 経路に分かれるため、経路ごとに
# 「出力タグ」「リンク先」「退避の中身」を確認する。

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

# assert_tag <期待するタグ> <link_config の出力>
# 出力には色コードが混ざるので部分一致で見る
assert_tag() {
  expected=$1
  output=$2
  case "$output" in
    *"$expected"*) pass ;;
    *) fail "tag: expected=$expected output=$output" ;;
  esac
}

# assert_readlink <期待するリンク先> <パス>
assert_readlink() {
  expected=$1
  link=$2
  actual=$(readlink "$link" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    pass
  else
    fail "readlink: expected=$expected actual=$actual ($link)"
  fi
}

# assert_content <期待する中身> <パス>
assert_content() {
  expected=$1
  path=$2
  # 退避先はタイムスタンプ付きなのでグロブで解決する（意図的にクォートしない）
  # shellcheck disable=SC2086
  actual=$(cat $path 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    pass
  else
    fail "content: expected=$expected actual=$actual ($path)"
  fi
}

# assert_count <期待する件数> <find の条件>
assert_count() {
  expected=$1
  shift
  actual=$(find "$@" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$actual" = "$expected" ]; then
    pass
  else
    fail "count: expected=$expected actual=$actual ($*)"
  fi
}

T=$(mktemp -d)
mkdir -p "$T/src" "$T/home"
echo "content-a" > "$T/src/a"
echo "content-b" > "$T/src/b"
mkdir -p "$T/src/dir"
echo "src-file" > "$T/src/dir/f"

# --- リンク先が存在しない: 張って [new] ---
out=$(link_config "$T/src/a" "$T/home/case1")
assert_tag "[new]" "$out"
assert_readlink "$T/src/a" "$T/home/case1"

# --- 同じ先を指す symlink: 何もせず [linked] ---
out=$(link_config "$T/src/a" "$T/home/case1")
assert_tag "[linked]" "$out"
assert_readlink "$T/src/a" "$T/home/case1"

# --- 別の先を指す symlink: 張り替えて [relinked] ---
out=$(link_config "$T/src/b" "$T/home/case1")
assert_tag "[relinked]" "$out"
assert_readlink "$T/src/b" "$T/home/case1"

# --- 実ファイルで内容が一致: 退避せず置き換えて [replaced] ---
cp "$T/src/a" "$T/home/case4"
out=$(link_config "$T/src/a" "$T/home/case4")
assert_tag "[replaced]" "$out"
assert_readlink "$T/src/a" "$T/home/case4"
assert_count 0 "$T/home" -name 'case4.presymlink.*'

# --- 実ファイルで内容が分岐: 退避してから張って [backup] ---
echo "locally edited" > "$T/home/case5"
out=$(link_config "$T/src/a" "$T/home/case5")
assert_tag "[backup]" "$out"
assert_readlink "$T/src/a" "$T/home/case5"
assert_count 1 "$T/home" -name 'case5.presymlink.*'
assert_content "locally edited" "$T/home/case5.presymlink.*"

# --- 実ディレクトリ: 内容を比較せず退避して [backup] ---
mkdir -p "$T/home/case6"
echo "existing" > "$T/home/case6/g"
out=$(link_config "$T/src/dir" "$T/home/case6")
assert_tag "[backup]" "$out"
assert_readlink "$T/src/dir" "$T/home/case6"
assert_content "existing" "$T/home/case6.presymlink.*/g"

# --- 親ディレクトリが無い: mkdir -p してから張る ---
out=$(link_config "$T/src/a" "$T/home/nested/deep/case7")
assert_tag "[new]" "$out"
assert_readlink "$T/src/a" "$T/home/nested/deep/case7"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
