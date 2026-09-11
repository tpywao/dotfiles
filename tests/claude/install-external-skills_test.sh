#! /bin/sh
# claude/install.sh の install_external_skills をケースごとに検証する。
#
#   sh tests/claude/install-external-skills_test.sh
#
# gh をスタブに差し替え、$HOME は mktemp した偽ホームへ向けるのでネットワークへは
# 出ず、実際の ~/.claude/ も触らない。gh の認証状態と gh skill install の成否で
# 経路が分かれるため、経路ごとに「出力タグ」「SKILL.md の後始末」「gh skill install
# を呼んだかどうか」「積まれた TODO」を確認する。
#
# 成否の直後に再実行するケースを置いているのは、失敗した導入が「導入済み」と
# 判定されて固定されないことが、この関数で一番壊れやすいため。

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd -P)

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

# assert_not_contains <あってはいけない部分文字列> <実際の文字列> <ラベル>
assert_not_contains() {
  case "$2" in
    *"$1"*) fail "$3: unexpected=$1 actual=$2" ;;
    *) pass ;;
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
STUB="$T/stub"
mkdir -p "$STUB"

# claude が無いと install.sh が対話プロンプトに入るのでスタブを置く
printf '#! /bin/sh\nexit 0\n' > "$STUB/claude"
chmod +x "$STUB/claude"

# stub_gh <authed|unauthed> <install の終了ステータス>
# gh skill install は呼ばれたことを $T/called に記録する。実物は途中で落ちても
# SKILL.md だけは書いていることがあるので、失敗時も frontmatter を書く
stub_gh() {
  cat > "$STUB/gh" <<GH
#! /bin/sh
if [ "\$1 \$2" = "auth token" ]; then
  [ "$1" = "authed" ] && exit 0
  exit 1
fi
if [ "\$1 \$2" = "skill install" ]; then
  echo "\$4" >> "$T/called"
  dst="\$HOME/.claude/skills/\$4"
  mkdir -p "\$dst"
  printf 'metadata:\n    github-ref: refs/tags/%s\n' "\$6" > "\$dst/SKILL.md"
  exit $2
fi
exit 1
GH
  chmod +x "$STUB/gh"
}

# run_install <偽ホーム> <TODO の受け皿>
# 受け皿は先に空で作る。ルートの install.sh が mktemp で作ってから渡すのと
# 揃えるため（notice() が一度も呼ばれない経路でも空ファイルが残る）
run_install() {
  : > "$T/called"
  : > "$2"
  HOME="$1" PATH="$STUB:$PATH" DOTFILES_NOTICES="$2" \
    sh "$DOTFILES/claude/install.sh" 2>&1
}

# 最初のスキル名を Skillfile から取る（マニフェストの中身に依存しないため）
first_skill=$(awk '$1 !~ /^#/ && NF >= 3 { print $2; exit }' "$DOTFILES/claude/Skillfile")

# --- gh が未認証: 導入を丸ごと飛ばし、gh skill install を呼ばない ---
stub_gh unauthed 0
out=$(run_install "$T/home1" "$T/notices1")
assert_contains "[skipped]" "$out" "未認証のタグ"
assert_equals "" "$(cat "$T/called")" "未認証で gh skill install を呼ばない"
assert_contains "gh auth login" "$(cat "$T/notices1")" "未認証の TODO"

# --- 導入に失敗: SKILL.md を消して [failed]、TODO を積む ---
stub_gh authed 1
out=$(run_install "$T/home2" "$T/notices2")
assert_contains "[failed]" "$out" "失敗のタグ"
assert_not_contains "[installed]" "$out" "失敗時に [installed] を出さない"
assert_equals "" "$(find "$T/home2/.claude/skills" -name SKILL.md -path '*/'"$first_skill"'/*' 2>/dev/null)" \
  "失敗時に SKILL.md を残さない"
assert_contains "./claude/install.sh" "$(cat "$T/notices2")" "失敗の TODO"

# --- 失敗の直後に再実行: 導入済みと見なさず再試行する ---
out=$(run_install "$T/home2" "$T/notices2b")
assert_contains "$first_skill" "$(cat "$T/called")" "失敗後は再試行する"

# --- 導入に成功: [installed] を出し、TODO は積まない ---
stub_gh authed 0
out=$(run_install "$T/home3" "$T/notices3")
assert_contains "[installed]" "$out" "成功のタグ"
assert_not_contains "[failed]" "$out" "成功時に [failed] を出さない"
assert_equals "" "$(cat "$T/notices3")" "成功時に TODO を積まない"

# --- 成功の直後に再実行: pin が一致するので gh skill install を呼ばない ---
out=$(run_install "$T/home3" "$T/notices3b")
assert_contains "[installed]" "$out" "再実行時のタグ"
assert_equals "" "$(cat "$T/called")" "pin が一致すれば呼び直さない"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
