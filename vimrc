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
  if 0 | endif
  if &compatible
    set nocompatible
  endif

  " Required
  set runtimepath+=~/.vim/bundle/neobundle.vim/

  " Required
  call neobundle#begin(expand('~/.vim/bundle/'))

  " Let NeoBundle manage NeoBundle
  NeoBundleFetch 'Shougo/neobundle.vim'

  " My Bundles here:
  NeoBundle 'editorconfig/editorconfig-vim'
  NeoBundle 'tpope/vim-surround'
  NeoBundle 'airblade/vim-gitgutter'
  "" code syntax
  NeoBundle 'kchmck/vim-coffee-script'

  call neobundle#end()

  filetype plugin indent on

  NeoBundleCheck
endif


