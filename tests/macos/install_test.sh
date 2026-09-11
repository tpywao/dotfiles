#! /bin/sh
# macos/install.sh の書き込み判定を検証する。
#
#   sh tests/macos/install_test.sh
#
# 実機の defaults は触らない。PATH の先頭へ defaults / killall のスタブを置き、
# 値は mktemp した疑似ストアに持つ。スタブの defaults は実機と同じく
# `-bool` に 1/0 を渡されたら usage を出して失敗するので、書き込みの型が
# 間違っていればここで落ちる。
#
# 見るのは 2 点。1 回目に全ての write_* 行が実際に書き込むこと、2 回目に
# 1 件も書かないこと（現在値との比較が効いていること）。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

is_mac || {
  echo "skip: macOS 専用のため"
  exit 0
}

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

# assert_count_tag <期待する個数> <タグ> <出力>
assert_count_tag() {
  actual=$(printf '%s\n' "$3" | grep -c -- "$2")
  assert_eq "$1" "$actual" "tag $2"
}

T=$(mktemp -d)
trap '/bin/rm -rf -- "$T"' EXIT

STUB_STORE="$T/store"
export STUB_STORE
mkdir -p "$T/bin" "$STUB_STORE"

# 疑似 defaults。<ドメイン>.<キー> のファイルに値を持つ。
# bool は実機と同じく true/false で受けて 1/0 で返す
cat > "$T/bin/defaults" << 'STUB'
#! /bin/sh
store=$STUB_STORE
case $1 in
  read)
    [ -f "$store/$2.$3" ] || exit 1
    cat "$store/$2.$3"
    ;;
  write)
    domain=$2
    key=$3
    type=$4
    value=$5
    if [ "$type" = "-bool" ]; then
      case $value in
        true | yes) value=1 ;;
        false | no) value=0 ;;
        *)
          echo "usage: defaults write ... -bool (true | false | yes | no)" >&2
          exit 1
          ;;
      esac
    fi
    printf '%s' "$value" > "$store/$domain.$key"
    echo "$domain $key" >> "$store/.writes"
    ;;
  import)
    echo "$2 $3" >> "$store/.imports"
    ;;
  *)
    echo "unexpected: $*" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$T/bin/defaults"

printf '#! /bin/sh\nexit 0\n' > "$T/bin/killall"
chmod +x "$T/bin/killall"

PATH="$T/bin:$PATH"
export PATH

# install.sh が持つ write_* の行数。キーを増やしてもテスト側の修正は要らない
expected_writes=$(grep -c '^write_bool \|^write_default ' "$DOTFILES/macos/install.sh")
domain_count=$(grep -c '^report_domain ' "$DOTFILES/macos/install.sh")
import_count=$(grep -c '^import_defaults ' "$DOTFILES/macos/install.sh")

# --- 1 回目: 値がまだ無いので全件書き込む ---
out=$(sh "$DOTFILES/macos/install.sh")
assert_eq "$expected_writes" "$(wc -l < "$STUB_STORE/.writes" | tr -d ' ')" "1 回目の書き込み件数"
assert_count_tag "$domain_count" "\[applied\]" "$out"
assert_count_tag 0 "\[current\]" "$out"
assert_count_tag 0 "\[failed\]" "$out"
assert_count_tag "$import_count" "\[imported\]" "$out"

# --- 2 回目: 現在値と一致するので 1 件も書かない ---
: > "$STUB_STORE/.writes"
out=$(sh "$DOTFILES/macos/install.sh")
assert_eq 0 "$(wc -l < "$STUB_STORE/.writes" | tr -d ' ')" "2 回目の書き込み件数"
assert_count_tag "$domain_count" "\[current\]" "$out"
assert_count_tag 0 "\[applied\]" "$out"
assert_count_tag 0 "\[failed\]" "$out"

# --- 1 件だけ値を変えると、そのドメインだけ [applied] に戻る ---
: > "$STUB_STORE/.writes"
printf 'bottom' > "$STUB_STORE/com.apple.dock.orientation"
out=$(sh "$DOTFILES/macos/install.sh")
assert_eq 1 "$(wc -l < "$STUB_STORE/.writes" | tr -d ' ')" "1 件変更後の書き込み件数"
assert_count_tag 1 "\[applied\]" "$out"
assert_eq "left" "$(cat "$STUB_STORE/com.apple.dock.orientation")" "orientation の復元"

# --- plist は import 経由で、生成物として lint が通ること ---
assert_lint() {
  if plutil -lint "$1" > /dev/null 2>&1; then
    pass
  else
    fail "lint: $1"
  fi
}

assert_lint "$DOTFILES/macos/symbolichotkeys.plist"
assert_lint "$DOTFILES/macos/input-sources.plist"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
