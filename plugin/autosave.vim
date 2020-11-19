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
" by default write every 5 minutes
let g:autosave_timer      = get(g:, 'autosave_timer', 60*5*1000)
let g:autosave_changenr   = {}
" by default try to save in the first directory from your &rtp,
" e.g. linux:   ~/.vim/backup
"      windows: c:\users\vim\backup on windows
let g:autosave_backup     = get(g:, 'autosave_backup', split(&rtp, ',')[0]. '/backup')
" if set, only allow to autosave particular buffers, that have been enabled
" using: AutoSaveThisBuffer
let g:autosave_include    = 0
" timestamp each backup file
let g:autosave_timestamp  = 1
" keep that many number of copies (per file)
let g:autosave_max_copies = 20

" public interface {{{1
com! -nargs=? AutoSave call <sid>SetupTimer(<q-args>)
com! DisableAutoSave AutoSave 0
com! EnableAutoSave  AutoSave g:autosave_timer
com! -bang AutoSaveThisBuffer call <sid>Autosave_this(<bang>0)

" functions {{{1
func! Autosave_this(bang) "{{{2
  if !a:bang
    let g:autosave_include=1
    let b:autosave_include=1
  else
    " Disable Autosaving this buffer
    unlet! b:autosave_include
  endif
endfunc

func! Autosave_DoSave(timer) abort "{{{2
  let skip_condition = ''
  if exists("*state")
    let skip_condition = "state('moaxw')"
  endif

  if empty(skip_condition) || empty(eval(skip_condition))
    let bufnr=bufnr('')
    let g:autosave_backupdir=split(&bdir, '\\\@<!,')
    let g:autosave_errors=[]
    " replace escaped commas with commas
    call map(g:autosave_backupdir, 'substitute(v:val, ''\\,'', ",", "g")')
    if exists("g:autosave_backup")
      call extend(g:autosave_backupdir, [g:autosave_backup], 0)
    endif
    call map(g:autosave_backupdir, 'expand(v:val)')

    " test if only autosave included buffers should be saved
    let include=[]
    for nr in range(1, bufnr('$'))
      if getbufvar(nr, 'autosave_include', 0)
        call add(include, nr)
      endif
    endfor
    " only save specific buffers
    if empty(include)
      for nr in range(1, bufnr('$'))
        call <sid>SaveBuffer(nr)
      endfor
      let g:autosave_include=0
    else
      " only save specific buffers
      for nr in include
        call <sid>SaveBuffer(nr)
      endfor
    endif
    call <sid>Warning(g:autosave_errors)
  endif
endfunc

func! <sid>GetNames(dir, bufname) "{{{2
  " Returns the final buffername and the directory where to save it
  let filename = fnamemodify(a:bufname, ':t')
  let timestamp = strftime('%Y%m%d_%H%M')

  if empty(filename)
    let filename='unnamed_buffer_'.timestamp.'.txt'
  endif
  " Add timestamp to the filename
  if get(g:, 'autosave_timestamp', 1) || a:dir is# '.'
    " file extensions could be 1, 2, 3, or 4 characters (*.h, *.cc, *.cpp, *.html)
    if filename =~ '\.\w\{1,4}$'
      let filename = substitute(filename, '\.\(\w\{1,4}\)$', '\="_".timestamp.".". submatch(1)', '')
    else
      let filename = filename . '_'.timestamp
    endif
    return filename
  endif

  let prefix = fnamemodify(a:bufname, ':p:h')
  if has("win32") || has("win64")
    let prefix = substitute(prefix, ':', '', 'g')
    let prefix = substitute(prefix, '\\', '=+', 'g')
  endif
  let prefix = substitute(prefix, '/', '=+', 'g'). '=+'

  if a:dir isnot# '.'
    let filename = prefix.filename
  endif

  return filename
endfunc
func! <sid>SaveBuffer(nr) abort "{{{2
  if !bufexists(a:nr)
    return
  endif
  " don't try to save special buffers (help)
  " unmodified files or buffers without a name
  " or buffers, for which the buffer-local variable
  " 'autosave_disabled' has been set
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
  let bufname = bufname(a:nr + 0)
  for dir in g:autosave_backupdir
    let filename = s:GetNames(dir, bufname)
    if !isdirectory(dir)
      call mkdir(dir, 'p')
    endif
    try
      let cnt = getbufline(a:nr, 1, '$')
      let name = dir. '/'. fnameescape(filename)
      let existing = sort(readdir(dir, {n -> n =~ bufname}), 'N')
      let num_copies = len(existing)
      let max_copies = get(g:, 'autosave_max_copies')
      if num_copies > max_copies
        " remove the oldest copies
        for v in range(num_copies - max_copies)
          let item = remove(existing, 0)
          call delete(dir. '/'. item)
          if get(g:, 'autosave_debug', 0)
            echomsg printf("removed oldest item '%s' in dir '%s'", item, dir)
          endif
        endfor
      endif
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
      call add(g:autosave_errors, v:exception)
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
  call <sid>MessOut(list)
	sleep 1
	let v:errmsg = list[0]
endfun

call <sid>SetupTimer(g:autosave_timer)
" Restore: "{{{1
let &cpo=s:cpo
unlet s:cpo
" vim: ts=2 sts=2 sw=2 et fdm=marker com+=l\:\"
