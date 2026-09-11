#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# .zshenv だけをリンクする。以降の設定は .zshenv が設定する
# $ZDOTDIR (= $DOTFILES/zsh) から直接読まれる
link_config "$DOTFILES/zsh/.zshenv" "$HOME/.zshenv"

# zsh-autocomplete が cdr (最近訪れたディレクトリ) の保存先を
# $XDG_DATA_HOME/zsh/chpwd-recent-dirs に設定するが、親ディレクトリは作らない。
# 無いと cd のたびに chpwd_recent_filehandler が書き込みに失敗してエラーを出す
zsh_state_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
if [ ! -d "$zsh_state_dir" ]; then
  mkdir -p "$zsh_state_dir"
  log_tag "$LOG_CREATED" "[new]" "$zsh_state_dir"
fi

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
