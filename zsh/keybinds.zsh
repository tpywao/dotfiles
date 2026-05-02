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
bindkey "^[[Z" reverse-menu-complete
## history
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
# # https://github.com/zsh-users/zsh-autosuggestions/issues/678
# ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(history-beginning-search-backward-end history-beginning-search-forward-end)
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
# fzfのコマンドで上書きされるためコメントアウト
# bindkey "^R" history-incremental-pattern-search-backward
# bindkey "^S" history-incremental-pattern-search-forward
##
bindkey "^L" clear-screen
