# cmux のキーボード入力化け対策
#
# ■ 何が起きるか
#   cmux (Ghostty ベースのターミナル) は、Ctrl を伴うキー入力を kitty
#   keyboard protocol の CSI-u 形式で pty に書くことがある。
#   例: Ctrl+M →「ESC [ 109 ; 5 u」という 8 バイトのエスケープ列。
#   zsh はこの形式を要求していないため解釈できず、途中まで消費された
#   残りの「9;5u」のような断片がプロンプトに文字として漏れる。
#   iTerm2 などはアプリが要求した時だけこの形式で送るので起きない。
#
# ■ このファイルがやること (cmux 内 + 内蔵キーボードが JIS の時だけ)
#   1. 端末に kitty モードの解除を要求する (それだけでは直りきらないので 2, 3 が要る)
#   2. シェル起動前に漏れ済みのゴミバイトを読み捨てる
#   3. CSI-u で届く全キー (Ctrl+英字/記号/数字 × Shift/Alt × 押す/リピート/離す)
#      を本来の文字に変換してキー入力へ再注入する。keybinds.zsh などの
#      既存バインドは、再注入された文字に対して普段どおり効く
#
# ■ 運用
#   - やめたい/直ったとき: .zshrc からこのファイルの source を外すだけ
#   - キーボード判定をやり直すとき: ~/.cache/zsh/jis-internal-keyboard を削除

# 有効化条件: cmux 内かつ内蔵キーボードが JIS 配列のとき。
# CSI-u の漏れが実害になると確認できているのは JIS 配列環境のみのため、
# それ以外では何もせず副作用を避ける (ioreg は macOS 専用。他 OS では偽になる)
# ioreg は 1 回 0.4 秒近くかかり、内蔵キーボードの配列はマシン固有で
# 変わらないため、判定結果はファイルにキャッシュする
_cmux-jis-internal-keyboard() {
  local cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/jis-internal-keyboard
  if [[ ! -r $cache ]]; then
    mkdir -p ${cache:h}
    if ioreg -r -c AppleEmbeddedKeyboard -d 1 2>/dev/null |
       grep -q 'KeyboardLanguage.*Japanese'; then
      echo 1 > $cache
    else
      echo 0 > $cache
    fi
  fi
  [[ "$(<$cache)" == 1 ]]
}
if [[ -n "$CMUX_SOCKET_PATH" ]] && _cmux-jis-internal-keyboard; then
  # (1) kitty keyboard mode の解除を要求
  printf '\e[<u'
  # (2) 起動前に漏れた残留バイトを排出
  while read -t 0.01 -k 1 _cmux_drain 2>/dev/null; do :; done
  # (3) CSI-u → 本来の文字への再注入バインドを生成する
  # キーコード → 注入する文字コードのマップ
  typeset -A _cmux_map
  for _cmux_code in {97..122}; do  # Ctrl+a〜z → ^A〜^Z
    _cmux_map[$_cmux_code]=$(( _cmux_code - 96 ))
  done
  for _cmux_code in {91..95}; do   # Ctrl+[ \ ] ^ _ → ESC ^\ ^] ^^ ^_
    _cmux_map[$_cmux_code]=$(( _cmux_code - 64 ))
  done
  # kitty 仕様 "Legacy ctrl mapping of ASCII keys" の表にある写像
  # (Space/@/2→NUL, 3→ESC, 4〜7→0x1c〜0x1f, 8→DEL, /→0x1f)
  _cmux_map+=(32 0  64 0  50 0  51 27  52 28  53 29  54 30  55 31  56 127  47 31)
  # 修飾つきで CSI-u 化される機能キー (Tab/Enter/Backspace) は素のキーに戻す
  _cmux_map+=(9 9  13 13  127 127)
  # 上記以外 (制御文字写像を持たない数字・記号) は修飾を落として素の文字にする
  # (放置すると Ctrl+. が「46;5u」のような断片として漏れる)
  for _cmux_code in {33..46} {48..49} {57..63} 96 {123..126}; do
    _cmux_map[$_cmux_code]=$_cmux_code
  done
  # release イベントは入力に対応物がないので黙って捨てる
  _cmux-discard-key() { :; }
  zle -N _cmux-discard-key
  # modifier: 5=Ctrl 6=Ctrl+Shift 7=Ctrl+Alt 8=Ctrl+Alt+Shift
  # event-type: 省略/:1=press :2=repeat は注入、:3=release は破棄
  for _cmux_code in ${(k)_cmux_map}; do
    _cmux_ctrl=$_cmux_map[$_cmux_code]
    if (( _cmux_ctrl == 0 )); then
      _cmux_out='^@'
    elif (( _cmux_ctrl == 127 )); then
      _cmux_out='^?'
    else
      _cmux_out=${(#)_cmux_ctrl}
    fi
    for _cmux_mod in 5 6 7 8; do
      # Alt を含む修飾 (7, 8) は legacy どおり ESC プレフィックスを付ける
      _cmux_prefix=''
      (( _cmux_mod >= 7 )) && _cmux_prefix=$'\e'
      for _cmux_ev in '' ':1' ':2'; do
        bindkey -s "\e[${_cmux_code};${_cmux_mod}${_cmux_ev}u" "${_cmux_prefix}${_cmux_out}"
      done
      bindkey "\e[${_cmux_code};${_cmux_mod}:3u" _cmux-discard-key
    done
  done
  # ^C は例外: SIGINT は tty ドライバが typed 0x03 を見て発生させるもので、
  # 再注入した 0x03 は zle に文字として届くだけなので、ウィジェットで代替する
  for _cmux_seq in '\e[99;5u' '\e[99;5:1u' '\e[99;5:2u' \
                   '\e[99;6u' '\e[99;6:1u' '\e[99;6:2u'; do
    bindkey "$_cmux_seq" send-break
  done
  unset _cmux_drain _cmux_map _cmux_code _cmux_ctrl _cmux_out _cmux_mod _cmux_ev _cmux_prefix _cmux_seq
fi
