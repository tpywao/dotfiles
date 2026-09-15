#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

# Karabiner-Elements は macOS 専用
is_mac || exit 0

KARABINER_JSON="$HOME/.config/karabiner/karabiner.json"
ASSETS="$HOME/.config/karabiner/assets/complex_modifications"

# complex modifications は assets/ へリンクする。Karabiner はこのディレクトリを
# 読むだけで（GUI のゴミ箱ボタンで消したときだけ unlink する）、リンクを壊さない。
#
# Naginata.json は必要なときに GUI から選ぶための置き場で、常時有効にするもの
# ではない。未有効を TODO へ回すのは Personal.json だけにする。
link_config "$DOTFILES/karabiner/Naginata.json" "$ASSETS/Naginata.json"
link_config "$DOTFILES/karabiner/Personal.json" "$ASSETS/Personal.json"

# karabiner.json はリンクの対象にできない。Karabiner-Elements は設定を保存する
# たびにこのファイルを書き直し、その際 symlink を実体で置き換えてしまう。
# symlink のままだと外部からの変更検知（自動リロード）も効かない。
#
# 共有するのは profile-defaults.json が持つキーだけ。complex_modifications の
# rules には触れない（assets/ 側のファイルを GUI で有効化した結果がそこに入るため、
# 両方から書くと二重管理になる）。
#
# devices は配列なので dotfiles 側で置換される。マシン固有のデバイス設定を
# 足したマシンでは merge_config が [dropped] で知らせる。
merge_karabiner_profile() {
  # $live / $shared は jq の変数。シェルに展開させない
  # shellcheck disable=SC2016
  merge_config "$DOTFILES/karabiner/profile-defaults.json" "$KARABINER_JSON" '
    .[0] as $live | .[1] as $shared
    | $live
    | .profiles = (
        ($live.profiles // [])
        | map(
            if .name == $shared.name
            then .devices = $shared.devices
               | .virtual_hid_keyboard = ((.virtual_hid_keyboard // {}) * $shared.virtual_hid_keyboard)
            else . end
          )
      )
  '
}

# assets/ に置いただけでは complex modification は効かない。GUI で Add rule して
# はじめて karabiner.json の rules に入るため、未反映のルールを TODO へ回す。
#
#   notice_unenabled_rules <常時有効にしたいルールを持つ assets の json>
notice_unenabled_rules() {
  command -v jq > /dev/null 2>&1 || return 0

  profile=$(jq -r '.name' "$DOTFILES/karabiner/profile-defaults.json")
  if ! jq -e --arg n "$profile" 'any(.profiles[]?; .name == $n)' "$KARABINER_JSON" > /dev/null 2>&1; then
    notice "Karabiner-Elements で \"$profile\" を作ってから ./karabiner/install.sh を再実行する"
    return 0
  fi

  # $live / $shared は jq の変数。シェルに展開させない
  # shellcheck disable=SC2016
  unenabled=$(jq -r -s --arg n "$profile" '
    .[0] as $live | .[1] as $shared
    | [$live.profiles[] | select(.name == $n) | .complex_modifications.rules[]?.description] as $enabled
    | $shared.rules[].description
    | select(. as $d | $enabled | index($d) | not)
  ' "$KARABINER_JSON" "$1" 2> /dev/null)
  [ -n "$unenabled" ] || return 0

  notice "Karabiner-Elements の Settings > Complex Modifications > Add rule で $(basename "$1") の以下を有効化する:
$(printf '%s\n' "$unenabled" | sed 's/^/  - /')"
}

# karabiner.json は Karabiner-Elements が初回起動時に作る。無いうちにマージすると
# profiles が空の設定ファイルを先回りで置いてしまうため、起動を待つ。
if [ -f "$KARABINER_JSON" ]; then
  merge_karabiner_profile
  notice_unenabled_rules "$DOTFILES/karabiner/Personal.json"
else
  notice "Karabiner-Elements を一度起動してから ./karabiner/install.sh を再実行する（$KARABINER_JSON が無い）"
fi

# 個別の失敗でルートの install.sh を止めない (止めたいときだけ exit 1 する)
exit 0
