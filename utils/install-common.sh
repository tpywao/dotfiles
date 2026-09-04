# shellcheck shell=sh
# 各ディレクトリの install.sh から source する共通部。
# 呼び出し元が $DOTFILES を設定してから読み込むこと。
#
# symlink() を utils/utils.bash に置かないのは、utils.bash が zsh/.zshenv から
# 全 zsh 起動で source されるため。インストール時にしか使わない関数を
# シェル起動のたびに定義しない。

: "${DOTFILES:?DOTFILES must be set before sourcing install-common.sh}"

# OS 判定関数 (is_mac, is_wsl, is_linux)
. "$DOTFILES/utils/utils.bash"

symlink() {
  file=$1
  link=$2
  if [ -L "$link" ]; then
    printf "\033[0;36m[linked]\033[0m %s\n" "$link"
  elif [ ! -e "$link" ]; then
    echo "-----> Symlinking your new $link"
    ln -si $file $link
  fi
}
