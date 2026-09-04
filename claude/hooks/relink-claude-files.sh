#!/bin/bash
# PostToolUse hook (Edit|Write): re-hardlink any ~/.claude/<path> file that has a
# counterpart at $DOTFILES/claude/<path>. Claude's Edit/Write use atomic save
# (tmpfile + rename), which breaks hardlinks on every edit; this script restores
# the link.
#
# - If both sides have identical content, just re-link (lossless).
# - If they have diverged, back up the older side to <path>.relinkbak.<ts>
#   before overwriting it, so no edit is silently lost.
#
# claude/ 配下は claude/install.sh の link_claude_files が symlink で張るようになったため、
# 通常は -ef が実体を辿って同一 inode と判定され、このスクリプトは何もせず終了する。
# install.sh を未実行のマシンに残る hardlink を拾うためだけに残している。
set -u

# This script is hardlinked into ~/.claude/hooks, so it can't resolve its own
# repo location. Derive the dotfiles dir from $DOTFILES if set, otherwise from
# the ~/.zshenv symlink target (mirrors zsh/.zshenv).
if [ -z "${DOTFILES:-}" ]; then
  ZSHENV=$(readlink "$HOME/.zshenv" 2>/dev/null)
  DOTFILES="${ZSHENV%/*/*}"
fi

EDITED=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null < /dev/stdin)
[ -z "$EDITED" ] && exit 0

case "$EDITED" in
  "$HOME/.claude/"*)
    rest="${EDITED#$HOME/.claude/}"
    OTHER="$DOTFILES/claude/$rest"
    ;;
  "$DOTFILES/claude/"*)
    rest="${EDITED#$DOTFILES/claude/}"
    OTHER="$HOME/.claude/$rest"
    ;;
  *)
    exit 0
    ;;
esac

# settings.json は hardlink 同期の対象外。Claude Code 自身が model や autoMode を
# ~/.claude/settings.json へ書き込むため、リンクを張るとマシン固有の値が dotfiles
# 側へ流れ込む。共有キーの反映は claude/install.sh の merge_claude_settings が担う
[ "$rest" = "settings.json" ] && exit 0

[ -f "$EDITED" ] || exit 0
[ -f "$OTHER" ] || exit 0

if [ "$EDITED" -ef "$OTHER" ]; then
  exit 0
fi

if [ "$EDITED" -nt "$OTHER" ]; then
  SRC="$EDITED"; DST="$OTHER"
else
  SRC="$OTHER"; DST="$EDITED"
fi

if cmp -s "$SRC" "$DST"; then
  /bin/rm -- "$DST" && ln "$SRC" "$DST"
  exit 0
fi

BACKUP="$DST.relinkbak.$(date +%Y%m%d-%H%M%S)"
cp -p "$DST" "$BACKUP"
/bin/rm -- "$DST" && ln "$SRC" "$DST"
echo "relink-claude-files: $DST と $SRC が divergent でした。$DST の旧内容を $BACKUP に退避し、$SRC で hardlink を再構築しました。ユーザに backup の存在と diff を確認するよう促してください。" >&2
exit 2
