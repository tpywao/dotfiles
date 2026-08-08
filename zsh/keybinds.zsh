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
  for _cmux_code in {97..122}; do  # Ctrl+a〜z → ^A〜^Z
    _cmux_ctrl=$(( _cmux_code - 96 ))
    bindkey -s "\e[${_cmux_code};5u" "${(#)_cmux_ctrl}"
  done
  for _cmux_code in {91..95}; do   # Ctrl+[ \ ] ^ _ → ESC ^\ ^] ^^ ^_
    _cmux_ctrl=$(( _cmux_code - 64 ))
    bindkey -s "\e[${_cmux_code};5u" "${(#)_cmux_ctrl}"
  done
  bindkey -s '\e[32;5u' '^@'   # Ctrl+Space → NUL
  bindkey -s '\e[64;5u' '^@'   # Ctrl+@ → NUL
  # 制御文字が存在しないキー (数字・記号): legacy 端末は修飾を落として
  # 素の文字を送るので、それに合わせて文字を注入する
  # (放置すると Ctrl+. が「46;5u」のような断片として漏れる)
  for _cmux_code in {33..63} 96 {123..126}; do
    bindkey -s "\e[${_cmux_code};5u" "${(#)_cmux_code}"
  done
  # ^C は例外: SIGINT は tty ドライバが typed 0x03 を見て発生させるもので、
  # 再注入した 0x03 は zle に文字として届くだけなので、ウィジェットで代替する
  bindkey '\e[99;5u' send-break
  unset _cmux_drain _cmux_code _cmux_ctrl
fi
