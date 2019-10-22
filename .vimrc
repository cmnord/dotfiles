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
Plugin 'rust-lang/rust.vim'
Plugin 'airblade/vim-gitgutter'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'altercation/vim-colors-solarized'

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

set number
set cursorline
set wildmenu
set ruler

set lbr " line break
set tw=500

set mouse=a " Use mouse to scroll, select, etc.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" COLOR
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use syntax highlighting
syntax enable
set background=light
colorscheme solarized

" Some python thing
let python_highlight_all=1

let g:solarized_termtrans = 1

" Airline things
let g:airline_powerline_fonts=1
let g:airline_theme='solarized'

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
set textwidth=80

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
" MAPPINGS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Delete trailing whitespace on save
func! DeleteTrailingWS()
    exe "normal mz"
    %s/\s\+$//ge
    exe "normal`z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()
autocmd BufWrite *.coffee :call DeleteTrailingWS()

