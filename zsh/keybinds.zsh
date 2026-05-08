# keybind
bindkey -e
# ^ ctrl, ^[ alt, ^[[Z shift+tab
## cursor
bindkey "^F" forward-char
bindkey "^B" backward-char
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line
bindkey "^[f" forward-word
bindkey "^[b" backward-word
## delete
bindkey "^H" backward-delete-char
bindkey "^D" delete-char-or-list
bindkey "^W" backward-kill-word
bindkey "^K" kill-line
bindkey "^U" kill-whole-line
## input
bindkey "^M" accept-line
bindkey "^Y" yank
bindkey "^Z" undo
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
