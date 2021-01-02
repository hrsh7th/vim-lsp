let s:is_win = has('win32') || has('win64')
let s:diagnostics = {} " { uri: { 'server_name': response } }

function! lsp#ui#vim#diagnostics#handle_text_document_publish_diagnostics(server_name, data) abort
    if lsp#client#is_error(a:data['response'])
        return
    endif
    let l:uri = a:data['response']['params']['uri']
    let l:uri = lsp#utils#normalize_uri(l:uri)
    if !has_key(s:diagnostics, l:uri)
        let s:diagnostics[l:uri] = {}
    endif
    let s:diagnostics[l:uri][a:server_name] = a:data

    doautocmd <nomodeline> User lsp_diagnostics_updated
endfunction

function! s:severity_of(diagnostic) abort
    return get(a:diagnostic, 'severity', 1)
endfunction

function! lsp#ui#vim#diagnostics#next_error(...) abort
    let l:diagnostics = filter(s:get_all_buffer_diagnostics(),
        \ {_, diagnostic -> s:severity_of(diagnostic) ==# 1 })
    let l:options = lsp#utils#parse_command_options(a:000)
    call s:next_diagnostic(l:diagnostics, l:options)
endfunction

function! lsp#ui#vim#diagnostics#next_warning(...) abort
    let l:diagnostics = filter(s:get_all_buffer_diagnostics(),
        \ {_, diagnostic -> s:severity_of(diagnostic) ==# 2 })
    let l:options = lsp#utils#parse_command_options(a:000)
    call s:next_diagnostic(l:diagnostics, l:options)
endfunction

function! lsp#ui#vim#diagnostics#next_diagnostic(...) abort
    let l:options = lsp#utils#parse_command_options(a:000)
    call s:next_diagnostic(s:get_all_buffer_diagnostics(), l:options)
endfunction

function! s:next_diagnostic(diagnostics, options) abort
    if !len(a:diagnostics)
        return
    endif
    call sort(a:diagnostics, 's:compare_diagnostics')

    let l:wrap = 1
    if has_key(a:options, 'wrap')
        let l:wrap = a:options['wrap']
    endif

    let l:view = winsaveview()
    let l:next_line = 0
    let l:next_col = 0
    for l:diagnostic in a:diagnostics
        let [l:line, l:col] = lsp#utils#position#lsp_to_vim('%', l:diagnostic['range']['start'])
        if l:line > l:view['lnum']
            \ || (l:line == l:view['lnum'] && l:col > l:view['col'] + 1)
            let l:next_line = l:line
            let l:next_col = l:col - 1
            break
        endif
    endfor

    if l:next_line == 0
        if !l:wrap
            return
        endif
        " Wrap to start
        let [l:next_line, l:next_col] = lsp#utils#position#lsp_to_vim('%', a:diagnostics[0]['range']['start'])
        let l:next_col -= 1
    endif

    let l:view['lnum'] = l:next_line
    let l:view['col'] = l:next_col
    let l:view['topline'] = 1
    let l:height = winheight(0)
    let l:totalnum = line('$')
    if l:totalnum > l:height
        let l:half = l:height / 2
        if l:totalnum - l:half < l:view['lnum']
            let l:view['topline'] = l:totalnum - l:height + 1
        else
            let l:view['topline'] = l:view['lnum'] - l:half
        endif
    endif
    call winrestview(l:view)
endfunction

function! lsp#ui#vim#diagnostics#previous_error(...) abort
    let l:diagnostics = filter(s:get_all_buffer_diagnostics(),
        \ {_, diagnostic -> s:severity_of(diagnostic) ==# 1 })
    let l:options = lsp#utils#parse_command_options(a:000)
    call s:previous_diagnostic(l:diagnostics, l:options)
endfunction

function! lsp#ui#vim#diagnostics#previous_warning(...) abort
    let l:options = lsp#utils#parse_command_options(a:000)
    let l:diagnostics = filter(s:get_all_buffer_diagnostics(),
        \ {_, diagnostic -> s:severity_of(diagnostic) ==# 2 })
    call s:previous_diagnostic(l:diagnostics, l:options)
endfunction

function! lsp#ui#vim#diagnostics#previous_diagnostic(...) abort
    let l:options = lsp#utils#parse_command_options(a:000)
    call s:previous_diagnostic(s:get_all_buffer_diagnostics(), l:options)
endfunction

function! s:previous_diagnostic(diagnostics, options) abort
    if !len(a:diagnostics)
        return
    endif
    call sort(a:diagnostics, 's:compare_diagnostics')

    let l:wrap = 1
    if has_key(a:options, 'wrap')
        let l:wrap = a:options['wrap']
    endif

    let l:view = winsaveview()
    let l:next_line = 0
    let l:next_col = 0
    let l:index = len(a:diagnostics) - 1
    while l:index >= 0
        let [l:line, l:col] = lsp#utils#position#lsp_to_vim('%', a:diagnostics[l:index]['range']['start'])
        if l:line < l:view['lnum']
            \ || (l:line == l:view['lnum'] && l:col < l:view['col'])
            let l:next_line = l:line
            let l:next_col = l:col - 1
            break
        endif
        let l:index = l:index - 1
    endwhile

    if l:next_line == 0
        if !l:wrap
            return
        endif
        " Wrap to end
        let [l:next_line, l:next_col] = lsp#utils#position#lsp_to_vim('%', a:diagnostics[-1]['range']['start'])
        let l:next_col -= 1
    endif

    let l:view['lnum'] = l:next_line
    let l:view['col'] = l:next_col
    let l:view['topline'] = 1
    let l:height = winheight(0)
    let l:totalnum = line('$')
    if l:totalnum > l:height
        let l:half = l:height / 2
        if l:totalnum - l:half < l:view['lnum']
            let l:view['topline'] = l:totalnum - l:height + 1
        else
            let l:view['topline'] = l:view['lnum'] - l:half
        endif
    endif
    call winrestview(l:view)
endfunction

function! s:get_diagnostics(uri) abort
    if has_key(s:diagnostics, a:uri)
        return [1, s:diagnostics[a:uri]]
    else
        if s:is_win
            " vim in windows always uses upper case for drive letter, so use lowercase in case lang server uses lowercase
            " https://github.com/theia-ide/typescript-language-server/issues/23
            let l:uri = substitute(a:uri, '^' . a:uri[:8], tolower(a:uri[:8]), '')
            if has_key(s:diagnostics, l:uri)
                return [1, s:diagnostics[l:uri]]
            endif
        endif
    endif
    return [0, {}]
endfunction

" Get diagnostics for the current buffer URI from all servers
function! s:get_all_buffer_diagnostics(...) abort
    let l:target_server_name = get(a:000, 0, '')

    let l:uri = lsp#utils#get_buffer_uri()

    let [l:has_diagnostics, l:diagnostics] = s:get_diagnostics(l:uri)
    if !l:has_diagnostics
        return []
    endif

    let l:all_diagnostics = []
    for [l:server_name, l:data] in items(l:diagnostics)
        if empty(l:target_server_name) || l:server_name ==# l:target_server_name
            call extend(l:all_diagnostics, l:data['response']['params']['diagnostics'])
        endif
    endfor

    return l:all_diagnostics
endfunction

function! s:compare_diagnostics(d1, d2) abort
    let l:range1 = a:d1['range']
    let l:line1 = l:range1['start']['line'] + 1
    let l:col1 = l:range1['start']['character'] + 1
    let l:range2 = a:d2['range']
    let l:line2 = l:range2['start']['line'] + 1
    let l:col2 = l:range2['start']['character'] + 1

    if l:line1 == l:line2
        return l:col1 == l:col2 ? 0 : l:col1 > l:col2 ? 1 : -1
    else
        return l:line1 > l:line2 ? 1 : -1
    endif
endfunction

function! lsp#ui#vim#diagnostics#get_buffer_first_error_line() abort
    let l:uri = lsp#utils#get_buffer_uri()
    let [l:has_diagnostics, l:diagnostics] = s:get_diagnostics(l:uri)
    let l:first_error_line = v:null
    for [l:server_name, l:data] in items(l:diagnostics)
        for l:diag in l:data['response']['params']['diagnostics']
            if s:severity_of(l:diag) ==# 1 && (l:first_error_line ==# v:null || l:first_error_line ># l:diag['range']['start']['line'])
                let l:first_error_line = l:diag['range']['start']['line']
            endif
        endfor
    endfor
    return l:first_error_line ==# v:null ? v:null : l:first_error_line + 1
endfunction
" vim sw=4 ts=4 et
