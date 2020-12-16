#! /bin/sh
DOTFILES=`cd $(dirname $0) && pwd -P`
shell=${1:-$SHELL}

FZF_ROOT=$HOME/.fzf
case $shell in
  *fish )
    ln -si $DOTFILES/fish ~/.config/fish
    ;;
  *zsh )
    ln -si $DOTFILES/zsh/.zshenv ~/.zshenv
    # fzf
    mkdir -p $FZF_ROOT
    ln -si $DOTFILES/fzf/fzf.functions.zsh $FZF_ROOT/fzf.functions.zsh
    ;;
  *bash )
    ln -si $DOTFILES/bashrc ~/.bashrc
    ln -si $DOTFILES/bashrc.aliases ~/.bashrc.aliases
    ;;
esac

# EditorConfig
ln -si $DOTFILES/editorconfig ~/.editorconfig

# vim
# ln -sin $DOTFILES/.vim ~/.vim
ln -si $DOTFILES/vimrc ~/.vimrc

# git
ln -si $DOTFILES/gitconfig ~/.gitconfig

# docker
ln -si $DOTFILES/docker/config.json ~/.docker/config.json

# tmux
ln -si $DOTFILES/tmux.conf ~/.tmux.conf

# screen
ln -si $DOTFILES/screenrc ~/.screenrc

# sqlite
ln -si $DOTFILES/sqliterc ~/.sqliterc

# direnv
ln -si $DOTFILES/direnvrc ~/.direnvrc
