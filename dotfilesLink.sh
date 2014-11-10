#! /bin/bash
path=`readlink -f $0`
dir_path=`dirname $path`

ln -s $dir_path/.vimrc ~/.vimrc
ln -s $dir_path/.bashrc ~/.bashrc
ln -s $dir_path/.bash_aliases ~/.bash_aliases
ln -s $dir_path/.bash_git ~/.bash_git
ln -s $dir_path/.gitconfig ~/.gitconfig

