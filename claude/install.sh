#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# claude/ 配下は symlink で同期する。hardlink は inode 参照なので、git switch や
# Claude Code の atomic save（tmpfile + rename）でリンクが切れ、両側が黙って分岐する。
# symlink はパス参照なので切れない。Claude Code の Edit は symlink 経由の書き込みを
# 拒否するため、~/.claude/ 側が誤って編集されることもない（編集は dotfiles 側で行う）。
#
# 既存ファイルの扱いは共通の symlink() と違い、hardlink 時代の実ファイルを
# symlink へ置き換える必要があるため専用関数にしている。
link_claude_file() {
  file=$1
  link=$2
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$file" ]; then
      printf "\033[0;36m[linked]\033[0m %s\n" "$link"
      return 0
    fi
    ln -sfn "$file" "$link"
    echo "-----> Re-symlinked $link"
    return 0
  fi
  if [ ! -e "$link" ]; then
    echo "-----> Symlinking your new $link"
    ln -s "$file" "$link"
    return 0
  fi
  # hardlink 時代の実ファイル、または手で置いたファイル。内容が一致していれば
  # そのまま置き換え、分岐しているなら退避してから張る（編集を黙って捨てない）
  if cmp -s "$file" "$link"; then
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    echo "-----> Replaced with symlink: $link"
  else
    backup="$link.presymlink.$(date +%Y%m%d-%H%M%S)"
    cp -p "$link" "$backup"
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    echo "-----> $link は内容が分岐していました。$backup へ退避して symlink を張りました"
  fi
}

link_claude_files() {
  # relink フックが退避する *.relinkbak.* は git 管理外のバックアップなので同期しない。
  # settings.json はリンクせず merge_claude_settings で共有キーのみを反映する。
  # install.sh と Skillfile はインストーラ側のファイルで ~/.claude/ には要らない
  find "$DOTFILES/claude" -type f -not -name '*.relinkbak.*' \
    -not -path "$DOTFILES/claude/settings.json" \
    -not -path "$DOTFILES/claude/install.sh" \
    -not -path "$DOTFILES/claude/Skillfile" | while read -r src; do
    rel="${src#$DOTFILES/claude/}"
    dst="$HOME/.claude/$rel"
    mkdir -p "$(dirname "$dst")"
    link_claude_file "$src" "$dst"
  done
}

# settings.json はリンクの対象にできない。Claude Code 自身が model や
# effortLevel、autoMode をこのファイルへ書き込むため、リンクを張るとマシン固有の
# 値が dotfiles 側に流れ込む。
# dotfiles 側は共有したいキーだけを持ち、既存の設定へ上書き適用する。
# dotfiles にないキーは既存値がそのまま残る。
merge_claude_settings() {
  src="$DOTFILES/claude/settings.json"
  dst="$HOME/.claude/settings.json"
  [ -f "$src" ] || return 0
  if ! command -v jq > /dev/null 2>&1; then
    echo "-----> jq が無いため $dst のマージをスキップしました"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  [ -f "$dst" ] || echo '{}' > "$dst"
  tmp="$dst.merging.$$"
  if jq -s '.[0] * .[1]' "$dst" "$src" > "$tmp"; then
    mv "$tmp" "$dst"
    printf "\033[0;36m[merged]\033[0m %s\n" "$dst"
  else
    echo "-----> $dst のマージに失敗しました。$tmp を確認してください"
  fi
}

# 外部スキルは実体をリポジトリに取り込まず、Skillfile をマニフェストとして
# gh skill install --pin で ~/.claude/skills/ へ導入する（実体は git 管理外）。
# pin されたスキルは gh skill update の対象外になるため、更新するときは Skillfile の
# pin を上げてからこのスクリプトを再実行する。導入済みスキルの ref（SKILL.md
# frontmatter の github-ref）が pin と食い違う場合も入れ直す（マニフェスト側が正）。
install_external_skills() {
  manifest="$DOTFILES/claude/Skillfile"
  [ -f "$manifest" ] || return 0
  if ! command -v gh > /dev/null 2>&1; then
    echo "-----> gh が無いため外部スキルの導入をスキップしました"
    return 0
  fi
  while read -r repo skill pin; do
    case "$repo" in ''|\#*) continue ;; esac
    dst="$HOME/.claude/skills/$skill"
    # 別の skill インストーラ（npx skills 等）が自前 store へのディレクトリ symlink を
    # 張っていることがある。残したまま gh skill install すると symlink を辿って
    # 別ツールの store を書き換えかねないため、先に symlink 自体を外す（store は残る）
    if [ -L "$dst" ]; then
      /bin/rm -- "$dst"
      echo "-----> Removed installer dir symlink: $dst"
    fi
    current=$(sed -n 's|.*github-ref: *refs/tags/||p' "$dst/SKILL.md" 2>/dev/null | head -n 1)
    if [ "$current" = "$pin" ]; then
      printf "\033[0;36m[installed]\033[0m %s %s\n" "$skill" "$pin"
      continue
    fi
    gh skill install "$repo" "$skill" --pin "$pin" --dir "$HOME/.claude/skills" --force
  done < "$manifest"
}

if ! command -v claude > /dev/null 2>&1; then
  CLAUDE_INSTALL_CMD="curl -fsSL https://claude.ai/install.sh | bash"
  echo "Claude Code is not installed."
  echo "  $CLAUDE_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$CLAUDE_INSTALL_CMD"
    link_claude_files
    merge_claude_settings
  else
    echo "Skipping Claude Code installation."
  fi
else
  link_claude_files
  merge_claude_settings
fi
install_external_skills

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
