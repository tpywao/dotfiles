# keybind
bindkey -e
# ^ ctrl, ^[ alt, ^[[Z shift+tab, $terminfo[kcbt] shift+tab
## cursor
bindkey "^F" forward-char
bindkey "^B" backward-char
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^[f" forward-word
bindkey "^[b" backward-word
bindkey "^[[1;3C" forward-word   # Alt+→
bindkey "^[[1;3D" backward-word  # Alt+←
## delete
bindkey "^H" backward-delete-char
bindkey "^D" delete-char-or-list
bindkey "^W" backward-kill-word
bindkey "^K" kill-line
bindkey "^U" kill-whole-line
## input
bindkey "^Y" yank
bindkey "^Z" undo
bindkey "^[k" accept-line
## history
# fzfのコマンドで上書きされるためコメントアウト
# bindkey "^R" history-incremental-pattern-search-backward
# bindkey "^S" history-incremental-pattern-search-forward
##
bindkey "^L" clear-screen
## completion
zmodload zsh/complist
bindkey "^I" menu-select
bindkey "$terminfo[kcbt]" menu-select
## zsh-abbr
bindkey " " abbr-expand-and-insert
bindkey "^M" abbr-expand-and-accept
## fzf widgets (関数定義は fzf/fzf.functions.zsh)
bindkey "^@" fzf-select-src
bindkey "^R" fzf-select-history
bindkey "^Q" fzf-find-file
bindkey "^X^A" fzf-select-abbr
bindkey "^^" fzf-select-ps
bindkey "^T" fzf-change-worktree

## cmux 対策: kitty keyboard protocol (CSI-u) の漏れを吸収する
# cmux は子アプリが kitty protocol を要求していなくても Ctrl+修飾キーを
# CSI-u 形式 (\e[<code>;5u) で pty に書くため、zle が解釈できず
# 「9;5u」等の断片が入力に漏れる。3 段階で対処する:
#   (1) kitty keyboard mode を pop してエンコーダを legacy に戻す試み
#   (2) 初期化時に漏れた残留バイトを排出
#   (3) 保険: CSI-u を対応する legacy 制御文字に再注入
#       (ウィジェットへ直接バインドせず再注入にするのは、
#        上記の既存バインドにそのまま追従させるため)
# 有効化条件: cmux 内かつ内蔵キーボードが JIS 配列のとき。
# CSI-u の漏れが実害になると確認できているのは JIS 配列環境のみのため、
# それ以外では何もせず副作用を避ける (ioreg は macOS 専用。他 OS では偽になる)
if [[ -n "$CMUX_SOCKET_PATH" ]] &&
   ioreg -r -c AppleEmbeddedKeyboard -d 1 2>/dev/null | grep -q 'KeyboardLanguage.*Japanese'; then
  printf '\e[<u'
  while read -t 0.01 -k 1 _cmux_drain 2>/dev/null; do :; done
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
