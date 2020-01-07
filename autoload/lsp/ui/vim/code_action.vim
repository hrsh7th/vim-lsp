function! lsp#ui#vim#code_action#complete(input, command, len) abort
    let l:server_names = filter(lsp#get_whitelisted_servers(), 'lsp#capabilities#has_code_action_provider(v:val)')
    let l:kinds = []
    for l:server_name in l:server_names
        let l:kinds += lsp#capabilities#get_code_action_kinds(l:server_name)
    endfor
    return filter(copy(l:kinds), { _, kind -> kind =~ '^' . a:input })
endfunction

"
" @param range  Provides by command invoking like `<','>LspCodeAction` or `10LspCodeAction`
" @param query  Specified CodeAction#kind string. Invoke CodeAction immediately when query provided and matched CodeAction is only one.
"
function! lsp#ui#vim#code_action#do(range, query) abort
    let l:server_names = filter(lsp#get_whitelisted_servers(), 'lsp#capabilities#has_code_action_provider(v:val)')
    if len(l:server_names) == 0
        return lsp#utils#error('Code action not supported for ' . &filetype)
    endif

    let l:command_id = lsp#_new_command()
    for l:server_name in l:server_names
        let l:diagnostic = lsp#ui#vim#diagnostics#get_diagnostics_under_cursor(l:server_name)
        let l:visual_range = s:get_visual_range(a:range)
        call lsp#send_request(l:server_name, {
                    \ 'method': 'textDocument/codeAction',
                    \ 'params': {
                    \   'textDocument': lsp#get_text_document_identifier(),
                    \   'range': empty(l:diagnostic) ? l:visual_range : l:diagnostic['range'],
                    \   'context': {
                    \       'diagnostics' : empty(l:diagnostic) ? [] : [l:diagnostic],
                    \       'only': ['', 'quickfix', 'refactor', 'refactor.extract', 'refactor.inline', 'refactor.rewrite', 'source', 'source.organizeImports'],
                    \   },
                    \ },
                    \ 'on_notification': function('s:handle_code_action', [l:server_name, l:command_id, a:query]),
                    \ })
    endfor
    echo 'Retrieving code actions ...'
endfunction

function! s:handle_code_action(server_name, command_id, query, data) abort
    " Check dupulicate request.
    if a:command_id != lsp#_last_command()
        return
    endif

    " Check response error.
    if lsp#client#is_error(a:data['response'])
        call lsp#utils#error('Failed to CodeAction for ' . a:server_name . ': ' . lsp#client#error_message(a:data['response']))
        return
    endif

    " Check code actions.
    let l:code_actions = a:data['response']['result']
    call lsp#log('s:handle_code_action', l:code_actions)
    if len(l:code_actions) == 0
        echo 'No code actions found'
        return
    endif

    " Filter code actions.
    if !empty(a:query)
        let l:code_actions = filter(l:code_actions, { _, action -> get(action, 'kind', '') =~# '^' . a:query })
    endif

    " Prompt to choose code actions when empty query provided.
    let l:index = 1
    if len(l:code_actions) > 1 && empty(a:query)
        let l:index = inputlist(map(copy(l:code_actions), { i, action ->
                    \   printf('%s - %s', i + 1, action['title'])
                    \ }))
    endif

    " Execute code action.
    if 0 < l:index && l:index <= len(l:code_actions)
        call s:handle_one_code_action(a:server_name, l:code_actions[l:index - 1])
    endif
endfunction

function! s:handle_one_code_action(server_name, command_or_code_action) abort
    " has WorkspaceEdit.
    if has_key(a:command_or_code_action, 'edit')
        call lsp#utils#workspace_edit#apply_workspace_edit(a:command_or_code_action['edit'])

    " Command.
    elseif has_key(a:command_or_code_action, 'command') && type(a:command_or_code_action['command']) == type('')
        call lsp#send_request(a:server_name, {
                    \   'method': 'workspace/executeCommand',
                    \   'params': a:command_or_code_action
                    \ })

    " has Command.
    elseif has_key(a:command_or_code_action, 'command') && type(a:command_or_code_action['command']) == type({})
        call lsp#send_request(a:server_name, {
                    \   'method': 'workspace/executeCommand',
                    \   'params': a:command_or_code_action['command']
                    \ })
    endif
endfunction

function! s:get_visual_range(range) abort
    " Use current line range if range is not specified.
    if a:range == 0
        let l:pos = getpos('.')[1 : 2]
        let l:range = {}
        let l:range['start'] = lsp#utils#position#_vim_to_lsp('%', l:pos)
        let l:range['end'] = lsp#utils#position#_vim_to_lsp('%', [l:pos[0], l:pos[1] + strlen(getline(l:pos[0])) + 1])
    endif

    let l:start_pos = getpos("'<")[1 : 2]
    let l:end_pos = getpos("'>")[1 : 2]
    let l:end_pos[1] += 1 " To exclusive

    " Fix line selection.
    let l:end_line = getline(l:end_pos[0])
    if l:end_pos[1] > strlen(l:end_line)
        let l:end_pos[1] = strlen(l:end_line) + 1
    endif

    let l:range = {}
    let l:range['start'] = lsp#utils#position#_vim_to_lsp('%', l:start_pos)
    let l:range['end'] = lsp#utils#position#_vim_to_lsp('%', l:end_pos)
    return l:range
endfunction

