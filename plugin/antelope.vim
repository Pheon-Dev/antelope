if exists('g:loaded_antelope') | finish | endif

function! s:complete(...)
  return "buffers\nmarks"
endfunction

command! -nargs=1 -complete=custom,s:complete ReachOpen lua require'antelope'.<args>()

let g:loaded_antelope = 1
