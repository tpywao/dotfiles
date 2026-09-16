#! /bin/sh
# karabiner/install.sh を karabiner.json の状態ごとに検証する。
#
#   sh tests/karabiner/install_test.sh
#
# 実機の ~/.config/karabiner は触らない。$HOME を mktemp した一時ディレクトリへ
# 差し替えて install.sh を実行する。
#
# 見るのは 3 点。complex modifications が assets/ へリンクされること、
# profile-defaults.json のキーだけが karabiner.json へ入って他のキーが残ること、
# そして GUI での有効化が要るルールと Karabiner 未起動が TODO へ回ること。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

is_mac || {
  echo "skip: macOS 専用のため"
  exit 0
}

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

# assert_eq <期待値> <実際の値> <ラベル>
assert_eq() {
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
    *) fail "$3: expected to contain=$1" ;;
  esac
}

# assert_not_contains <あってはいけない部分文字列> <実際の文字列> <ラベル>
assert_not_contains() {
  case "$2" in
    *"$1"*) fail "$3: unexpected=$1" ;;
    *) pass ;;
  esac
}

# assert_jq <期待する値> <jq のフィルタ> <パス>
assert_jq() {
  expected=$1
  filter=$2
  path=$3
  actual=$(jq -r "$filter" "$path" 2> /dev/null)
  if [ "$actual" = "$expected" ]; then
    pass
  else
    fail "jq: expected=$expected actual=$actual ($filter of $path)"
  fi
}

# assert_symlink <期待するリンク先> <パス>
assert_symlink() {
  if [ "$(readlink "$2")" = "$1" ]; then
    pass
  else
    fail "symlink: $2 -> $(readlink "$2") (expected $1)"
  fi
}

T=$(mktemp -d)
trap '/bin/rm -rf -- "$T"' EXIT

SRC="$DOTFILES/karabiner/profile-defaults.json"
PROFILE=$(jq -r '.name' "$SRC")

# run_install <HOME> — 単体実行と同じく notice がその場の標準出力へ出る
run_install() {
  HOME="$1" DOTFILES_NOTICES='' sh "$DOTFILES/karabiner/install.sh" 2>&1
}

# 検証用の karabiner.json を組み立てる。
#   write_config <HOME> <profiles の JSON>
write_config() {
  mkdir -p "$1/.config/karabiner"
  jq -n --argjson p "$2" '{global: {check_for_updates_on_startup: true}, profiles: $p}' \
    > "$1/.config/karabiner/karabiner.json"
}

# 共有したいキーを持たない素のプロファイル
bare_profile() {
  jq -n --arg n "$PROFILE" '[{name: $n, selected: true, complex_modifications: {rules: []}}]'
}

# --- karabiner.json が無い: リンクは張るが設定ファイルは作らない ---
H="$T/case1"
mkdir -p "$H"
out=$(run_install "$H")
assert_symlink "$DOTFILES/karabiner/Naginata.json" "$H/.config/karabiner/assets/complex_modifications/Naginata.json"
assert_symlink "$DOTFILES/karabiner/Personal.json" "$H/.config/karabiner/assets/complex_modifications/Personal.json"
# Karabiner の起動前に profiles が空の設定ファイルを置かない
if [ -e "$H/.config/karabiner/karabiner.json" ]; then
  fail "karabiner.json を先回りで作っている"
else
  pass
fi
assert_contains "一度起動してから" "$out" "未起動の案内"

# --- プロファイルがある: 共有キーが入り、他のキーは残る ---
H="$T/case2"
write_config "$H" "$(bare_profile)"
out=$(run_install "$H")
CONFIG="$H/.config/karabiner/karabiner.json"
assert_contains "[merged]" "$out" "マージのタグ"
assert_jq "japanese_eisuu" '.profiles[0].devices[0].simple_modifications[0].from.key_code' "$CONFIG"
assert_jq "jis" '.profiles[0].virtual_hid_keyboard.keyboard_type_v2' "$CONFIG"
# Karabiner 自身が書くキーは触らない
assert_jq "true" '.global.check_for_updates_on_startup' "$CONFIG"
assert_jq "true" '.profiles[0].selected' "$CONFIG"
# complex_modifications の rules は assets/ 側の管轄なので書き込まない
assert_jq "0" '.profiles[0].complex_modifications.rules | length' "$CONFIG"
# 未有効のルールは TODO へ回る
assert_contains "Personal.json" "$out" "未有効ルールのファイル名"
assert_contains "Post Escape if Command_R is pressed alone." "$out" "未有効ルールの description"
# Naginata.json は必要なときに選ぶ置き場なので、未有効でも TODO に出さない
assert_not_contains "Naginata.json の以下を有効化" "$out" "薙刀式は対象外"

# --- 2 回目: 冪等（内容が変わらない） ---
before=$(jq -S . "$CONFIG")
run_install "$H" > /dev/null
assert_eq "$before" "$(jq -S . "$CONFIG")" "2 回目の内容"

# --- Personal.json を有効化済み: 薙刀式が未有効でも TODO は空になる ---
H="$T/case3"
rules=$(jq '[.rules[]]' "$DOTFILES/karabiner/Personal.json")
write_config "$H" "$(jq -n --arg n "$PROFILE" --argjson a "$rules" \
  '[{name: $n, complex_modifications: {rules: $a}}]')"
out=$(run_install "$H")
assert_not_contains "Add rule" "$out" "有効化済みなら案内を出さない"

# --- プロファイル名が違う: 触らずに TODO を出す ---
H="$T/case4"
write_config "$H" '[{"name":"Other profile","devices":[],"complex_modifications":{"rules":[]}}]'
out=$(run_install "$H")
CONFIG="$H/.config/karabiner/karabiner.json"
assert_jq "0" '.profiles[0].devices | length' "$CONFIG"
assert_jq "null" '.profiles[0].virtual_hid_keyboard' "$CONFIG"
assert_contains "$PROFILE" "$out" "プロファイル不在の案内"

# --- 共有するプロファイルが複数ある中の 1 つ: 他のプロファイルは触らない ---
H="$T/case5"
write_config "$H" "$(jq -n --arg n "$PROFILE" \
  '[{name: "Other profile", devices: [{identifiers: {is_pointing_device: true}}]},
    {name: $n, complex_modifications: {rules: []}}]')"
run_install "$H" > /dev/null
CONFIG="$H/.config/karabiner/karabiner.json"
assert_jq "true" '.profiles[0].devices[0].identifiers.is_pointing_device' "$CONFIG"
assert_jq "jis" '.profiles[1].virtual_hid_keyboard.keyboard_type_v2' "$CONFIG"

# --- マシン固有のデバイス設定がある: 配列は置換されるので [dropped] で知らせる ---
H="$T/case6"
write_config "$H" "$(jq -n --arg n "$PROFILE" \
  '[{name: $n,
     devices: [{identifiers: {vendor_id: 1234, product_id: 5678}, simple_modifications: []}],
     complex_modifications: {rules: []}}]')"
out=$(run_install "$H")
assert_contains "[dropped]" "$out" "配列消失の検出"
assert_contains "1234" "$out" "消える要素の中身"
assert_contains "恒久化" "$out" "復旧手順"

# --- ルート経由（DOTFILES_NOTICES あり）: 案内は標準出力ではなく受け皿へ積む ---
H="$T/case7"
notices="$T/notices"
: > "$notices"
write_config "$H" "$(bare_profile)"
out=$(HOME="$H" DOTFILES_NOTICES="$notices" sh "$DOTFILES/karabiner/install.sh" 2>&1)
assert_not_contains "Add rule" "$out" "ルート経由で案内が標準出力へ漏れていない"
assert_contains "Add rule" "$(cat "$notices")" "受け皿の内容"

# --- dotfiles 側の json は書き換わっていない ---
assert_jq "$PROFILE" '.name' "$SRC"
assert_jq "Personal rules" '.title' "$DOTFILES/karabiner/Personal.json"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
