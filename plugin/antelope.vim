if exists('g:loaded_antelope') | finish | endif

function! s:complete(...)
  return "buffers\nmarks\ntabpages"
endfunction

command! -nargs=1 -complete=custom,s:complete Antelope lua require'antelope'.<args>()

let g:loaded_antelope = 1
