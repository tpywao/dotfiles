#! /bin/sh
# docker/install.sh の merge_docker_config() をケースごとに検証する。
#
#   sh tests/docker/merge-config_test.sh
#
# $HOME は書き換えず、mktemp した一時ディレクトリを HOME に見せて
# docker/install.sh を実行する。dotfiles 側の共有キーが入ること、
# マシン固有キーが残ること、symlink が実体へ戻ることを確認する。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
SRC="$DOTFILES/docker/config.json"

if ! command -v jq > /dev/null 2>&1; then
  echo "SKIP  jq が無いため検証できない"
  exit 0
fi

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_tag <期待するタグ> <install.sh の出力>
# 出力には色コードが混ざるので部分一致で見る
assert_tag() {
  expected=$1
  output=$2
  case "$output" in
    *"$expected"*) pass ;;
    *) fail "tag: expected=$expected output=$output" ;;
  esac
}

# assert_no_tag <出てはいけないタグ> <install.sh の出力>
assert_no_tag() {
  unexpected=$1
  output=$2
  case "$output" in
    *"$unexpected"*) fail "tag: unexpected=$unexpected output=$output" ;;
    *) pass ;;
  esac
}

# assert_jq <期待する値> <jq のフィルタ> <パス>
assert_jq() {
  expected=$1
  filter=$2
  path=$3
  actual=$(jq -r "$filter" "$path" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    pass
  else
    fail "jq: expected=$expected actual=$actual ($filter of $path)"
  fi
}

# assert_not_symlink <パス>
assert_not_symlink() {
  if [ -L "$1" ]; then
    fail "symlink: $1 がまだ symlink"
  else
    pass
  fi
}

# run_install <HOME に見せるディレクトリ>
run_install() {
  HOME="$1" sh "$DOTFILES/docker/install.sh" 2>&1
}

# 共有キーは dotfiles 側の config.json から動的に取る。
# キー名を固定するとファイルを触るたびにテストが壊れる
shared_key=$(jq -r 'keys[0]' "$SRC")
shared_value=$(jq -r --arg k "$shared_key" '.[$k]' "$SRC")

T=$(mktemp -d)

# --- 既存の設定が無い: 共有キーだけの設定が作られる ---
h="$T/case1"
mkdir -p "$h"
out=$(run_install "$h")
assert_tag "[merged]" "$out"
assert_jq "$shared_value" ".[\"$shared_key\"]" "$h/.docker/config.json"

# --- マシン固有キーがある: 固有キーが残り、共有キーが足される ---
h="$T/case2"
mkdir -p "$h/.docker"
echo '{"credsStore":"desktop","currentContext":"desktop-linux"}' > "$h/.docker/config.json"
out=$(run_install "$h")
assert_tag "[merged]" "$out"
assert_jq "desktop" '.credsStore' "$h/.docker/config.json"
assert_jq "desktop-linux" '.currentContext' "$h/.docker/config.json"
assert_jq "$shared_value" ".[\"$shared_key\"]" "$h/.docker/config.json"

# --- 共有キーが既存にもある: dotfiles 側の値で上書きされる ---
h="$T/case3"
mkdir -p "$h/.docker"
jq -n --arg k "$shared_key" '{($k): "locally-edited"}' > "$h/.docker/config.json"
out=$(run_install "$h")
assert_tag "[merged]" "$out"
assert_jq "$shared_value" ".[\"$shared_key\"]" "$h/.docker/config.json"

# --- 既存の認証情報は消えない: dotfiles 側に無いネストしたキーが残る ---
h="$T/case4"
mkdir -p "$h/.docker"
echo '{"auths":{"registry.example.com":{"auth":"dummy"}}}' > "$h/.docker/config.json"
out=$(run_install "$h")
assert_tag "[merged]" "$out"
assert_jq "dummy" '.auths["registry.example.com"].auth' "$h/.docker/config.json"

# --- 旧バージョンが張った symlink: 実体へ戻してからマージする ---
# リンク先には dotfiles ではなくテスト用のファイルを使い、リンク先が
# 書き換えられないことも確認する
h="$T/case5"
mkdir -p "$h/.docker"
echo '{"credsStore":"desktop"}' > "$T/linked-source.json"
ln -s "$T/linked-source.json" "$h/.docker/config.json"
out=$(run_install "$h")
assert_tag "[unlinked]" "$out"
assert_tag "[merged]" "$out"
assert_not_symlink "$h/.docker/config.json"
# リンク経由で書き込まれていた値を引き継ぐ
assert_jq "desktop" '.credsStore' "$h/.docker/config.json"
assert_jq "$shared_value" ".[\"$shared_key\"]" "$h/.docker/config.json"
# リンク先は無傷
assert_jq "null" ".[\"$shared_key\"]" "$T/linked-source.json"

# --- 2 回目の実行: symlink は残っていないので [unlinked] は出ない ---
out=$(run_install "$h")
assert_tag "[merged]" "$out"
assert_no_tag "[unlinked]" "$out"
assert_jq "desktop" '.credsStore' "$h/.docker/config.json"

# --- 中間ファイルを残さない ---
if [ -z "$(find "$T" -name 'config.json.merging.*' -o -name 'config.json.unlinking.*')" ]; then
  pass
else
  fail "中間ファイルが残っている"
fi

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
