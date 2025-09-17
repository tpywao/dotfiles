zi id-as"auto" wait lucid as"completion" blockf light-mode for \
  https://raw.githubusercontent.com/docker/cli/master/contrib/completion/zsh/_docker \
  https://raw.githubusercontent.com/sharkdp/fd/master/contrib/completion/_fd \
  id-as"_delta" https://raw.githubusercontent.com/dandavison/delta/master/etc/completion/completion.zsh

zi id-as"auto" wait lucid light-mode for \
  https://raw.githubusercontent.com/sagiegurari/cargo-make/master/extra/shell/makers-completion.bash

zi wait lucid blockf light-mode for \
  atpull"zinit creinstall -q ." \
  zsh-users/zsh-completions

# ref. https://nnsnico.hatenablog.jp/entry/2021/01/30/185939
zi id-as"auto" wait silent lucid light-mode for \
  https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
zi id-as"_git" wait lucid as"completion" light-mode for \
  atload"zstyle ':completion:*:*:git:*' script $ZI[SNIPPETS_DIR]/git-completion.bash" \
  https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh
