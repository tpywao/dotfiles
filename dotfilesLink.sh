#! /bin/sh
path=`readlink -f $0`
dir_path=`dirname $path`
# if ( $1 == NULL or $1 == '' )
shell=${1:-$SHELL}

case $shell in
  *zsh )
    zsh_path=$dir_path/.zsh
    ln -si $zsh_path/.zshenv ~/.zshenv
    # ln -si $zsh_path/.zshrc ~/.zshrc
    # ln -si $dir_path/.zshrc.alias ~/.zshrc.alias
    ;;
  *bash )
    ln -si $dir_path/.bashrc ~/.bashrc
    ln -si $dir_path/.bashrc.aliases ~/.bashrc.aliases
    ;;
esac

# vim
# ln -sin $dir_path/.vim ~/.vim
ln -si $dir_path/.vimrc ~/.vimrc

# git
ln -si $dir_path/.gitconfig ~/.gitconfig
ln -si $dir_path/.gitignore ~/.gitignore

# tmux
ln -si $dir_path/.tmux.conf ~/.tmux.conf

# screen
ln -si $dir_path/.screenrc ~/.screenrc
