"=============================================================================
" File:         addons/lh-compil-hints/autoload/lh/compil_hints.vim {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} gmail {dot} com>
"               <URL:http://github.com/LucHermitte/vim-compil-hints>
" Version:      1.1.0
let s:k_version = 110
" Created:      10th Apr 2012
" Last Update:  28th Jun 2018
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
" - check if this is enough for plugins that do asynchronous compilation
" - support loclist?
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version {{{2
function! lh#compil_hints#version()
  return s:k_version
endfunction

" # Debug   {{{2
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

" # Options {{{2
function! s:UseBalloons()
  return has('balloon_eval') && get(g:compil_hints, 'use_balloons', 1)
endfunction

function! s:UseSigns()
  return has('signs')        && get(g:compil_hints, 'use_signs', 1)
endfunction

function! s:opt(key, default) abort
  return lh#option#get('compil_hints.'.a:key, a:default, 'g')
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
      call call('s:Supdate', a:000)
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
  call s:Supdate('start')
endfunction

" Function: Sstop() {{{3
function! s:Sstop() abort
  call s:Sclear()
endfunction

" Function: Sclear() {{{3
function! s:Sclear() abort
  if lh#option#get('compil_hints.harsh_signs_removal_enabled', !exists('*execute'))
    for b in keys(s:signs_buffers)
      if buflisted(b+0) " need to convert the key (stored as a string) to a number
        exe 'sign unplace * buffer='.b
      endif
    endfor
  elseif exists('*execute')
    " Should be fast enough => TODO: bench!!!
    call execute(map(s:signs, '"sign unplace ".v:val'))
  else
    " This is really slow...
    for s in s:signs
      silent! exe 'sign unplace '.(s)
    endfor
  endif
  let s:signs         = []
  let s:signs_buffers = {}
  let s:first_sign_id = s:k_first_sign_id
endfunction

" Function: s:ReduceQFList() {{{3
" Merges QF list inputs to have one entry per file+line_number
function! s:ReduceQFList(qflist) abort
  " note: "instantiated from" may be specific to C&C++ compilers like GCC. An
  " option may be required to extend the CompilHintsContext highlighting to
  " other filetypes/compilers.
  let context_re = lh#option#get('compil_hints.context_re', '^\s*instantiated from\|within this context\|required from here')
  let errors  = {}
  for qf in a:qflist
    let type =
          \   (qf.type ==? 'w' || qf.text =~? '^\swarning:')             ? 'Warning'
          \ : (qf.text =~? '^\s*note:')                                  ? 'Note'
          \ : (qf.text =~? context_re)                                   ? 'Context'
          \ : (qf.type ==? 'e' || qf.text =~? '^\serror:')               ? 'Error'
          \ :                                                              'Here'
    if !has_key(errors, qf.bufnr)
      let errors[qf.bufnr] = {}
    endif
    let lnum = get(qf,'lnum',-1)
    if !has_key(errors[qf.bufnr], lnum)
      let errors[qf.bufnr][lnum] = {}
    endif

    " TODO: too much info is cached
    call extend(errors[qf.bufnr][lnum], {get(qf, 'text') : type} )
  endfor
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
let s:inc_signs = {}
function! s:Supdate(...) abort
  call lh#assert#true(g:compil_hints.activated)
  " if !g:compil_hints.displayed | return | endif

  let qflist = getqflist()

  let cmd = get(a:, 1, '')
  if cmd =~ 'add'
    if len(qflist) < s:qf_length
      let s:qf_length = len(qflist)
      " new compilation, let's clear every thing
      call s:Verbose("Clearing signs")
      let s:inc_signs = {}
      call s:Sclear()
    else
      let new_qf_length = len(qflist)
      " We only parse what's new!
      let qflist = qflist[s:qf_length : ]
      call s:Verbose("Keep %1 elements: %2 - %3", len(qflist), new_qf_length, s:qf_length)
      let s:qf_length = new_qf_length
    endif
  else
    let s:qf_length = len(qflist)
    call s:Sclear()
  endif

  let qflist = filter(qflist, 'v:val.bufnr>0')
  let errors = s:ReduceQFList(qflist)

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
          let sign_info = lh#dict#need_ref_on(s:inc_signs, [bufnr, lnum], {} )
          if has_key(sign_info, 'id')
            call extend(sign_info.what, what)
            let cmds += ['silent! sign unplace '.(sign_info.id)]
          else
            call extend(sign_info, {'id': s:first_sign_id, 'what': what})
            let s:first_sign_id += 1
          endif
          let cmds += ['silent! sign place '.(sign_info.id)
                \ .' line='.lnum
                \ .' name=CompilHints'.s:WorstType(sign_info.what)
                \ .' buffer='.bufnr]
        endfor

        call extend(s:signs_buffers, { bufnr : 1})
      endif
    endfor
  else
    for [bufnr, file_with_errors] in items(errors)
      if !empty(file_with_errors)
        " => Use map() in that case!
        for [lnum, what] in items(file_with_errors)
          let cmds += ['silent! sign place '.s:first_sign_id
                \ .' line='.lnum
                \ .' name=CompilHints'.s:WorstType(what)
                \ .' buffer='.bufnr]
          let s:first_sign_id += 1
        endfor
        call extend(s:signs_buffers, { bufnr : 1})
      endif
    endfor
  endif
  exe join(cmds, "\n")
  let s:signs=range(s:k_first_sign_id, s:first_sign_id)
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
