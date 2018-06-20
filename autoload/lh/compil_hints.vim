"=============================================================================
" File:         addons/lh-compil-hints/autoload/lh/compil_hints.vim {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} gmail {dot} com>
"               <URL:http://github.com/LucHermitte/vim-compil-hints>
" Version:      1.0.1
let s:k_version = 101
" Created:      10th Apr 2012
" Last Update:  20th Jun 2018
" License:      GPLv3
"------------------------------------------------------------------------
" Description/Installation/...:
"
" After a program has been compiled, execute lh#compil_hints#update() to update
" the signs and the balloons that highlight the compilation errors and warnings.
"
" - track the changes and update only the related signs
"
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

"------------------------------------------------------------------------
" ## Exported functions {{{1

" Function: lh#compil_hints#start() {{{2
function! lh#compil_hints#start() abort
  let g:compil_hints.running = 1
  if s:UseBalloons()
    call s:Bstart()
  endif
  if s:UseSigns()
    call s:Sstart()
  endif
endfunction

" Function: lh#compil_hints#stop() {{{2
function! lh#compil_hints#stop() abort
  let g:compil_hints.running = 0
  if has('balloon_eval')
    call s:Bstop()
  endif
  if has('signs')
    call s:Sstop()
  endif
endfunction

" Function: lh#compil_hints#update([cmd]) {{{2
function! lh#compil_hints#update(cmd) abort
  if ! g:compil_hints.running |  return | endif
  if s:UseSigns()
    call call('s:Supdate', a:000)
  endif
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" Function: s:Init() {{{2
let s:pixmaps_dir = expand('<sfile>:p:h:h:h').'/pixmaps/'

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
    let s_error   = lh#option#get('compil_hints.signs.error',   ["\u274c", 'XX']           , 'g')
    let s_warning = lh#option#get('compil_hints.signs.warning', ["\u26a0", "\u26DB", '!!'] , 'g')
    let s_note    = lh#option#get('compil_hints.signs.note',    ["\u2139", "\U1F6C8", 'ii'], 'g')
    let s_context = lh#option#get('compil_hints.signs.context', ['>>']                     , 'g')
    let s_info    = lh#option#get('compil_hints.signs.info',    ["\u27a9", '->']           , 'g')

    let [error, warning, note, ctx, here] = lh#encoding#find_best_glyph(
          \ 'compil-hints',
          \ s_error, s_warning, s_note, s_context, s_info
          \ )
  endif

  " - do define the signs
  let signs = []
  let signs += [{'kind': 'Error',   'text': error,   'hl': 'error'   }]
  let signs += [{'kind': 'Warning', 'text': warning, 'hl': 'todo'    }]
  let signs += [{'kind': 'Note',    'text': note ,   'hl': 'comment' }]
  let signs += [{'kind': 'Context', 'text': ctx  ,   'hl': 'constant'}]
  let signs += [{'kind': 'Here',    'text': here ,   'hl': 'todo'    }]
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
  call lh#compil_hints#update()
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
  let s:signs        = []
  let s:signs_buffers= {}
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
let s:first_sign_id = 27000
let s:qf_length     = -1
function! s:Supdate(...) abort
  if !g:compil_hints.running | return | endif

  let qflist = getqflist()

  let cmd = get(a:, 1, '')
  if cmd =~ 'add'
    if len(qflist) < qf_length
      " new compilation, let's clear every thing
      call s:Sclear()
    else
      " We only parse what's new!
      let qflist = qflist[qf_length+1 : ]
    endif
    let qf_length = len(qflist)
  else
    call s:Sclear()
  endif

  let qflist = filter(qflist, 'v:val.bufnr>0')
  let errors = s:ReduceQFList(qflist)

  let s:signs_buffers = {}

  " let g:whats = []
  let nb = s:first_sign_id
  for [bufnr, file_with_errors] in items(errors)
    if !empty(file_with_errors)
      for [lnum, what] in items(file_with_errors)
        " let g:whats += [what]
        let type = s:WorstType(what)
        let cmd = 'silent! sign place '.nb
              \ .' line='.lnum
              \ .' name=CompilHints'.type
              \ .' buffer='.bufnr
        exe cmd
        let nb += 1
      endfor
      call extend(s:signs_buffers, { bufnr : 1})
    endif
  endfor
  let s:signs=range(s:first_sign_id, nb-1)
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
  " Every time a file is updated, the dictionary returned by getqflist() is
  " updated regarding line numbers. As such, We cannot cache anything.
  " At best, we merge different lines.
  "
  " do we need to cache the info obtained ?
  let qflist = getqflist()
  let crt_qf = filter(qflist, 'v:val.bufnr == '.v:beval_bufnr.' && v:val.lnum == '.v:beval_lnum)
  let crt_text = join(lh#list#unique_sort2(map(copy(crt_qf), 'v:val.text')), "\n")
  return crt_text
endfunction


call s:Init()
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
