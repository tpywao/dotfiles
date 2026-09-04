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

  backup="$link.presymlink.$(date +%Y%m%d-%H%M%S)"

  if [ -d "$link" ]; then
    mv "$link" "$backup"
    ln -sfn "$file" "$link"
    echo "-----> $link は実ディレクトリでした。$backup へ退避して symlink を張りました"
    return 0
  fi

  if cmp -s "$file" "$link"; then
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    echo "-----> Replaced with symlink: $link"
  else
    cp -p "$link" "$backup"
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    echo "-----> $link は内容が分岐していました。$backup へ退避して symlink を張りました"
  fi
}
