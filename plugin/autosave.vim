" vim-autosave - Save you work periodically
" -------------------------------------------------------------
" Version: 0.1
" Maintainer:  Christian Brabandt <cb@256bit.org>
" Last Change: Thu, 05 Mar 2015 08:11:46 +0100
" Script: http://www.vim.org/scripts/script.php?script_id=
" Copyright:   (c) 2009-2016 by Christian Brabandt
"          The VIM LICENSE applies to vim-autosave.vim
"          (see |copyright|) except use "vim-autosave"
"          instead of "Vim".
"          No warranty, express or implied.
"    *** ***   Use At-Your-Own-Risk!   *** ***
" Init: {{{1
let s:cpo= &cpo
if exists("g:loaded_autosave") || &cp
    finish
elseif !has('timers')
    echohl WarningMsg
    echomsg "The vim-autosave Plugin needs at least a Vim version 8 (with +timers)"
    echohl Normal
    finish
endif
set cpo&vim
let g:loaded_autosave = 1

" Configuration variables {{{1
let g:autosave_extension  = get(g:, 'autosave_extension', '.backup')
" by default write every 5 minutes
let g:autosave_timer      = get(g:, 'autosave_timer', 60*5) * 1000
let g:autosave_changenr   = {}

" public interface {{{1
com! -nargs=? AutoSave call <sid>SetupTimer(<q-args>)
com! DisableAutoSave AutoSave 0
com! EnableAutoSave  AutoSave g:autosave_timer

" functions {{{1
func! Autosave_DoSave(timer) abort "{{{2
  let bufnr=bufnr('')
  let g:autosave_backupdir=split(&bdir, '\\\@<!,')
  let g:autosave_errors=[]
  " replace escaped commas with commas
  call map(g:autosave_backupdir, 'substitute(v:val, ''\\,'', ",", "g")')
  for nr in range(1, bufnr('$'))
    call <sid>SaveBuffer(nr)
  endfor
  call <sid>Warning(g:autosave_errors)
endfunc

func! <sid>SaveBuffer(nr) abort "{{{2
  if !bufexists(a:nr)
    return
  endif
  " don't try to save special buffers (help)
  " unmodified files or buffers without a name
  " or buffers, for which the buffer-local variable
  " 'autosave_disabled' has been set
  let bufname = bufname(a:nr + 0)
  if !getbufvar(a:nr, '&modified') ||
  \  !empty(getbufvar(a:nr, '&buftype')) ||
  \  getbufvar(a:nr, 'autosave_disabled', 0)
      return
  endif
  if get(get(g:, 'autosave_changenr', {}), a:nr+0) == getbufvar(a:nr+0, 'changedtick')
    " buffer saved last time and hasn't changed
    return
  endif
  let saved=0
  for dir in g:autosave_backupdir
    if dir is# '.'
      let dir = fnamemodify(bufname, ':p:h')
    endif
    let filename = fnamemodify(bufname, ':t')
    if empty(filename)
      let filename='unnamed_buffer_'.strftime('%Y%m%d_%H%M').'.txt'
    endif
    if !isdirectory(dir)
      continue
    endif
    try
      let cnt = getbufline(a:nr, 1, '$')
      let name = dir. '/'. fnameescape(filename). g:autosave_extension
      if getbufvar(a:nr, '&ff') is# 'unix'
        " write as unix file
        call writefile(cnt, name)
      else
        " write as dos file
        call writefile(map(cnt, 'v:val."\r"'), name)
      endif
      let saved=1
      if get(g:, 'autosave_debug', 0)
        echomsg printf("%s saved at %s", name, strftime('%H:%M:%S'))
      endif
      let g:autosave_changenr[a:nr+0] = getbufvar(a:nr+0, 'changedtick')
      break
    catch
    endtry
  endfor
  if !saved
    call add(g:autosave_errors, filename)
  endif
endfunc

func! <sid>Num(nr) abort "{{{2
  return a:nr/1000
endfu

func! <sid>SetupTimer(enable) abort "{{{2
  let msg = ''
  if empty(a:enable)
    if exists('s:autosave_timer')
      let info = timer_info(s:autosave_timer)
      if empty(info)
        let msg = 'AutoSave disabled'
      elseif info[0].callback is# function('Autosave_DoSave')
        let msg  = printf("AutoSave: %s (every %d seconds), triggers again in %d seconds",
              \ (info[0].paused ? 'paused' : 'active'), <sid>Num(info[0].time),
              \ <sid>Num(info[0].remaining))
      else
        let msg = printf("Unknown timer")
      endif
    else
      let msg = "No AutoSave Timer active"
    endif
  elseif a:enable
    if a:enable > 100 * 60 * 1000 || a:enable < 1000
      let msg = "Warning: Timer value must be given in millisecods and can't be > 100*60*1000 (100 minutes) or < 1000 (1 second)"
    else
      let g:autosave_timer = a:enable
      let s:autosave_timer=timer_start(g:autosave_timer, 'Autosave_DoSave', {'repeat': -1})
    endif
  elseif exists('s:autosave_timer')
    call timer_stop(s:autosave_timer)
  endif
  if !empty(msg)
    call <sid>MessOut(msg)
  endif
endfunc

func! <sid>MessOut(msg) abort "{{{2
  echohl WarningMsg
  if type(a:msg) == type([])
    for item in a:msg | unsilent echomsg item | endfor
  else
    unsilent echomsg a:msg
  endif
  echohl Normal
endfu

func! <sid>Warning(list) abort "{{{2
  if empty(a:list)
    return
  endif
  let list = ["AutoSave: The following files could not be written."] + a:list
  <sid>MessOut(list)
	sleep 1
	let v:errmsg = list[0]
endfun

call <sid>SetupTimer(g:autosave_timer)
" Restore: "{{{1
let &cpo=s:cpo
unlet s:cpo
" vim: ts=2 sts=2 sw=2 et fdm=marker com+=l\:\"
