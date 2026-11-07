#! /bin/sh
# claude/install.sh の link_claude_skills をケースごとに検証する。
#
#   sh tests/claude/link-claude-skills_test.sh
#
# claude/ と utils/ を一時ディレクトリへ複製して、そこから実行する。$HOME も偽ホーム
# へ向けるので、実際の ~/.claude/ もリポジトリも触らない。除外を誤るとディレクトリの
# リンク越しに dotfiles 側のファイルが消えるため、複製を対象にしている。

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

# assert_readlink <期待するリンク先> <パス> <ラベル>
assert_readlink() {
  actual=$(readlink "$2" 2>/dev/null)
  if [ "$actual" = "$1" ]; then
    pass
  else
    fail "$3: expected=$1 actual=$actual"
  fi
}

# assert_true <ラベル> <コマンド...>
assert_true() {
  label=$1
  shift
  if "$@"; then
    pass
  else
    fail "$label"
  fi
}

T=$(cd "$(mktemp -d)" && pwd -P)
STUB="$T/stub"
mkdir -p "$STUB"

# claude が無いと install.sh が対話プロンプトに入るのでスタブを置く。
# gh は未認証にして外部スキルの導入を飛ばし、ネットワークへ出ない
printf '#! /bin/sh\nexit 0\n' > "$STUB/claude"
chmod +x "$STUB/claude"
printf '#! /bin/sh\nexit 1\n' > "$STUB/gh"
chmod +x "$STUB/gh"

REPO="$T/repo"
mkdir -p "$REPO"
cp -R "$DOTFILES/claude" "$DOTFILES/utils" "$REPO/"

# スキルの実体を揃える。fresh は未リンク、legacy はファイル単位のリンクが残った状態、
# edited は実ファイルが混ざった状態の移行元として使う
for skill in fresh legacy edited; do
  mkdir -p "$REPO/claude/skills/$skill/references"
  printf '%s\n' "$skill" > "$REPO/claude/skills/$skill/SKILL.md"
  printf 'ref\n' > "$REPO/claude/skills/$skill/references/a.md"
done

H="$T/home"
SKILLS="$H/.claude/skills"
mkdir -p "$SKILLS/legacy/references" "$SKILLS/edited" "$SKILLS/external"
ln -s "$REPO/claude/skills/legacy/SKILL.md" "$SKILLS/legacy/SKILL.md"
ln -s "$REPO/claude/skills/legacy/references/a.md" "$SKILLS/legacy/references/a.md"
ln -s "$REPO/claude/skills/edited/SKILL.md" "$SKILLS/edited/SKILL.md"
printf 'local edit\n' > "$SKILLS/edited/notes.md"
printf 'external\n' > "$SKILLS/external/SKILL.md"

run_install() {
  HOME="$H" DOTFILES_NOTICES='' PATH="$STUB:$PATH" sh "$REPO/claude/install.sh" 2>&1
}

out=$(run_install)

# 未作成
assert_readlink "$REPO/claude/skills/fresh" "$SKILLS/fresh" "未作成のスキルをディレクトリごと張る"

# 中身が dotfiles へのリンクだけの実ディレクトリ
assert_readlink "$REPO/claude/skills/legacy" "$SKILLS/legacy" "ファイル単位のリンクを張り替える"
assert_contains "[unlinked]" "$out" "張り替えのタグ"
if ls -d "$SKILLS"/legacy.presymlink.* > /dev/null 2>&1; then
  fail "リンクだけのディレクトリを退避しない"
else
  pass
fi

# 実ファイルが混ざった実ディレクトリ
assert_readlink "$REPO/claude/skills/edited" "$SKILLS/edited" "実ファイルが混ざっていても張る"
backup=$(ls -d "$SKILLS"/edited.presymlink.* 2>/dev/null | head -n 1)
assert_true "退避先に手元の編集が残る" [ -f "$backup/notes.md" ]
assert_contains "退避したスキルがある" "$out" "退避の TODO"
assert_contains "$backup" "$out" "退避先のパスを TODO に出す"

# 管理外のスキル
assert_true "管理外のスキルを実ディレクトリのまま残す" [ ! -L "$SKILLS/external" ]
assert_true "管理外のスキルの中身を残す" [ -f "$SKILLS/external/SKILL.md" ]

# 除外が効いていれば、リンク越しに dotfiles 側のファイルを張り替えない
assert_true "dotfiles 側の SKILL.md が実ファイルのまま" \
  [ -f "$REPO/claude/skills/fresh/SKILL.md" -a ! -L "$REPO/claude/skills/fresh/SKILL.md" ]

# スキルの外はファイル単位のまま
first=$(find "$REPO/claude/hooks" -type f | head -n 1)
assert_readlink "$first" "$H/.claude/hooks/${first##*/}" "スキルの外はファイル単位で張る"

# ディレクトリのリンクなので、後から足したファイルは再実行なしに見える
printf 'new\n' > "$REPO/claude/skills/fresh/references/b.md"
assert_true "後から足したファイルが見える" [ -f "$SKILLS/fresh/references/b.md" ]

# 2 回目の実行では何も動かない
backups_before=$(find "$SKILLS" -mindepth 1 -maxdepth 1 -name '*.presymlink.*' | wc -l)
out=$(run_install)
backups_after=$(find "$SKILLS" -mindepth 1 -maxdepth 1 -name '*.presymlink.*' | wc -l)
assert_true "2 回目は退避を増やさない" [ "$backups_before" -eq "$backups_after" ]
assert_contains "[linked]" "$out" "2 回目のタグ"
case "$out" in
  *'(ファイル単位のリンク)'*) fail "2 回目は張り替えない" ;;
  *) pass ;;
esac

# dotfiles 側で消したスキルのリンクは prune_claude_links が片付ける
/bin/rm -r -- "$REPO/claude/skills/fresh"
out=$(run_install)
if [ -L "$SKILLS/fresh" ]; then
  fail "消したスキルのリンクを片付ける"
else
  pass
fi

/bin/rm -r -- "$T"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
