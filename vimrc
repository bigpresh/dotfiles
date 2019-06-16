
" 256 color support stuff (thanks to Jim for this)
set t_Co=256
let mapleader=","
let g:solarized_termcolors=256

set number

filetype plugin indent on
syntax enable

set nowrap
set textwidth=80
set shiftwidth=4
set shiftround
set expandtab
set tabstop=8
"set autoindent
set smarttab     "Backspace at start of line outdents"
set ruler        "Show current position in file at bottom"

" More normal backspace behaviour:
set backspace=indent,eol,start

" Allow me to switch from a buffer with unsaved changes without
" saving/abandoning them - just makes the buffer hidden:
set hidden

" for coding, have things in braces indenting themselves:
"autocmd FileType perl set smartindent
autocmd FileType php  set smartindent

" have the h and l cursor keys wrap between lines (like <Space> and <BkSpc> do
" by default), and ~ covert case over line breaks; also have the cursor keys
" wrap in insert mode:
set whichwrap=h,l,~,[,]

" Don't make noise:
set visualbell

" I always use terminals with dark backgrounds:
set background=dark

" make the completion menus readable
highlight Pmenu ctermfg=0 ctermbg=3
highlight PmenuSel ctermfg=0 ctermbg=7

"The following should be done automatically for the default colour scheme
"at least, but it is not in Vim 7.0.17.
if &bg == "dark"
  highlight MatchParen ctermbg=darkblue guibg=blue
endif

" Show cursor position easily:
"if v:version >= 700
" set cursorline
"    set cursorcolumn
"endif

" Don't need the toolbar, it takes up valuable space:
set guioptions-=T

" Highlight lines that go over 80 chars:
highlight OverLength ctermbg=red ctermfg=white guibg=#592929
match OverLength /\%81v.*/


" colorscheme murphy
set guifont=Source\ Code\ Pro\ 9

"Useful shortcuts:
:imap ;na Account->new( accountname => '' );<left><left><left><left> 

" Delete lines from insert mode with Ctrl+k
:imap <silent> <C-k> <Esc>ddi

" Quick buffer switching with ^b using the BufExplorer plugin
:nmap <C-b> <Esc>:BufExplorer<CR>

" Toggle paste mode and jump to insert mode with ^p
:nmap <C-p> :set paste!<cr>i

" F2 to save; shift+F2 to save + quit
:set <S-F2>=1;2Q
:nmap <F2> <Esc>:w<cr>
:nmap <S-F2> <Esc>:wq<cr>

" Allow w!! to write to files you wouldn't usually have access to - handy
:cmap w!! %!sudo tee > /dev/null %


" Write versioned backups to backups dir in case of stupity (but not if it's
" a file in /dev/shm because that's unlikely of long-term interest)
set backup
:silent exec "!mkdir -p ~/tmp/vimbackups"
set backupdir=~/tmp/vimbackups
" Update the backup file extension each time Esc is hit to make sure it's fresh
fun! InitBex()
  let append_timestamp = strftime("%Y%m%d-%H%M%S")
  let cmd = "set backupext=_". append_timestamp
  execute cmd
 
  if expand('%:p:h') =~ '/dev/shm'
    " Editing an ephemeral file in /dev/shm - probably don't need to back it up,
    " as long of long-term interest would be there, and it may even be pass
    " invoking us to edit a password store entry, and we don't want to back that
    " up in plain text!
    set nobackup
  else
    set backup
  endif
endfun
autocmd BufWritePre * call InitBex()

" Let me open the Perl module under my cursor trivally with c-o
nmap <C-o> :call LoadPerlModule()<CR>

function! LoadPerlModule()
    execute 'e `perldoc -l ' . expand("<cWORD>") . '`'
endfunction

