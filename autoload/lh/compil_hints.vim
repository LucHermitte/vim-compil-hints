"=============================================================================
" File:         addons/lh-compil-hints/autoload/lh/compil_hints.vim {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} gmail {dot} com>
"               <URL:http://github.com/LucHermitte/vim-compil-hints>
" Version:      1.1.1
let s:k_version = 111
" Created:      10th Apr 2012
" Last Update:  02nd Jul 2018
" License:      GPLv3
"------------------------------------------------------------------------
" Description/Installation/...:
"
" The plugin shall work out the box.
" - commands that update the qflist will trigger an (incremental) update
"   of the signs -- and activate balloons
" - :copen, :cnewer, :colder... will trigger a complete update of the
"   signs to display
" - :cclose will hide all the signs and disable balloons
" - balloons always use the current qflist
"
" - track the changes and update only the related signs
"
"
" TODO:
" - support loclist?
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version       {{{2
function! lh#compil_hints#version()
  return s:k_version
endfunction

" # Debug         {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#compil_hints#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Log(expr, ...) abort
  call call('lh#log#this',[a:expr]+a:000)
endfunction

function! s:Verbose(expr, ...) abort
  if s:verbose
    call call('s:Log',[a:expr]+a:000)
  endif
endfunction

function! lh#compil_hints#debug(expr) abort
  return eval(a:expr)
endfunction

" # Options       {{{2
function! s:UseBalloons()
  return has('balloon_eval') && get(g:compil_hints, 'use_balloons', 1)
endfunction

function! s:UseSigns()
  return has('signs')        && get(g:compil_hints, 'use_signs', 1)
endfunction

function! s:opt(key, default) abort
  return lh#option#get('compil_hints.'.a:key, a:default, 'g')
endfunction

" # Miscelleanous {{{2
" Function: s:execute(list) {{{3
if exists('*execute')
  let s:execute = function('execute')
else
  function! s:execute(list) abort
    for c in a:list
      exe c
    endfor
  endfunction
endif

" Function: s:function(fname) {{{3
function! s:function(fname) abort
  if !exists("s:SNR")
    let s:SNR=matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$')
  endif
  return function(s:SNR.a:fname)
endfunction

"------------------------------------------------------------------------
" ## Exported functions {{{1

" Function: lh#compil_hints#start() {{{2
function! lh#compil_hints#start() abort
  call lh#assert#true(g:compil_hints.activated)
  call s:Verbose("start")
  let g:compil_hints.displayed = 1
  if s:UseBalloons()
    call s:Bstart()
  endif
  if s:UseSigns()
    call s:Sstart()
  endif
endfunction

" Function: lh#compil_hints#stop() {{{2
function! lh#compil_hints#stop() abort
  call s:Verbose("stop")
  let g:compil_hints.displayed = 0
  if has('balloon_eval')
    call s:Bstop()
  endif
  if has('signs')
    call s:Sstop()
  endif
endfunction

" Function: lh#compil_hints#update([cmd]) {{{2
function! lh#compil_hints#update(...) abort
  call lh#assert#true(g:compil_hints.activated)
  if get(a:, 1, '') =~ 'grep'
    " TODO: avoid to do it after each :grepadd
    call s:qf_context.set('balloon', lh#qf#get_title())
  endif
  if ! get(g:compil_hints, 'displayed', 0)
    call lh#compil_hints#start()
    return
  else
    call s:Verbose("update(%1)", a:000)
    if s:UseSigns()
      let s:stats += [lh#time#bench('call', s:function('Supdate'), a:000)]
    endif
  endif
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" Function: s:Init() {{{2
let s:pixmaps_dir = expand('<sfile>:p:h:h:h').'/pixmaps/'
let s:qf_context = lh#qf#make_context_map(0)

function! s:Init() abort
  " Initialize internal variables for Signs
  let s:signs         = get(s:, 'signs', [])
  let s:signs_buffers = get(s:, 'signs_buffers', {})
  let s:signs_undo    = get(s:, 'signs_undo', [])

  " Highlighting
  " - define sign texts, or icons
  if has('gui_running') && (has('xpm') || has('xpm_w32'))
    " In that case, we don't care!
    " => No need to try to detect which glyphs are supported
    let [error, warning, note, ctx, here] = repeat(['>>'], 5)

    " TODO: permit to tune the icons used
    " TODO: if we can use other icon types (png), we may not need UTF-8 glyphs
    let icons = {}
    let icons.Error   = s:pixmaps_dir.'error.xpm'
    let icons.Warning = s:pixmaps_dir.'alert.xpm'
    let icons.Note    = s:pixmaps_dir.'info.xpm'
    let icons.Context = s:pixmaps_dir.'quest.xpm'
    let icons.Here    = s:pixmaps_dir.'tb_jump.xpm'
  else
    " TODO: What if &enc isn't UTF-8 ?
    let s_error   = s:opt('signs.error',   ["\u274c", 'XX']           )
    let s_warning = s:opt('signs.warning', ["\u26a0", "\u26DB", '!!'] )
    let s_note    = s:opt('signs.note',    ["\u2139", "\U1F6C8", 'ii'])
    let s_context = s:opt('signs.context', ['>>']                     )
    let s_info    = s:opt('signs.info',    ["\u27a9", '->']           )

    let [error, warning, note, ctx, here] = lh#encoding#find_best_glyph(
          \ 'compil-hints',
          \ s_error, s_warning, s_note, s_context, s_info
          \ )
  endif

  " - do define the signs
  let signs = []
  let signs += [{'kind': 'Error',   'text': error,   'hl': s:opt('hl.error',   'error'   )}]
  let signs += [{'kind': 'Warning', 'text': warning, 'hl': s:opt('hl.warning', 'todo'    )}]
  let signs += [{'kind': 'Note',    'text': note ,   'hl': s:opt('hl.note',    'comment' )}]
  let signs += [{'kind': 'Context', 'text': ctx  ,   'hl': s:opt('hl.context', 'constant')}]
  let signs += [{'kind': 'Here',    'text': here ,   'hl': s:opt('hl.info',    'todo'    )}]
  for s in signs
    let cmd  = 'sign define CompilHints'.( s.kind ).' text='.( s.text ).' texthl='.( s.hl )
    if exists('l:icons')
      let cmd .= ' icon='.get(icons, s.kind, '__unexpected__')
    endif
    call s:Verbose(cmd)
    exe cmd
  endfor
endfunction

" # Signs {{{2
" Function: Sstart() {{{3
function! s:Sstart() abort
  " call s:Supdate('start')
  let s:stats += [lh#time#bench(s:function('Supdate'), 'start')]
endfunction

" Function: Sstop() {{{3
function! s:Sstop() abort
  call s:Sclear()
endfunction

" Function: Sclear() {{{3
function! s:Sclear() abort
  call s:Verbose("Remove %1 signs", len(s:signs_undo))
  if lh#option#get('compil_hints.harsh_signs_removal_enabled', !exists('*execute'))
    for b in keys(s:signs_buffers)
      if buflisted(b+0) " need to convert the key (stored as a string) to a number
        exe 'sign unplace * buffer='.b
      endif
    endfor
  else
    " `sign unplace {id}`  is 12500 times slower on 22900 signs than
    " `sign unplace {id} buffer={bid}`
    " It's likelly a consequence that the related files may not all be
    " loaded.
    " I don't know yet, whether unplacing that may signs from loaded
    " buffers will incur a similar performance slow down.
    " call s:execute(map(s:signs, '"sign unplace ".v:val'))
    call s:execute(s:signs_undo)
  endif
  let s:signs         = []
  let s:signs_undo    = []
  let s:signs_buffers = {}
  let s:first_sign_id = s:k_first_sign_id
endfunction

" Function: s:ReduceQFList() {{{3
" Merges QF list inputs to have one entry per file+line_number
function! s:qf_type(qf, context_re) abort
  let type =
        \   (a:qf.type ==? 'w' || a:qf.text =~? '^\swarning:') ? 'Warning'
        \ : (a:qf.text =~? '^\s*note:')                        ? 'Note'
        \ : (a:qf.text =~? a:context_re)                       ? 'Context'
        \ : (a:qf.type ==? 'e' || a:qf.text =~? '^\serror:')   ? 'Error'
        \ :                                                      'Here'
  return type
endfunction

function! s:ReduceQFList(qflist) abort
  " note: "instantiated from" may be specific to C&C++ compilers like GCC. An
  " option may be required to extend the CompilHintsContext highlighting to
  " other filetypes/compilers.
  let context_re = lh#option#get('compil_hints.context_re', '^\s*instantiated from\|within this context\|required from here')
  let errors  = {}

  call map(a:qflist, 'extend(lh#dict#need_ref_on(errors, [v:val.bufnr, get(v:val,"lnum",-1)], {}), {get(v:val, "text") : s:qf_type(v:val, context_re)})')

  "for qf in a:qflist
  "  let type = s:qf_type(qf, context_re)
  "  let lnum = get(qf,"lnum",-1)
  "  let entry = lh#dict#need_ref_on(errors, [qf.bufnr, lnum], {})

  "  " TODO: too much info is cached
  "  call extend(entry, {get(qf, "text") : type} )
  "endfor
  return errors
endfunction

" Function: s:WorstType(errors) {{{3
let s:k_levels = ['Error', 'Warning', 'Context', 'Note', 'Here']
function! s:WorstType(errors) abort
  let idx = min(map(values(a:errors), 'index(s:k_levels, v:val)'))
  call lh#assert#value(idx).is_ge(0)
  return s:k_levels[idx]
endfunction

" Function: Supdate([cmd]) {{{3
let s:k_first_sign_id = 27000  " Initial value
" todo: use int max
let s:qf_length       = 10000000000000
let s:aync_signs = {}
let s:stats  = []
function! s:Supdate(...) abort
  let s:stats += ['update('.string(a:000).')']
  call lh#assert#true(g:compil_hints.activated)

  let qflist = getqflist()

  let cmd = get(a:, 1, '')
  if cmd =~ 'add'
    if len(qflist) == 0
      let s:qf_length = len(qflist)
      " When compiling asynchronously, the length is usually 1. A new
      " compilation will also have a length of 1.
      " => We'd need to compare the quickdix-ID, except this is not available
      " before v 7.4.2200, and a correct async job starts at v7.4-1980...  new
      " compilation, let's clear every thing
      call s:Sclear()
      let s:aync_signs = {}
    else
      let new_qf_length = len(qflist)
      " We only parse what's new!
      let qflist = qflist[s:qf_length : ]
      " call s:Verbose("Keep %1 elements: %2 - %3", len(qflist), new_qf_length, s:qf_length)
      let s:qf_length = new_qf_length
    endif
  else
    " This may also match a situation where the qf list is reset to nothing
    " before an asynchronous filling => let's clear everything
    let s:qf_length = len(qflist)
    let s:stats += ['unplacing of '.len(s:signs).'signs done in '.string(lh#time#bench(s:function('Sclear')))]
    let s:aync_signs = {}
    call s:Verbose("Starts a new session for %1 elements", s:qf_length)
  endif

  let qflist = filter(qflist, 'v:val.bufnr>0')
  " let errors = s:ReduceQFList(qflist)
  let [errors, t] = lh#time#bench(s:function('ReduceQFList'), (qflist))
  let s:stats += ['s:Reduce: '.string(t)]

  let s:signs_buffers = {}

  " When triggered from `grepadd`, `cexpradd`..., we will likelly only
  " have one new sign.
  " In that case,
  " - "what" needs to accumulate data from several signs, it may also
  "   need to be updated (arg!!).
  " - "id" numbers shall not restart from scratch either.
  " Otherwise, we'll register a lot of signs simultaneously
  let cmds = []
  if cmd =~ 'add'
    for [bufnr, file_with_errors] in items(errors)
      if !empty(file_with_errors)
        for [lnum, what] in items(file_with_errors)
          " Test whether there is already a sign in the same place
          let sign_info = lh#dict#need_ref_on(s:aync_signs, [bufnr, lnum], {} )
          if has_key(sign_info, 'id')
            let old_lvl = s:WorstType(sign_info.what)
            call extend(what, sign_info.what)
            let new_lvl = s:WorstType(what)
            if new_lvl != old_lvl
              let sign_info.what = what
              let cmds += ['silent! sign unplace '.(sign_info.id)]
              let cmds += ['silent! sign place '.(sign_info.id)
                    \ .' line='.lnum
                    \ .' name=CompilHints'.new_lvl
                    \ .' buffer='.bufnr]
              " Else: if the level doesn't change => don't do anything
              " else | call s:Verbose("Doesn't change!")
            endif
          else
            call extend(sign_info, {'id': s:first_sign_id, 'what': what})
            let s:first_sign_id += 1
            let cmds += ['silent! sign place '.(sign_info.id)
                  \ .' line='.lnum
                  \ .' name=CompilHints'.s:WorstType(sign_info.what)
                  \ .' buffer='.bufnr]
          endif
          let s:signs_undo += ['silent! sign unplace '.(sign_info.id).' buffer='.bufnr]
          " call s:Verbose('cmds(%2:%3): %1 ; %4 inc signs', cmds, bufname(bufnr), lnum, len(s:aync_signs[bufnr]))
        endfor

        call extend(s:signs_buffers, { bufnr : 1})
      endif
    endfor
    let s:signs_undo = lh#list#unique_sort(s:signs_undo)
  else
    for [bufnr, file_with_errors] in items(errors)
      if !empty(file_with_errors)
        let new_cmds = []
        let new_cmds = map(items(file_with_errors),
              \ "'silent! sign place '.(s:first_sign_id+v:key).' line='.v:val[0].' name=CompilHints'.s:WorstType(v:val[1]).' buffer='.bufnr")
        let s:signs_undo += map(items(file_with_errors),
              \ '"silent! sign unplace ".(s:first_sign_id+v:key)." buffer=".bufnr')
        let s:first_sign_id += len(new_cmds)
        call extend(s:signs_buffers, { bufnr : 1})
        let cmds += new_cmds
      endif
    endfor
  endif
  " call s:execute(cmds)
  let [d,t] = lh#time#bench(s:execute, cmds)
  let s:signs=range(s:k_first_sign_id, s:first_sign_id)
  if cmd !~ 'add'
    let s:stats += [len(cmds). ' commands executed in '.string(t).' for '.len(s:signs).' signs placed']
  endif
endfunction

" # Ballons {{{2
" Function: s:Bstart() {{{3
function! s:Bstart() abort
  set beval bexpr=lh#compil_hints#ballon_expr()
endfunction

" Function: s:Bstop() {{{3
function! s:Bstop() abort
  if &bexpr=='lh#compil_hints#ballon_expr()'
    " reset to default
    set beval& bexpr&
  endif
endfunction

" Function: lh#compil_hints#ballon_expr() {{{3
function! lh#compil_hints#ballon_expr() abort
  " Question: what'll be the id after cnewer/colder?
  "     <<If "nr" is not present then the current quickfix list is used.>>
  " -> looks like it'll be OK!
  let ctx = s:qf_context.get('balloon')

  " Every time a file is updated, the dictionary returned by getqflist() is
  " updated regarding line numbers. As such, We cannot cache anything.
  " At best, we merge different lines.
  "
  " do we need to cache the info obtained ?
  let qflist = getqflist()
  let crt_qf = filter(qflist, 'v:val.bufnr == '.v:beval_bufnr.' && v:val.lnum == '.v:beval_lnum)
  if !empty(ctx) && !empty(crt_qf)
    return ctx
  endif
  let crt_text = join(lh#list#unique_sort2(map(copy(crt_qf), 'v:val.text')), "\n")
  return crt_text
endfunction


call s:Init()
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
