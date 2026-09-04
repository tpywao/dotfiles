#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# config.json はリンクの対象にできない。Docker Desktop が credsStore や
# currentContext、plugins をこのファイルへ書き込むため、リンクを張ると
# マシン固有の値が dotfiles 側へ流れ込む。逆に dotfiles 側の内容で置き換えると
# 認証情報の保存先（credsStore）を失い、docker login が効かなくなる。
# dotfiles 側は共有したいキーだけを持ち、既存の設定へ上書き適用する。
# dotfiles にないキーは既存値がそのまま残る。
merge_docker_config() {
  src="$DOTFILES/docker/config.json"
  dst="$HOME/.docker/config.json"
  [ -f "$src" ] || return 0
  if ! command -v jq > /dev/null 2>&1; then
    log_tag "$LOG_CHANGED" "[skipped]" "$dst (jq が無い)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"

  # 以前のバージョンはこのファイルをリンクしていた。リンクのまま書き込むと
  # dotfiles 側の config.json を書き換えてしまうため、先に実体へ戻す。
  # 内容ごとコピーするので、リンク経由で書き込まれていた値も引き継げる
  if [ -L "$dst" ]; then
    copy="$dst.unlinking.$$"
    [ -f "$dst" ] && cp -L "$dst" "$copy"
    /bin/rm -- "$dst"
    [ -f "$copy" ] && mv "$copy" "$dst"
    log_tag "$LOG_CHANGED" "[unlinked]" "$dst (symlink を実体に戻した)"
  fi

  [ -f "$dst" ] || echo '{}' > "$dst"
  tmp="$dst.merging.$$"
  if jq -s '.[0] * .[1]' "$dst" "$src" > "$tmp"; then
    mv "$tmp" "$dst"
    log_tag "$LOG_UNCHANGED" "[merged]" "$dst"
  else
    log_tag "$LOG_FAILED" "[failed]" "$dst (マージ失敗。$tmp を確認)"
  fi
}

merge_docker_config

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
