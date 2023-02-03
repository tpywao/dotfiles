#! /bin/sh
DOTFILES=`cd $(dirname $0) && pwd -P`
shell=${1:-$SHELL}

symlink() {
  file=$1
  link=$2
  if [ ! -e "$link" ]; then
    echo "-----> Symlinking your new $link"
    ln -si $file $link
  fi
}

case $shell in
  *fish )
    symlink $DOTFILES/fish ~/.config/fish
    ;;
  *zsh )
    symlink $DOTFILES/zsh/.zshenv ~/.zshenv
    ;;
  *bash )
    symlink $DOTFILES/bashrc ~/.bashrc
    symlink $DOTFILES/aliases.bashrc ~/.aliases.bashrc
    ;;
esac

# EditorConfig
symlink $DOTFILES/.editorconfig ~/.editorconfig

# vim
symlink $DOTFILES/vimrc ~/.vimrc

# git
symlink $DOTFILES/gitconfig ~/.gitconfig

# docker
symlink $DOTFILES/docker/config.json ~/.docker/config.json

# tmux
symlink $DOTFILES/tmux.conf ~/.tmux.conf

# screen
symlink $DOTFILES/screenrc ~/.screenrc

# sqlite
symlink $DOTFILES/sqliterc ~/.sqliterc

# direnv
symlink $DOTFILES/direnvrc ~/.direnvrc

exec $SHELL
