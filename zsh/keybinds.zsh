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

# cmux でのキー入力化け対策 (CSI-u の吸収) は cmux.zsh にある
