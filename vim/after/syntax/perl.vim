" Added rules for Perl Syntax highlighting.

" I want the member methods/vars of an object to be a different colour.
syn match perlArrowBare "->" containedin=perlVarPlain
syn match perlMember "->\i\+"  contains=perlArrowBare containedin=perlString,perlVarPlain,perlArrow,perlVarSimpleMemberName,perlMethod,perlVarPlain2,perlVarMember,perlVarSimpleMember
hi link perlArrowBare    String
hi link perlMember       Function


" Also, I want labels after control statements to be label colour
syn match perlControlLabel "\(last\|next\|refo\|goto\|break\)\s\i\+" contains=perlStatementControl
hi link perlControlLabel Label


" =POD != #comment; So make POD a different colour to comments.
hi link perlPOD SpecialComment

" Make the =over / back blocks differnt so I can see how 'deep' I am FNAR ;-)
" The multi-entry for multi-level is BitShit™ but meh, it works and if I find
" myself 8 levels deep in my data structure it needs help.
syn region perlPODOver1 matchgroup=perlPODOver1 start="^=over" end="^=back" contained containedin=perlPOD keepend
syn region perlPODOver2 matchgroup=perlPODOver2 start="^=over" end="^=back" contained containedin=perlPODOver1 keepend extend
syn region perlPODOver3 matchgroup=perlPODOver3 start="^=over" end="^=back" contained containedin=perlPODOver2 keepend extend
syn region perlPODOver4 matchgroup=perlPODOver4 start="^=over" end="^=back" contained containedin=perlPODOver3 keepend extend
syn region perlPODOver5 matchgroup=perlPODOver5 start="^=over" end="^=back" contained containedin=perlPODOver4 keepend extend
syn region perlPODOver6 matchgroup=perlPODOver6 start="^=over" end="^=back" contained containedin=perlPODOver5 keepend extend
syn region perlPODOver7 matchgroup=perlPODOver7 start="^=over" end="^=back" contained containedin=perlPODOver6 keepend extend

" Set the colours for the POD levels hax here, it should really be in my
" colorscheme file, but that means linking the 7 levels to standard tags, and I
" don't want that. I tried a nice casecade of colour, but that wasn't obvious
" enough when shit was wrong, so blatent differeneces
hi perlPODOver1 cterm=NONE ctermfg=34  ctermbg=NONE
hi perlPODOver2 cterm=NONE ctermfg=142 ctermbg=NONE
hi perlPODOver3 cterm=NONE ctermfg=202 ctermbg=NONE
hi perlPODOver4 cterm=NONE ctermfg=90  ctermbg=NONE
hi perlPODOver5 cterm=NONE ctermfg=180 ctermbg=NONE
hi perlPODOver6 cterm=NONE ctermfg=160 ctermbg=NONE
hi perlPODOver7 cterm=NONE ctermfg=290 ctermbg=NONE

