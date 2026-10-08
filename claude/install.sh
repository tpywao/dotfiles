#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# claude/ 配下は symlink で同期する。hardlink は inode 参照なので、git switch や
# Claude Code の atomic save（tmpfile + rename）でリンクが切れ、両側が黙って分岐する。
# symlink はパス参照なので切れない。Claude Code の Edit は symlink 経由の書き込みを
# 拒否するため、~/.claude/ 側が誤って編集されることもない（編集は dotfiles 側で行う）。
link_claude_files() {
  # settings.json はリンクせず merge_claude_settings で共有キーのみを反映する。
  # mcp-servers.json も同様にマージ元で、~/.claude/ へ配るファイルではない。
  # install.sh と Skillfile はインストーラ側のファイルで ~/.claude/ には要らない
  find "$DOTFILES/claude" -type f \
    -not -path "$DOTFILES/claude/settings.json" \
    -not -path "$DOTFILES/claude/mcp-servers.json" \
    -not -path "$DOTFILES/claude/install.sh" \
    -not -path "$DOTFILES/claude/Skillfile" | while read -r src; do
    rel="${src#$DOTFILES/claude/}"
    link_config "$src" "$HOME/.claude/$rel"
  done
}

# settings.json はリンクの対象にできない。Claude Code 自身が model や
# effortLevel、autoMode をこのファイルへ書き込むため、リンクを張るとマシン固有の
# 値が dotfiles 側に流れ込む。
#
# hooks は既定の再帰マージではなくフィルタで組み立てる。jq の `*` は削除を表現
# できず、再帰マージのままだと dotfiles 側で消した hook が既存の設定に残り、実体を
# 失ったスクリプトが呼ばれ続ける。一方で丸ごと差し替えると、他のアプリ（エージェント
# 管理ツール等）が自分で足した hook まで毎回消してしまう。
#
# そこで dotfiles が配った hook だけを入れ替え、それ以外は残す。「配った」かどうかは
# 設定の中身からは判別できない（command の形はまちまちで、パスで見分けられない）
# ため、配った hook を状態ファイルに記録しておき、次の実行で既存の設定から取り除く。
# 記録は和集合で積み増す。マージに失敗した回でも過去の記録を失わないため。
merge_claude_settings() {
  src="$DOTFILES/claude/settings.json"
  state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-hooks.json"
  if [ -f "$state" ]; then set -- "$state"; else set --; fi

  # $live などは jq の変数。シェルに展開させない
  # shellcheck disable=SC2016
  merge_config "$src" "$HOME/.claude/settings.json" '
    .[0] as $live | .[1] as $shared | (.[2] // []) as $distributed
    | ($live * $shared)
    | if ($shared | has("hooks")) then
        ([$shared.hooks[][] | .hooks // [] | .[]] + $distributed) as $owned
        # 既存の設定から dotfiles 由来の hook を抜き、空になったグループ・イベントを落とす
        | (($live.hooks // {})
            | map_values(
                map(.hooks = [(.hooks // [])[] | select(. as $h | $owned | any(. == $h) | not)])
                | map(select(.hooks | length > 0)))
            | with_entries(select(.value | length > 0))) as $foreign
        | .hooks = reduce (($shared.hooks + $foreign) | keys_unsorted[]) as $event ({};
            .[$event] = ($shared.hooks[$event] // []) + ($foreign[$event] // []))
      else . end
  ' "$@"

  command -v jq > /dev/null 2>&1 || return 0
  mkdir -p "$(dirname "$state")"
  if jq -s '(.[1] // []) + [.[0].hooks // {} | .[][] | .hooks // [] | .[]] | unique' \
    "$src" "$@" > "$state.tmp"; then
    mv "$state.tmp" "$state"
  else
    /bin/rm -f -- "$state.tmp"
  fi
}

# MCP サーバーの登録先 ~/.claude.json は、Claude Code 自身がセッション状態や
# プロジェクト履歴を書き込むマシンローカルのファイルのため、settings.json と同じく
# リンクできない。マシン間で共有したいサーバーだけを mcp-servers.json に持ち、
# 既定の再帰マージで反映する。マシン固有のサーバーや、マシン側で追記したキー
# （API キーの headers 等）は dst にしか無いので保持される。
#
# hooks と違って削除は同期しない（丸ごと差し替えるとマシン固有のサーバーが消える。
# 残ったサーバーは実体を失うわけではなく接続に失敗するだけで、実害が小さい）。
# dotfiles 側で消したサーバーは各マシンで `claude mcp remove <name> -s user` する。
merge_claude_mcp_servers() {
  merge_config "$DOTFILES/claude/mcp-servers.json" "$HOME/.claude.json"
}

# 外部スキルは実体をリポジトリに取り込まず、Skillfile をマニフェストとして
# gh skill install --pin で ~/.claude/skills/ へ導入する（実体は git 管理外）。
# pin されたスキルは gh skill update の対象外になるため、更新するときは Skillfile の
# pin を上げてからこのスクリプトを再実行する。導入済みスキルの ref（SKILL.md
# frontmatter の github-ref）が pin と食い違う場合も入れ直す（マニフェスト側が正）。
install_external_skills() {
  manifest="$DOTFILES/claude/Skillfile"
  failed=
  [ -f "$manifest" ] || return 0
  if ! command -v gh > /dev/null 2>&1; then
    log_tag "$LOG_CHANGED" "[skipped]" "外部スキルの導入 (gh が無い)"
    return 0
  fi
  # 未認証でも gh skill install は動くが、GitHub API の未認証レート制限
  # (IP 単位で 60 req/h) にすぐ当たる。スキル 1 つにつきファイル数だけ blob を
  # 引くため 1 つ導入する前に 403 になり、不完全なスキルが残る。
  # status ではなく token で見るのは、毎回の実行でネットワーク往復させないため
  # (失効したトークンは install の失敗として扱われる)
  if ! gh auth token > /dev/null 2>&1; then
    log_tag "$LOG_CHANGED" "[skipped]" "外部スキルの導入 (gh が未認証)"
    notice "外部スキルを導入していない。gh の認証後に再実行する:
  gh auth login
  ./claude/install.sh"
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
    if gh skill install "$repo" "$skill" --pin "$pin" --dir "$HOME/.claude/skills" --force; then
      log_tag "$LOG_CREATED" "[installed]" "$skill $pin"
    else
      # 途中で落ちても SKILL.md だけは書かれていることがある。残すと上の pin
      # 判定が一致して次回以降スキップされ、壊れたスキルが固定される。
      # 消せば --force で入り直し、Claude Code が読み込むこともなくなる
      /bin/rm -f -- "$dst/SKILL.md"
      log_tag "$LOG_FAILED" "[failed]" "$skill $pin"
      failed=1
    fi
  done < "$manifest"
  if [ -n "$failed" ]; then
    notice "導入に失敗した外部スキルがある。次を実行して入れ直す:
  ./claude/install.sh"
  fi
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
    merge_claude_mcp_servers
  else
    echo "Skipping Claude Code installation."
  fi
else
  link_claude_files
  merge_claude_settings
  merge_claude_mcp_servers
fi
install_external_skills

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
