" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.4
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


if exists('g:loaded_pear_tree') || v:version < 704
    finish
endif
let g:loaded_pear_tree = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:pear_tree_pairs')
    let g:pear_tree_pairs = {
                \ '(': {'closer': ')'},
                \ '[': {'closer': ']'},
                \ '{': {'closer': '}'},
                \ "'": {'closer': "'"},
                \ '"': {'closer': '"'}
                \ }
endif

if !exists('g:pear_tree_ft_disabled')
    let g:pear_tree_ft_disabled = []
endif

if !exists('g:pear_tree_smart_backspace')
    let g:pear_tree_smart_backspace = 0
endif

if !exists('g:pear_tree_smart_openers')
    let g:pear_tree_smart_openers = 0
endif

if !exists('g:pear_tree_smart_closers')
    let g:pear_tree_smart_closers = 0
endif


function! s:BufferEnable()
    if get(b:, 'pear_tree_enabled', 0)
        return
    endif
    call s:CreatePlugMappings()
    if !exists('b:pear_tree_enabled')
        call s:MapDefaults()
    endif
    let b:pear_tree_enabled = 1
endfunction


function! s:BufferDisable()
    if !get(b:, 'pear_tree_enabled', 0)
        return
    endif
    let l:pairs = get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
    for [l:opener, l:closer] in map(items(l:pairs), '[v:val[0][-1:], v:val[1].closer]')
        execute 'inoremap <silent> <buffer> <Plug>(PearTreeOpener_' . l:opener . ') ' . l:opener
        execute 'inoremap <silent> <buffer> <Plug>(PearTreeCloser_' . l:closer . ') ' . l:closer
    endfor
    inoremap <silent> <buffer> <Plug>(PearTreeBackspace) <BS>
    inoremap <silent> <buffer> <Plug>(PearTreeExpand) <CR>
    inoremap <silent> <buffer> <Plug>(PearTreeFinishExpansion) <ESC>
    inoremap <silent> <buffer> <Plug>(PearTreeExpandOne) <NOP>
    inoremap <silent> <buffer> <Plug>(PearTreeJump) <NOP>
    inoremap <silent> <buffer> <Plug>(PearTreeJNR) <NOP>
    let b:pear_tree_enabled = 0
endfunction


function! s:CreatePlugMappings()
    let l:pairs = get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
    for [l:opener, l:closer] in map(items(l:pairs), '[v:val[0][-1:], v:val[1].closer]')
        let l:escaped_opener = substitute(l:opener, "'", "''", 'g')
        execute 'inoremap <silent> <expr> <buffer> '
                    \ . '<Plug>(PearTreeOpener_' . l:opener . ') '
                    \ . 'pear_tree#insert_mode#TerminateOpener('''
                    \ . l:escaped_opener . ''')'

        if strlen(l:closer) == 1 && !has_key(l:pairs, l:closer)
            let l:escaped_closer = substitute(l:closer, "'", "''", 'g')
            execute 'inoremap <silent> <expr> <buffer> '
                        \ . '<Plug>(PearTreeCloser_' . l:closer . ') '
                        \ . 'pear_tree#insert_mode#HandleCloser('''
                        \ . l:escaped_closer . ''')'
        endif
    endfor
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeBackspace) pear_tree#insert_mode#Backspace()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeExpand) pear_tree#insert_mode#PrepareExpansion()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeFinishExpansion) pear_tree#insert_mode#Expand()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeExpandOne) pear_tree#insert_mode#ExpandOne()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeJump) pear_tree#insert_mode#JumpOut()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeJNR) pear_tree#insert_mode#JumpNReturn()
endfunction


function! s:MapDefaults()
    let l:pairs = get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
    for l:closer in map(values(l:pairs), 'v:val.closer')
        let l:closer_plug = '<Plug>(PearTreeCloser_' . l:closer . ')'
        if mapcheck(l:closer_plug, 'i') !=# '' && !hasmapto(l:closer_plug, 'i')
            execute 'imap <buffer> ' . l:closer . ' ' l:closer_plug
        endif
    endfor
    for l:opener in map(keys(l:pairs), 'v:val[-1:]')
        let l:opener_plug = '<Plug>(PearTreeOpener_' . l:opener . ')'
        if !hasmapto(l:opener_plug, 'i')
            execute 'imap <buffer> ' . l:opener . ' ' l:opener_plug
        endif
    endfor

    " Stop here if special keys aren't mappable.
    if stridx(&cpoptions, '<') > -1
        return
    endif
    if !hasmapto('<Plug>(PearTreeBackspace)', 'i')
        imap <buffer> <BS> <Plug>(PearTreeBackspace)
    endif
    if !hasmapto('<Plug>(PearTreeExpand)', 'i')
        imap <buffer> <CR> <Plug>(PearTreeExpand)
    endif
    if !hasmapto('<Plug>(PearTreeFinishExpansion)', 'i')
        if !has('nvim') && !has('gui_running')
            " Prevent <ESC> mapping from breaking cursor keys in insert mode
            imap <buffer> <ESC><ESC> <Plug>(PearTreeFinishExpansion)
            imap <buffer> <nowait> <ESC> <Plug>(PearTreeFinishExpansion)
        else
            imap <buffer> <ESC> <Plug>(PearTreeFinishExpansion)
        endif
    endif
endfunction


command -bar PearTreeEnable call s:BufferEnable()
command -bar PearTreeDisable call s:BufferDisable()

augroup pear_tree
    autocmd!
    autocmd FileType *
                \ call <SID>BufferEnable() |
                \ if index(g:pear_tree_ft_disabled, &filetype) > -1 |
                \     call <SID>BufferDisable() |
                \ endif
    autocmd BufRead,BufNewFile,BufEnter *
                \ if !exists('b:pear_tree_enabled') && index(g:pear_tree_ft_disabled, &filetype) == -1 |
                \     call <SID>BufferEnable() |
                \ endif
    autocmd InsertEnter *
                \ if get(b:, 'pear_tree_enabled', 0) |
                \     call pear_tree#insert_mode#Prepare() |
                \ endif
    autocmd CursorMovedI,InsertEnter *
                \ if get(b:, 'pear_tree_enabled', 0) |
                \     call pear_tree#insert_mode#OnCursorMovedI() |
                \ endif
    autocmd InsertCharPre *
                \ if get(b:, 'pear_tree_enabled', 0) |
                \     call pear_tree#insert_mode#OnInsertCharPre() |
                \ endif
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
