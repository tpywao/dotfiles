#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# config.json はリンクの対象にできない。Docker Desktop が credsStore や
# currentContext、plugins をこのファイルへ書き込むため、リンクを張ると
# マシン固有の値が dotfiles 側へ流れ込む。逆に dotfiles 側の内容で置き換えると
# 認証情報の保存先（credsStore）を失い、docker login が効かなくなる。
# dotfiles 側が持つのは detachKeys だけで、残りは既存値をそのまま使う。
merge_config "$DOTFILES/docker/config.json" "$HOME/.docker/config.json"

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
