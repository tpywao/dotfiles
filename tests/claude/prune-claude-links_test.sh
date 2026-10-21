#! /bin/sh
# claude/install.sh の prune_claude_links をケースごとに検証する。
#
#   sh tests/claude/prune-claude-links_test.sh
#
# $HOME は mktemp した偽ホームへ向けるので、実際の ~/.claude/ は触らない。
# 消してよいのは「dotfiles の claude/ を指していて、リンク先が無い」リンクだけ。
# 条件のどちらか一方しか満たさないリンクを並べ、消しすぎないことを確認する。

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

# assert_link <あるべきか (yes|no)> <パス> <ラベル>
assert_link() {
  if [ -L "$2" ]; then actual=yes; else actual=no; fi
  if [ "$1" = "$actual" ]; then
    pass
  else
    fail "$3: expected=$1 actual=$actual"
  fi
}

T=$(mktemp -d)
STUB="$T/stub"
mkdir -p "$STUB"

# claude が無いと install.sh が対話プロンプトに入るのでスタブを置く。
# gh が無ければ外部スキルの導入は [skipped] で終わり、ネットワークへ出ない
printf '#! /bin/sh\nexit 0\n' > "$STUB/claude"
chmod +x "$STUB/claude"
printf '#! /bin/sh\nexit 1\n' > "$STUB/gh"
chmod +x "$STUB/gh"

H="$T/home"
mkdir -p "$H/.claude/hooks" "$H/.claude/skills"

# dotfiles 側で消したファイルへのリンク（消す）
ln -s "$DOTFILES/claude/hooks/removed-hook.sh" "$H/.claude/hooks/removed-hook.sh"
# dotfiles の外を指すリンク先の無いリンク（他のツールのもの。残す）
ln -s "$T/elsewhere/missing" "$H/.claude/skills/foreign"
# dotfiles の外を指すリンク先のあるリンク（残す）
mkdir -p "$T/store/skill"
ln -s "$T/store/skill" "$H/.claude/skills/store-skill"

out=$(HOME="$H" PATH="$STUB:$PATH" sh "$DOTFILES/claude/install.sh" 2>&1)

assert_link no "$H/.claude/hooks/removed-hook.sh" "リンク先の消えた dotfiles のリンクを消す"
assert_contains "[unlinked]" "$out" "消したリンクのタグ"
assert_contains "removed-hook.sh" "$out" "消したリンクのパス"
assert_link yes "$H/.claude/skills/foreign" "dotfiles の外を指すリンクはリンク先が無くても残す"
assert_link yes "$H/.claude/skills/store-skill" "dotfiles の外を指すリンクを残す"

# 配布中のファイルへのリンクは link_config が張ったまま残る
first=$(find "$DOTFILES/claude/hooks" -type f | head -n 1)
assert_link yes "$H/.claude/hooks/${first##*/}" "配布中のリンクを残す"

/bin/rm -r -- "$T"

printf '\n%s passed, %s failed\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
