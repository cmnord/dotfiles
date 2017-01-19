set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" Markdown stuff
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'

Plugin 'altercation/vim-colors-solarized'
Plugin 'scrooloose/syntastic'
Plugin 'vim-scripts/indentpython.vim'
Plugin 'nvie/vim-flake8'
Plugin 'tmhedberg/SimpylFold'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'Valloric/YouCompleteMe'

" TO INSTALL, RUN `:PluginInstall`

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" Put your non-Plugin stuff after this line

set nocompatible " ?
set encoding=utf8
set ffs=unix,dos,mac

" Turn off backup since stuff is in git anyway
set nobackup
set nowb
set noswapfile

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" USABILITY
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable pasting
setlocal paste!

" Fix backspace
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

set number
set cursorline
set wildmenu
set ruler
set cmdheight=2

set lbr " line break
set tw=500

set mouse=a " Use mouse to scroll, select, etc.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" COLOR
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax enable

if has('gui_running')
    set background=light
    colorscheme solarized
else
    set background=light
    colorscheme solarized " used to be inkpot
endif

let g:solarized_termtrans = 1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TABS AND INDENT
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set expandtab " spaces instead of tabs
set smarttab

" Indent automatically depending on filetype
filetype indent on
set autoindent

set shiftwidth=4
set tabstop=4
set softtabstop=4
set ai
set si
set wrap " wrap lines

au BufNewFile,BufRead *.py
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=79 |
    \ set autoindent |
    \ set fileformat=unix |

au BufNewFile,BufRead *.js,*.html,*.css
    \ set tabstop=2 |
    \ set tabstop=2 |
    \ set shiftwidth=2 |

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" SYNTAX
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Some python and syntax checking thing
let python_highlight_all=1
syntax on

"define BadWhitespace before using in a match
highlight BadWhitespace ctermbg=red guibg=darkred
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" Highlight matching brackets when highlighted (blink for 2/10 of sec)
set showmatch
set mat=2

" No sound on errors
set noerrorbells
set novisualbell
set t_vb=0
set tm=500

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" SEARCH
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Case insensitive search
set ic
set smartcase

" Search - highlight and fancy
set hls
set incsearch

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" FOLDING
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable folding
set foldmethod=indent
set foldlevel=99
" Enable folding with space
nnoremap <space> za

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MAGIC (I don't really know what these do)
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has("gui_running")
    set guioptions-=T
    set guioptions+=e
    set t_Co=256
    set guitablabel=%M\ %t
endif

" Editing mappings
" Remap vim 0 to first non-blank character
map 0 ^

" Delete trailing whitespace on save
func! DeleteTrailingWS()
    exe "normal mz"
    %s/\s\+$//ge
    exe "normal`z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()
autocmd BufWrite *.coffee :call DeleteTrailingWS()

set diffexpr=MyDiff()
function MyDiff()
  let opt = '-a --binary '
  if &diffopt =~ 'icase' | let opt = opt . '-i ' | endif
  if &diffopt =~ 'iwhite' | let opt = opt . '-b ' | endif
  let arg1 = v:fname_in
  if arg1 =~ ' ' | let arg1 = '"' . arg1 . '"' | endif
  let arg2 = v:fname_new
  if arg2 =~ ' ' | let arg2 = '"' . arg2 . '"' | endif
  let arg3 = v:fname_out
  if arg3 =~ ' ' | let arg3 = '"' . arg3 . '"' | endif
  let eq = ''
  if $VIMRUNTIME =~ ' '
    if &sh =~ '\<cmd'
      let cmd = '""' . $VIMRUNTIME . '\diff"'
      let eq = '"'
    else
      let cmd = substitute($VIMRUNTIME, ' ', '" ', '') . '\diff"'
    endif
  else
    let cmd = $VIMRUNTIME . '\diff'
  endif
  silent execute '!' . cmd . ' ' . opt . arg1 . ' ' . arg2 . ' > ' . arg3 . eq
endfunction


