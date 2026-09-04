#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")" && pwd -P)
. "$DOTFILES/utils/install-common.sh"
shell=${1:-$SHELL}

case $shell in
  *fish )
    # fish/ はディレクトリごと ~/.config/fish へリンクするため、fish/install.sh を
    # 置くとインストーラまでリンク先に配られる。ここでリンクする
    symlink "$DOTFILES/fish" "$HOME/.config/fish"
    ;;
  *zsh )
    sh "$DOTFILES/zsh/install.sh" || exit $?
    ;;
  *bash )
    symlink "$DOTFILES/bashrc" "$HOME/.bashrc"
    symlink "$DOTFILES/aliases.bash" "$HOME/.aliases.bash"
    ;;
esac

# 専用ディレクトリを持たない、リポジトリ直下の設定ファイル
symlink "$DOTFILES/.editorconfig" "$HOME/.editorconfig"
symlink "$DOTFILES/vimrc" "$HOME/.vimrc"
symlink "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
symlink "$DOTFILES/screenrc" "$HOME/.screenrc"
symlink "$DOTFILES/sqliterc" "$HOME/.sqliterc"
symlink "$DOTFILES/direnvrc" "$HOME/.direnvrc"

# fzf/ も fish/ と同じくディレクトリごとリンクするため、ここでリンクする
symlink "$DOTFILES/fzf" "$HOME/.fzf"

# 各ディレクトリの install.sh。それぞれ単体でも実行できる (例: ./git/install.sh)
for dir in git docker sheldon karabiner ghostty nix; do
  sh "$DOTFILES/$dir/install.sh" || exit $?
done

# Nix を今回インストールした場合、サブプロセスでの PATH 変更はここへ届かない。
# claude/install.sh が使う jq / gh は home-manager が ~/.nix-profile へ入れるため、
# このプロセスでも読み込んでおく
NIX_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
[ -f "$NIX_PROFILE" ] && . "$NIX_PROFILE"

for dir in brew claude; do
  sh "$DOTFILES/$dir/install.sh" || exit $?
done

exec $SHELL
