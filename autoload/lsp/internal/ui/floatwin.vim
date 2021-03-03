let s:config = {
\   'completion_documentation': {
\     'priority': 100,
\   },
\   'hover': {
\     'priority': 90,
\   },
\   'diagnostics': {
\     'priority': 80,
\   },
\   'default': {
\     'priority': 1,
\   },
\ }

let s:windows = {}

"
" Get window object.
"
function! lsp#internal#ui#floatwin#get(name) abort
  if !has_key(s:windows, a:name)
    let s:windows[a:name] = s:create(a:name, get(s:config, a:name, 'default'))
  endif
  return s:windows[a:name]
endfunction

"
" Create window with config
"
function! s:create(name, config) abort
  let l:win = vital#lsp#import('VS.Vim.Window.FloatingWindow').new({
  \   'on_opened': function('s:on_opened', [a:name]),
  \   'on_closed': function('s:on_closed', [a:name]),
  \ })
  call l:win.set_var('lsp_win', a:config)

  " Hijack open function to check priorities.
  let l:win._open = l:win.open
  let l:win.open = function('s:open', [a:name], l:win)
  return l:win
endfunction

"
" Open with checking priorities.
"
function! s:open(name, ...) abort dict
  let l:open_win = s:windows[a:name]
  for [l:name, l:win] in items(s:windows)
    if l:win.is_visible()
      if l:open_win.get_var('lsp_win').priority < l:win.get_var('lsp_win').priority
        return
      endif
    endif
  endfor
  call call(l:self._open, a:000, l:self)
endfunction

"
" Notify opened and close low priority windows if exists.
"
function! s:on_opened(name) abort
  if !has_key(s:windows, a:name)
    return
  endif

  let l:opened_win = s:windows[a:name]
  for [l:name, l:win] in items(s:windows)
    if l:win.is_visible()
      if l:opened_win.get_var('lsp_win').priority > l:win.get_var('lsp_win').priority
        call l:win.close()
      endif
    endif
  endfor
  call execute('doautocmd <nomodeline> User lsp_float_opened')
endfunction

"
" Notify closed.
"
function! s:on_closed(name) abort
  call execute('doautocmd <nomodeline> User lsp_float_closed')
endfunction

