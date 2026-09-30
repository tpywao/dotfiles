#! /bin/sh
# claude/install.sh の merge_claude_settings が hooks をどう組み立てるかを検証する。
#
#   sh tests/claude/merge-claude-settings_test.sh
#
# claude と gh をスタブに差し替え、$HOME は mktemp した偽ホームへ向けるので実際の
# ~/.claude/ も状態ファイルも触らない。dotfiles 側の hooks は実物の
# claude/settings.json を使い、期待値もそこから jq で取る（hook の増減でテストが
# 壊れないようにするため）。
#
# 他のアプリが足した hook を残すこと、dotfiles が前回配って今回は無い hook を
# 消すことの両立がこの関数の主旨なので、既存の設定と状態ファイルの組み合わせごとに
# ケースを置いている。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)

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

# assert_equals <期待する文字列> <実際の文字列> <ラベル>
assert_equals() {
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "$3: expected=$1 actual=$2"
  fi
}

# assert_not_contains <あってはいけない部分文字列> <実際の文字列> <ラベル>
assert_not_contains() {
  case "$2" in
    *"$1"*) fail "$3: unexpected=$1 actual=$2" ;;
    *) pass ;;
  esac
}

T=$(mktemp -d)
STUB="$T/stub"
mkdir -p "$STUB"
# claude が無いと install.sh が対話プロンプトに入る。gh は未認証にして外部スキルの
# 導入を飛ばす（ネットワークへ出さない）
printf '#! /bin/sh\nexit 0\n' > "$STUB/claude"
printf '#! /bin/sh\nexit 1\n' > "$STUB/gh"
chmod +x "$STUB/claude" "$STUB/gh"

SRC="$DOTFILES/claude/settings.json"

# run_install <偽ホーム>
run_install() {
  HOME="$1" PATH="$STUB:$PATH" XDG_STATE_HOME='' DOTFILES_NOTICES="$T/notices" \
    sh "$DOTFILES/claude/install.sh" 2>&1
}

# settings_of <偽ホーム> / state_of <偽ホーム>
settings_of() { printf '%s' "$1/.claude/settings.json"; }
state_of() { printf '%s' "$1/.local/state/dotfiles/claude-hooks.json"; }

# hook_count <jq で選ぶ hook の条件> <ファイル> — 全イベントを通した一致件数
hook_count() {
  jq --argjson h "$1" '[.hooks[][] | .hooks[] | select(. == $h)] | length' "$2"
}

# dotfiles 側の hook を 1 つ取る（これが「dotfiles 由来」の代表）
shared_event=$(jq -r '.hooks | keys_unsorted[0]' "$SRC")
shared_hook=$(jq -c --arg e "$shared_event" '.hooks[$e][0].hooks[0]' "$SRC")
shared_total=$(jq '[.hooks[][] | .hooks[]] | length' "$SRC")

# 中の $HOME は展開させず、文字列のまま hook の command として比べる
# shellcheck disable=SC2016
FOREIGN_HOOK='{"type":"command","command":"$HOME/.other-app/hook.sh","timeout":10}'
# shellcheck disable=SC2016
STALE_HOOK='{"type":"command","command":"$HOME/.claude/hooks/removed-from-dotfiles.sh"}'

# --- 既存の設定が無い: dotfiles 側の hooks をそのまま配り、状態ファイルを作る ---
H="$T/home1"
out=$(run_install "$H")
assert_equals "$(jq -S .hooks "$SRC")" "$(jq -S .hooks "$(settings_of "$H")")" "新規は dotfiles 側と同じ"
assert_equals "$shared_total" "$(jq length "$(state_of "$H")")" "配った hook を記録する"

# --- 他のアプリの hook がある: 残し、[dropped] を出さない ---
H="$T/home2"
mkdir -p "$H/.claude"
jq -n --argjson f "$FOREIGN_HOOK" --arg e "$shared_event" \
  '{hooks: {($e): [{matcher: "*", hooks: [$f]}], Notification: [{hooks: [$f]}]}}' \
  > "$(settings_of "$H")"
out=$(run_install "$H")
assert_not_contains "[dropped]" "$out" "他のアプリの hook は消えない"
assert_equals "2" "$(hook_count "$FOREIGN_HOOK" "$(settings_of "$H")")" "他のアプリの hook が残る"
assert_equals "1" "$(hook_count "$shared_hook" "$(settings_of "$H")")" "dotfiles 側の hook も入る"
# dotfiles 側に無いイベントも残る
assert_equals "1" "$(jq '.hooks.Notification | length' "$(settings_of "$H")")" "dotfiles 側に無いイベント"
# 他のアプリの hook は記録しない（記録すると次回から消される）
assert_equals "0" "$(jq --argjson h "$FOREIGN_HOOK" '[.[] | select(. == $h)] | length' "$(state_of "$H")")" \
  "他のアプリの hook を記録しない"

# --- 再実行: dotfiles 側の hook が重複して増えない ---
before=$(jq -S .hooks "$(settings_of "$H")")
out=$(run_install "$H")
assert_equals "$before" "$(jq -S .hooks "$(settings_of "$H")")" "再実行で変わらない"
assert_not_contains "[dropped]" "$out" "再実行で [dropped] を出さない"

# --- 前回配って今回は無い hook: 状態ファイルに載っていれば消す ---
H="$T/home3"
mkdir -p "$H/.claude" "$(dirname "$(state_of "$H")")"
jq -n --argjson s "$STALE_HOOK" '{hooks: {Stop: [{hooks: [$s]}]}}' > "$(settings_of "$H")"
jq -n --argjson s "$STALE_HOOK" '[$s]' > "$(state_of "$H")"
out=$(run_install "$H")
assert_equals "0" "$(hook_count "$STALE_HOOK" "$(settings_of "$H")")" "記録済みの hook は消える"
# 消えた hook も記録に残す（別のマシンの状態から戻ってきても消せるように）
assert_equals "1" "$(jq --argjson h "$STALE_HOOK" '[.[] | select(. == $h)] | length' "$(state_of "$H")")" \
  "記録は積み増す"

# --- 状態ファイルが無い: 記録に無い hook は消さない ---
H="$T/home4"
mkdir -p "$H/.claude"
jq -n --argjson s "$STALE_HOOK" '{hooks: {Stop: [{hooks: [$s]}]}}' > "$(settings_of "$H")"
out=$(run_install "$H")
assert_equals "1" "$(hook_count "$STALE_HOOK" "$(settings_of "$H")")" "記録が無ければ残す"

# --- 1 つのグループに dotfiles 由来と他のアプリの hook が混ざる: hook 単位で分ける ---
H="$T/home5"
mkdir -p "$H/.claude"
jq -n --argjson s "$shared_hook" --argjson f "$FOREIGN_HOOK" --arg e "$shared_event" \
  '{hooks: {($e): [{matcher: "Old", hooks: [$s, $f]}]}}' > "$(settings_of "$H")"
out=$(run_install "$H")
assert_equals "1" "$(hook_count "$shared_hook" "$(settings_of "$H")")" "混在でも dotfiles 側は 1 件"
assert_equals "1" "$(hook_count "$FOREIGN_HOOK" "$(settings_of "$H")")" "混在でも他のアプリの hook は残る"
assert_equals '["Old"]' \
  "$(jq -c --argjson f "$FOREIGN_HOOK" '[.hooks[][] | select(.hooks | index([$f])) | .matcher]' "$(settings_of "$H")")" \
  "他のアプリの hook は元のグループに残る"

# --- hooks 以外のキーは従来どおり再帰マージ ---
H="$T/home6"
mkdir -p "$H/.claude"
echo '{"effortLevel":"high"}' > "$(settings_of "$H")"
out=$(run_install "$H")
assert_equals "high" "$(jq -r .effortLevel "$(settings_of "$H")")" "マシン固有キーが残る"

# --- 中間ファイルを残さない ---
if [ -z "$(find "$T" -name '*.tmp' -o -name '*.merging.*')" ]; then
  pass
else
  fail "中間ファイルが残っている"
fi

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
