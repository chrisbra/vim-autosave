" vim-autosave - Save you work periodically
" -------------------------------------------------------------
" Version: 0.1
" Maintainer:  Christian Brabandt <cb@256bit.org>
" Last Change: Thu, 05 Mar 2015 08:11:46 +0100
" Script: http://www.vim.org/scripts/script.php?script_id=
" Copyright:   (c) 2009-2016 by Christian Brabandt
"          The VIM LICENSE applies to EnhancedDifff.vim
"          (see |copyright|) except use "vim-autosave"
"          instead of "Vim".
"          No warranty, express or implied.
"    *** ***   Use At-Your-Own-Risk!   *** ***
" GetLatestVimScripts: ???? 1 :AutoInstall: vim-autosave.vim
"
" Init: {{{1
let s:cpo= &cpo
if exists("g:loaded_autosave") || &cp
    finish
elseif !has('timers')
    echohl WarningMsg
    echomsg "The vim-autosave Plugin needs at least a Vim version 7.4 (with +timers support)"
    echohl Normal
    finish
endif
set cpo&vim
let g:loaded_autosave = 1

" public interface {{{1
com! DisableAutoSave :let g:autosave=0 | call <sid>SetupTimer(g:autosave)
com! EnableAutoSave  :let g:autosave=1 | call <sid>SetupTimer(g:autosave)

" Configuration variabnles
let g:autosave_extension  = get(g:, 'autosave_extension', '.backup')
" by default write every 5 minutes
let g:autosave_timer      = get(g:, 'autosave_timer', 60*5) * 1000
let g:autosave_changenr   = {}

" functions {{{1
func! Autosave_DoSave(timer) "{{{2
  if !get(g:, 'autosave', 1)
    return
  endif
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
func! <sid>SaveBuffer(nr) "{{{2
  if !bufexists(a:nr)
    return
  endif
  " don't try to save special buffers (help)
  " unmodified files or buffers without a name
  " or buffers, for which the buffer-local variable
  " 'autosave_disabled' has been set
  let bufname = bufname(a:nr + 0)
  if !getbufvar(a:nr, '&modified') ||
  \  empty(bufname) ||
  \  !empty(getbufvar(a:nr, '&buftype')) ||
  \  getbufvar(a:nr, 'autosave_disabled', 0)
      return
  endif
  if 0
    " not possible, without jumping to the buffer
    if get(get(g:, 'autosave_changenr', {}), a:nr) == changenr()
      " buffer saved last time and hasn't changed
      return
    endif
  endif
  let saved=0
  for dir in g:autosave_backupdir
    if dir is# '.'
      let dir = fnamemodify(bufname, ':p:h')
    endif
    let filename = fnamemodify(bufname, '%:t')
    if !isdirectory(dir)
      continue
    endif
    try
      let cnt = getbufline(a:nr, 1, '$')
      let name = dir. '/'. fnameescape(filename). g:autosave_extension
      if getbufvar(a:nr, '&ff') is# unix
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
      "let g:autosave_changenr[bufnr('%')] = changenr()
      break
    catch
    endtry
  endfor
  if !saved
    call add(g:autosave_errors, filename)
  endif
endfunc
func! <sid>SetupTimer(enable) "{{{2
  if a:enable
    let s:autosave_timer=timer_start(g:autosave_timer, 'Autosave_DoSave', {'repeat': -1})
  elseif exists('s:autosave_timer')
    call timer_stop(s:autosave_timer)
  endif
endfunc
func! <sid>Warning(list) "{{{2
  if empty(a:list)
    return
  endif
  let msg = "autosave: The following files could not be written."
	echohl WarningMsg
	unsilent echomsg msg
	for file in a:list | unsilent echomsg file | endfor
	sleep 1
	echohl Normal
	let v:errmsg = msg
endfun

let g:autosave = get(g:, 'autosave', 1)
call <sid>SetupTimer(g:autosave)
" Restore: "{{{1
let &cpo=s:cpo
unlet s:cpo
" vim: ts=2 sts=2 sw=2 et fdm=marker com+=l\:\"
