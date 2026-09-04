#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")" && pwd -P)
. "$DOTFILES/utils/install-common.sh"
shell=${1:-$SHELL}

case $shell in
  *fish )
    # fish/ はディレクトリごと ~/.config/fish へリンクするため、fish/install.sh を
    # 置くとインストーラまでリンク先に配られる。ここでリンクする
    link_config "$DOTFILES/fish" "$HOME/.config/fish"
    ;;
  *zsh )
    sh "$DOTFILES/zsh/install.sh" || exit $?
    ;;
  *bash )
    link_config "$DOTFILES/bashrc" "$HOME/.bashrc"
    link_config "$DOTFILES/aliases.bash" "$HOME/.aliases.bash"
    ;;
esac

# 専用ディレクトリを持たない、リポジトリ直下の設定ファイル
link_config "$DOTFILES/editorconfig" "$HOME/.editorconfig"
link_config "$DOTFILES/vimrc" "$HOME/.vimrc"
link_config "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
link_config "$DOTFILES/screenrc" "$HOME/.screenrc"
link_config "$DOTFILES/sqliterc" "$HOME/.sqliterc"
link_config "$DOTFILES/direnvrc" "$HOME/.direnvrc"

# fzf/ も fish/ と同じくディレクトリごとリンクするため、ここでリンクする
link_config "$DOTFILES/fzf" "$HOME/.fzf"

# 各ディレクトリの install.sh。それぞれ単体でも実行できる (例: ./git/install.sh)
for dir in git sheldon karabiner ghostty nix brew; do
  sh "$DOTFILES/$dir/install.sh" || exit $?
done

# Nix を今回インストールした場合、サブプロセスでの PATH 変更はここへ届かない。
# jq / gh は home-manager が ~/.nix-profile へ入れるため、このプロセスでも
# 読み込んでおく
NIX_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
[ -f "$NIX_PROFILE" ] && . "$NIX_PROFILE"

# docker と claude は設定を jq でマージするため、jq が入る nix より後に置く
for dir in docker claude; do
  sh "$DOTFILES/$dir/install.sh" || exit $?
done

# 実行中のシェルは置き換えない。exec すると終了ステータスを返せず、
# 再実行のたびにシェルが入れ子になる
echo ""
echo "-----> Done. Open a new shell to load the new configuration."
