#! /bin/sh
function __readlink_f {
  target="$1"
  while [ -n "$target"]; do
    filepath="$target"
    cd `dirname "$filepath"`
    target=`readlink "$filepath"`
  done
  /bin/echo `pwd -P`/`basename "$filepath"`
}
path=`__readlink_f $0`
dir_path=`dirname $path`
# if ( $1 == NULL or $1 == '' )
shell=${1:-$SHELL}

case $shell in
  *zsh )
    zsh_path=$dir_path/zsh
    ln -si $zsh_path/.zshenv ~/.zshenv
    # ln -si $zsh_path/.zshrc ~/.zshrc
    # ln -si $dir_path/.zshrc.alias ~/.zshrc.alias
    mkdir $HOME/.fzf
    ln -si $dir_path/fzf/fzf.functions.zsh $HOME/.fzf/fzf.functions.zsh
    ;;
  *bash )
    ln -si $dir_path/bashrc ~/.bashrc
    ln -si $dir_path/bashrc.aliases ~/.bashrc.aliases
    ;;
esac

# EditorConfig
ln -si $dir_path/editorconfig ~/.editorconfig
# vim
# ln -sin $dir_path/.vim ~/.vim
ln -si $dir_path/vimrc ~/.vimrc

# git
ln -si $dir_path/gitconfig ~/.gitconfig

# tmux
ln -si $dir_path/tmux.conf ~/.tmux.conf

# screen
ln -si $dir_path/screenrc ~/.screenrc
