#! /bin/sh
# utils/install-common.sh の merge_config() をケースごとに検証する。
#
#   sh tests/utils/merge-config_test.sh
#
# $HOME は書き換えず、mktemp した一時ディレクトリだけを対象にする。
# 配布先（dst）の状態と jq フィルタの有無で経路が分かれるため、経路ごとに
# 「出力タグ」「マージ後の内容」「src を書き換えていないこと」を確認する。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

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

# assert_tag <期待するタグ> <merge_config の出力>
# 出力には色コードが混ざるので部分一致で見る
assert_tag() {
  expected=$1
  output=$2
  case "$output" in
    *"$expected"*) pass ;;
    *) fail "tag: expected=$expected output=$output" ;;
  esac
}

# assert_no_tag <出てはいけないタグ> <merge_config の出力>
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

# assert_empty <merge_config の出力>
assert_empty() {
  if [ -z "$1" ]; then
    pass
  else
    fail "output: 空を期待したが '$1'"
  fi
}

# assert_missing <あってはいけないパス>
assert_missing() {
  if [ -e "$1" ]; then
    fail "missing: $1 が存在する"
  else
    pass
  fi
}

# assert_tag_count <期待する行数> <タグ> <merge_config の出力>
# タグは [] を含むので grep -F で固定文字列として数える
assert_tag_count() {
  expected=$1
  tag=$2
  output=$3
  actual=$(printf '%s\n' "$output" | grep -cF -- "$tag")
  if [ "$actual" -eq "$expected" ]; then
    pass
  else
    fail "tag count: expected=$expected actual=$actual tag=$tag"
  fi
}

# premerge_file <dst> — 退避ファイルのパスを出す。無ければ空
premerge_file() {
  find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").premerge.*" 2> /dev/null | head -1
}

# assert_premerge <dst>
assert_premerge() {
  if [ -n "$(premerge_file "$1")" ]; then
    pass
  else
    fail "premerge: $1.premerge.* が無い"
  fi
}

# assert_no_premerge <dst>
assert_no_premerge() {
  if [ -n "$(premerge_file "$1")" ]; then
    fail "premerge: $1.premerge.* が作られている"
  else
    pass
  fi
}

T=$(mktemp -d)
mkdir -p "$T/src" "$T/home"
echo '{"shared":"from-dotfiles"}' > "$T/src/config.json"
SRC="$T/src/config.json"

# --- dst が無い: src の内容で作って [merged] ---
out=$(merge_config "$SRC" "$T/home/case1.json")
assert_tag "[merged]" "$out"
assert_jq "from-dotfiles" '.shared' "$T/home/case1.json"

# --- dst にマシン固有キーがある: 固有キーが残り、共有キーが足される ---
echo '{"machineOnly":"keep-me"}' > "$T/home/case2.json"
out=$(merge_config "$SRC" "$T/home/case2.json")
assert_tag "[merged]" "$out"
assert_jq "keep-me" '.machineOnly' "$T/home/case2.json"
assert_jq "from-dotfiles" '.shared' "$T/home/case2.json"

# --- 共有キーが dst にもある: src の値で上書きされる ---
echo '{"shared":"locally-edited"}' > "$T/home/case3.json"
out=$(merge_config "$SRC" "$T/home/case3.json")
assert_tag "[merged]" "$out"
assert_jq "from-dotfiles" '.shared' "$T/home/case3.json"

# --- dst のネストしたキーは消えない（認証情報のような値を守る） ---
echo '{"auths":{"registry.example.com":{"auth":"dummy"}}}' > "$T/home/case4.json"
out=$(merge_config "$SRC" "$T/home/case4.json")
assert_tag "[merged]" "$out"
assert_jq "dummy" '.auths["registry.example.com"].auth' "$T/home/case4.json"

# --- dst が symlink: 実体へ戻してからマージする ---
# リンク先が書き換えられないことも確認する
echo '{"machineOnly":"written-through-link"}' > "$T/link-target.json"
ln -s "$T/link-target.json" "$T/home/case5.json"
out=$(merge_config "$SRC" "$T/home/case5.json")
assert_tag "[unlinked]" "$out"
assert_tag "[merged]" "$out"
assert_not_symlink "$T/home/case5.json"
# リンク経由で書き込まれていた値を引き継ぐ
assert_jq "written-through-link" '.machineOnly' "$T/home/case5.json"
assert_jq "from-dotfiles" '.shared' "$T/home/case5.json"
# リンク先は無傷
assert_jq "null" '.shared' "$T/link-target.json"

# --- 2 回目の実行: symlink は残っていないので [unlinked] は出ない ---
out=$(merge_config "$SRC" "$T/home/case5.json")
assert_tag "[merged]" "$out"
assert_no_tag "[unlinked]" "$out"
assert_jq "written-through-link" '.machineOnly' "$T/home/case5.json"

# --- jq フィルタを渡す: 既定の再帰マージではなく差し替えになる ---
# 既定では dst 側のネストしたキーが残るが、フィルタで src 側に寄せられる
echo '{"replaceMe":{"dst-only":1},"machineOnly":"keep-me"}' > "$T/home/case7.json"
echo '{"replaceMe":{"src-only":2}}' > "$T/src/filtered.json"
# $live / $shared は jq の変数。シェルに展開させない
# shellcheck disable=SC2016
out=$(merge_config "$T/src/filtered.json" "$T/home/case7.json" '
  .[0] as $live | .[1] as $shared
  | ($live * $shared)
  | .replaceMe = $shared.replaceMe
')
assert_tag "[merged]" "$out"
assert_jq "null" '.replaceMe["dst-only"]' "$T/home/case7.json"
assert_jq "2" '.replaceMe["src-only"]' "$T/home/case7.json"
# フィルタで触っていないキーは既定どおり残る
assert_jq "keep-me" '.machineOnly' "$T/home/case7.json"

# --- src が無い: 何もしない（dst を作らない） ---
out=$(merge_config "$T/src/absent.json" "$T/home/case8.json")
assert_empty "$out"
assert_missing "$T/home/case8.json"

# --- 親ディレクトリが無い: mkdir -p してからマージする ---
out=$(merge_config "$SRC" "$T/home/nested/deep/case9.json")
assert_tag "[merged]" "$out"
assert_jq "from-dotfiles" '.shared' "$T/home/nested/deep/case9.json"

# --- dst 側にしか無い配列要素: 失われる前に [dropped] で知らせて退避する ---
# jq の `*` は配列を再帰マージせず右辺で置換するため、dst 側にしか無い要素は
# 黙って消える。これを検出できることがこのケースの主旨
echo '{"permissions":{"allow":["machine-only","shared-a"]}}' > "$T/home/case10.json"
echo '{"permissions":{"allow":["shared-a","shared-b"]}}' > "$T/src/arr.json"
out=$(merge_config "$T/src/arr.json" "$T/home/case10.json")
assert_tag "[dropped]" "$out"
assert_tag "permissions.allow" "$out"
assert_tag "machine-only" "$out"
# 検出しても中断はしない（各サブ install を止めない規約に合わせる）
assert_tag "[merged]" "$out"
assert_jq "shared-a shared-b" '.permissions.allow | join(" ")' "$T/home/case10.json"
# 退避ファイルにマージ前の内容が残る
assert_premerge "$T/home/case10.json"
assert_jq "machine-only shared-a" '.permissions.allow | join(" ")' "$(premerge_file "$T/home/case10.json")"

# --- 警告に復旧手順が載る: 恒久化（src へ追記）と復旧（退避から戻す）の 2 経路 ---
assert_tag "恒久化" "$out"
assert_tag "復旧" "$out"
assert_tag "$T/src/arr.json" "$out"

# --- dst の配列が src の部分集合: 失うものが無いので警告も退避もしない ---
echo '{"permissions":{"allow":["shared-a"]}}' > "$T/home/case11.json"
out=$(merge_config "$T/src/arr.json" "$T/home/case11.json")
assert_tag "[merged]" "$out"
assert_no_tag "[dropped]" "$out"
assert_no_premerge "$T/home/case11.json"

# --- jq フィルタで差し替える場合も検出する（hooks の丸ごと差し替え相当） ---
# 検出はフィルタ適用後の結果と比較するので、フィルタが何をするかに依存しない
echo '{"hooks":{"PreToolUse":[{"shared":1},{"machineHook":true}]}}' > "$T/home/case12.json"
echo '{"hooks":{"PreToolUse":[{"shared":1}]}}' > "$T/src/hooks.json"
# $live / $shared は jq の変数。シェルに展開させない
# shellcheck disable=SC2016
out=$(merge_config "$T/src/hooks.json" "$T/home/case12.json" '
  .[0] as $live | .[1] as $shared
  | ($live * $shared)
  | .hooks = $shared.hooks
')
assert_tag "[dropped]" "$out"
assert_tag "hooks.PreToolUse" "$out"
assert_tag '{"machineHook":true}' "$out"
assert_premerge "$T/home/case12.json"

# --- 入れ子の配列: 親を報告したら子孫は重複して報告しない ---
echo '{"outer":[{"inner":["x","machine-only"]}]}' > "$T/home/case13.json"
echo '{"outer":[]}' > "$T/src/nested.json"
out=$(merge_config "$T/src/nested.json" "$T/home/case13.json")
assert_tag "[dropped]" "$out"
assert_tag_count 1 "[dropped]" "$out"
assert_tag "outer" "$out"

# --- src は一度も書き換わっていない ---
assert_jq "from-dotfiles" '.shared' "$SRC"
assert_jq "null" '.machineOnly' "$SRC"

# --- 中間ファイルを残さない ---
if [ -z "$(find "$T" -name '*.merging.*' -o -name '*.unlinking.*')" ]; then
  pass
else
  fail "中間ファイルが残っている"
fi

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
