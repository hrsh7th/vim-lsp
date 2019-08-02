function! s:not_supported(what) abort
    return lsp#utils#error(a:what.' not supported for '.&filetype)
endfunction

function! lsp#ui#vim#signature_help#get_signature_help_under_cursor() abort
    let l:servers = lsp#get_whitelisted_servers()
    let l:servers = filter(l:servers, function('s:should_trigger_characters'))

    for l:server in l:servers
        call lsp#send_request(l:server, {
            \ 'method': 'textDocument/signatureHelp',
            \ 'params': {
            \   'textDocument': lsp#get_text_document_identifier(),
            \   'position': lsp#get_position(),
            \ },
            \ 'on_notification': function('s:handle_signature_help', [l:server]),
            \ })
    endfor
endfunction

function! s:should_trigger_characters(i, server)
  let l:line = getline('.')
  let l:line = l:line[0 : min([strlen(l:line), col('.') - 1]) - 1]
  if strlen(substitute(l:line, '\s*$', '', 'g')) == 0
    return v:true
  endif
  let l:char = nr2char(strgetchar(l:line, strchars(l:line) - 1))
  let l:trigger_characters = s:get(lsp#get_server_capabilities(a:server), ['signatureHelpProvider', 'triggerCharacters'], [])
  return index(l:trigger_characters, l:char) != -1
endfunction

function! s:handle_signature_help(server, data) abort
    if index(['i', 'ic', 'ix'], mode()) == -1
      return
    endif
    if lsp#client#is_error(a:data['response'])
        return
    endif

    let l:response = s:get(a:data, ['response', 'result'], {})
    let l:signatures = s:get(l:response, ['signatures'], [])
    let l:active_signature = s:get(l:response, ['activeSignature'], 0)
    let l:active_parameter = s:get(l:response, ['activeParameter'], 0)

    let l:signature = s:get(l:signatures, [l:active_signature], {})
    let l:parameter = s:get(l:signature, ['parameters', l:active_parameter], {})

    if !s:has(l:signature, ['label']) || !s:has(l:parameter, ['label'])
      return
    endif

    let l:signature_label_parts = split(l:signature['label'], l:parameter['label'])
    let l:signature_label = join([l:signature_label_parts[0], '`' . l:parameter['label'] . '`', l:signature_label_parts[1]], '')
    call lsp#ui#vim#output#preview(l:signature_label, { 'insert_mode': v:true, 'window_align': 'top' })
endfunction

function! s:has(dict, keys)
  let target = a:dict
  for key in a:keys
    if index([v:t_dict, v:t_list], type(target)) == -1 | return v:false | endif
    let _ = get(target, key, v:null)
    unlet! target
    let target = _
    if target is v:null | return v:false | endif
  endfor
  return v:true
endfunction

function! s:get(dict, keys, def)
  let target = a:dict
  for key in a:keys
    if index([v:t_dict, v:t_list], type(target)) == -1 | return a:def | endif
    let _ = get(target, key, v:null)
    unlet! target
    let target = _
    if target is v:null | return a:def | endif
  endfor
  return target
endfunction
