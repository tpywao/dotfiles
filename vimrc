"
set notitle
set showmode
set showcmd
set nu
set ruler
set showmatch
set list
set listchars=eol:\ ,tab:\>-,trail:-
" tab setting
set expandtab
set autoindent
set tabstop=2
set shiftwidth=2

" set cpo-=<
" map z $
" map <Up> <Nop>
" map <Down> <Nop>
" map <Left> <Nop>
" map <Right> <Nop>
" inoremap <Up> <Nop>
" inoremap <Down> <Nop>
" inoremap <Left> <Nop>
" inoremap <Right> <Nop>



" skip initialization for vim-tiny or small.
if isdirectory( expand("~/.vim/bundle/neobundle.vim") )
  if !1 | finish | endif
  if has('vim_starting')
    set nocompatible
    set runtimepath+=~/.vim/bundle/neobundle.vim/
    " call neobundle#rc(expand('~/.vim/bundle/'))
  endif

  call neobundle#begin(expand('~/.vim/bundle/'))

  " Let NeoBundle manage NeoBundle
  NeoBundleFetch 'Shougo/neobundle.vim'

  " My Bundles here:
  NeoBundle 'Shougo/unite.vim'
  NeoBundle 'The-NERD-tree'

  call neobundle#end()

  filetype plugin indent on

  NeoBundleCheck

  " NERDTree setting
  " 隠しファイルを表示する。
  let NERDTreeShowHidden = 1
  " 引数なしで実行したとき、NERDTreeを実行する
  let file_name = expand("%:p")
  if has('vim_starting') &&  file_name == ""
    autocmd VimEnter * execute 'NERDTree ./'
  endif
endif


