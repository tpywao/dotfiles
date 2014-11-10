#! /bin/bash
path=`readlink -f $0`
dir_path=`dirname $path`

ln -sf $dir_path/.vim ~/.vim
ln -sf $dir_path/.vimrc ~/.vimrc
ln -sf $dir_path/.bashrc ~/.bashrc
ln -sf $dir_path/.bash_aliases ~/.bash_aliases
ln -sf $dir_path/.bash_git ~/.bash_git
ln -sf $dir_path/.gitconfig ~/.gitconfig

