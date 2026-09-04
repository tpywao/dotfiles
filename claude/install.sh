#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# claude/ 配下は symlink で同期する。hardlink は inode 参照なので、git switch や
# Claude Code の atomic save（tmpfile + rename）でリンクが切れ、両側が黙って分岐する。
# symlink はパス参照なので切れない。Claude Code の Edit は symlink 経由の書き込みを
# 拒否するため、~/.claude/ 側が誤って編集されることもない（編集は dotfiles 側で行う）。
link_claude_files() {
  # settings.json はリンクせず merge_claude_settings で共有キーのみを反映する。
  # install.sh と Skillfile はインストーラ側のファイルで ~/.claude/ には要らない
  find "$DOTFILES/claude" -type f \
    -not -path "$DOTFILES/claude/settings.json" \
    -not -path "$DOTFILES/claude/install.sh" \
    -not -path "$DOTFILES/claude/Skillfile" | while read -r src; do
    rel="${src#$DOTFILES/claude/}"
    link_config "$src" "$HOME/.claude/$rel"
  done
}

# settings.json はリンクの対象にできない。Claude Code 自身が model や
# effortLevel、autoMode をこのファイルへ書き込むため、リンクを張るとマシン固有の
# 値が dotfiles 側に流れ込む。
# dotfiles 側は共有したいキーだけを持ち、既存の設定へ上書き適用する。
# dotfiles にないキーは既存値がそのまま残る。
#
# ただし hooks は dotfiles を唯一の正として丸ごと差し替える。jq の `*` は
# オブジェクトを再帰マージするだけで削除を表現できないため、再帰マージのままだと
# dotfiles 側で消したイベントが既存の設定に残り、実体を失ったスクリプトが
# 呼ばれ続ける。差し替えの副作用として、マシン単位で hook を足したいときは
# ~/.claude/settings.json への直書きではなくプロジェクトの
# .claude/settings.local.json を使う必要がある。
merge_claude_settings() {
  src="$DOTFILES/claude/settings.json"
  dst="$HOME/.claude/settings.json"
  [ -f "$src" ] || return 0
  if ! command -v jq > /dev/null 2>&1; then
    log_tag "$LOG_CHANGED" "[skipped]" "$dst (jq が無い)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  [ -f "$dst" ] || echo '{}' > "$dst"
  tmp="$dst.merging.$$"
  if jq -s '
    .[0] as $live | .[1] as $shared
    | ($live * $shared)
    | if ($shared | has("hooks")) then .hooks = $shared.hooks else . end
  ' "$dst" "$src" > "$tmp"; then
    mv "$tmp" "$dst"
    log_tag "$LOG_UNCHANGED" "[merged]" "$dst"
  else
    log_tag "$LOG_FAILED" "[failed]" "$dst (マージ失敗。$tmp を確認)"
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
    log_tag "$LOG_CHANGED" "[skipped]" "外部スキルの導入 (gh が無い)"
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
      log_tag "$LOG_CHANGED" "[unlinked]" "$dst (別インストーラの symlink)"
    fi
    current=$(sed -n 's|.*github-ref: *refs/tags/||p' "$dst/SKILL.md" 2>/dev/null | head -n 1)
    if [ "$current" = "$pin" ]; then
      log_tag "$LOG_UNCHANGED" "[installed]" "$skill $pin"
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
