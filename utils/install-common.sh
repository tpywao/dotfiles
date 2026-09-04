# shellcheck shell=sh
# 各ディレクトリの install.sh から source する共通部。
# 呼び出し元が $DOTFILES を設定してから読み込むこと。
#
# link_config() を utils/utils.bash に置かないのは、utils.bash が zsh/.zshenv から
# 全 zsh 起動で source されるため。インストール時にしか使わない関数を
# シェル起動のたびに定義しない。

: "${DOTFILES:?DOTFILES must be set before sourcing install-common.sh}"

# OS 判定関数 (is_mac, is_wsl, is_linux)
. "$DOTFILES/utils/utils.bash"

# 対象ごとの結果は log_tag で 1 行にまとめる。何が起きたかをタグの色と語で
# 判別できるようにするため、対象を持たない進行ログ（`-----> Switching ...`）
# とは書式を分けている。
LOG_UNCHANGED=36  # シアン: 変化なし
LOG_CREATED=32    # 緑: 新規に作った
LOG_CHANGED=33    # 黄: 既存のものを動かした
LOG_FAILED=31     # 赤: 失敗した

# log_tag <色> <[タグ]> <対象...>
# タグ幅は最長の [installed] に合わせて揃える。色コードは %-11s の幅計算に
# 入らないよう、書式側に固定で置く。
log_tag() {
  color=$1
  tag=$2
  shift 2
  printf "\033[0;%sm%-11s\033[0m %s\n" "$color" "$tag" "$*"
}

# 設定ファイル/ディレクトリを symlink で配置する。親ディレクトリは自動で作る。
#
# リンクの有無だけでなく**リンク先**を検証する。リンク先を見ない実装では、
# dotfiles 側でリンク元のパスを変えても既存のリンクが張り替えられず、
# install.sh の指定と実際のリンクが食い違ったまま気づけない。
#
# リンク先に実体があるときは、内容を確認してから置き換える（編集を黙って
# 捨てない）。ディレクトリは内容を比較せず常に退避する。再帰比較の結果に
# 関わらず中身を消さずに済ませるため。
link_config() {
  file=$1
  link=$2
  mkdir -p "$(dirname "$link")"

  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$file" ]; then
      log_tag "$LOG_UNCHANGED" "[linked]" "$link"
      return 0
    fi
    ln -sfn "$file" "$link"
    log_tag "$LOG_CHANGED" "[relinked]" "$link"
    return 0
  fi

  if [ ! -e "$link" ]; then
    ln -s "$file" "$link"
    log_tag "$LOG_CREATED" "[new]" "$link"
    return 0
  fi

  backup="$link.presymlink.$(date +%Y%m%d-%H%M%S)"

  if [ -d "$link" ]; then
    mv "$link" "$backup"
    ln -sfn "$file" "$link"
    log_tag "$LOG_CHANGED" "[backup]" "$link -> $backup (実ディレクトリ)"
    return 0
  fi

  if cmp -s "$file" "$link"; then
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    log_tag "$LOG_CHANGED" "[replaced]" "$link"
  else
    cp -p "$link" "$backup"
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    log_tag "$LOG_CHANGED" "[backup]" "$link -> $backup (内容が分岐)"
  fi
}

# JSON の設定ファイルを、dotfiles 側の共有キーだけ既存の設定へ上書き適用する。
#
#   merge_config <dotfiles 側の src> <配布先の dst> [<jq フィルタ>]
#
# アプリ自身が書き込む設定ファイルは link_config の対象にできない。リンクを張ると
# アプリが書いたマシン固有の値が dotfiles 側へ流れ込み、逆に dotfiles 側の内容で
# 置き換えるとその値が失われる。dst にしか無いキーは触らずそのまま残す。
#
# jq フィルタは .[0] を既存の設定（dst）、.[1] を dotfiles 側（src）として受け取る。
# 既定は再帰マージのみ。jq の `*` はオブジェクトを再帰マージするだけで削除を
# 表現できないため、dotfiles 側で消したキーを dst からも消したい場合は
# 呼び出し側でフィルタを渡す。
merge_config() {
  src=$1
  dst=$2
  filter="${3:-.[0] * .[1]}"
  [ -f "$src" ] || return 0
  if ! command -v jq > /dev/null 2>&1; then
    log_tag "$LOG_CHANGED" "[skipped]" "$dst (jq が無い)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"

  # 以前のバージョンがこのファイルをリンクしていることがある。リンクのまま
  # 書き込むと src を書き換えてしまうため、先に実体へ戻す。内容ごとコピーする
  # ので、リンク経由でアプリが書き込んでいた値も引き継げる
  if [ -L "$dst" ]; then
    copy="$dst.unlinking.$$"
    [ -f "$dst" ] && cp -L "$dst" "$copy"
    /bin/rm -- "$dst"
    [ -f "$copy" ] && mv "$copy" "$dst"
    log_tag "$LOG_CHANGED" "[unlinked]" "$dst (symlink を実体に戻した)"
  fi

  [ -f "$dst" ] || echo '{}' > "$dst"
  tmp="$dst.merging.$$"
  if jq -s "$filter" "$dst" "$src" > "$tmp"; then
    mv "$tmp" "$dst"
    log_tag "$LOG_UNCHANGED" "[merged]" "$dst"
  else
    log_tag "$LOG_FAILED" "[failed]" "$dst (マージ失敗。$tmp を確認)"
  fi
}
