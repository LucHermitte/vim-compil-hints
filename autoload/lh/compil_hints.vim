"=============================================================================
" $Id$
" File:         addons/lh-compil-hints/autoload/lh/compil_hints.vim {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://code.google.com/p/lh-vim/>
" Version:      0.2.0
let s:k_version = 020
" Created:      10th Apr 2012
" Last Update:  $Date$
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
let s:verbose = 0
function! lh#compil_hints#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Verbose(expr)
  if s:verbose
    echomsg a:expr
  endif
endfunction

function! lh#compil_hints#debug(expr)
  return eval(a:expr)
endfunction

" # Options {{{2
function! s:UseBalloons()
  return lh#option#get('compil_hints_use_balloons',  has('balloon_eval'), 'g')
endfunction

function! s:UseSigns()
  return lh#option#get('compil_hints_use_signs',  has('signs'), 'g')
endfunction

"------------------------------------------------------------------------
" ## Exported functions {{{1

" Function: lh#compil_hints#start() {{{2
function! lh#compil_hints#start()
  let g:compil_hints_running = 1
  if s:UseBalloons()
    call s:Bstart()
  endif
  if s:UseSigns()
    call s:Sstart()
  endif
endfunction

" Function: lh#compil_hints#stop() {{{2
function! lh#compil_hints#stop()
  let g:compil_hints_running = 0
  call s:Bstop()
  call s:Sstop()
endfunction

" Function: lh#compil_hints#update() {{{2
function! lh#compil_hints#update()
  if ! g:compil_hints_running |  return | endif
  if s:UseSigns()
    call s:Supdate()
  endif
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" Function: s:Init() {{{2
function! s:Init()
  " Signs
  if !exists('s:signs')
    let s:signs=[]
  endif
  if !exists('s:signs_buffers')
    let s:signs_buffers={}
  endif
  " Highlighting
  sign define CompilHintsError   text=>> texthl=error
  sign define CompilHintsWarning text=>> texthl=todo
  sign define CompilHintsNote    text=>> texthl=comment
  sign define CompilHintsContext text=>> texthl=constant
endfunction

" # Signs {{{2
" Function: Sstart() {{{3
function! s:Sstart()
  call lh#compil_hints#update()
endfunction

" Function: Sstop() {{{3
function! s:Sstop()
  call s:Sclear()
endfunction

" Function: Sclear() {{{3
function! s:Sclear()
  if lh#option#get('compil_hint_harsh_signs_removal_enabled', 1, 'bg')
    for b in keys(s:signs_buffers)
      if buflisted(b)
        exe 'sign unplace * buffer='.b
      endif
    endfor
  else
    for s in s:signs
      silent! exe 'sign unplace '.(s) 
    endfor
  endif
  let s:signs=[]
  let s:signs_buffers={}
endfunction

" Function: s:ReduceQFList() {{{3
" Merges QF list inputs to have one entry per file+line_number
function! s:ReduceQFList(qflist)
  let errors  = {}
  for qf in a:qflist
    " note: "instantiated from" may be specific to C&C++ compilers like GCC. An
    " option may be required to extend the CompilHintsContext highlighting to
    " other filetypes/compilers.
    let type = 'CompilHints' . (
          \   (qf.type ==? 'w' || qf.text =~? '^\swarning:')             ? 'Warning' 
          \ : (qf.text =~? '^\s*note:')                                  ? 'Note'
          \ : (qf.text =~? '^\s*instantiated from\|within this context') ? 'Context'
          \ :                                                              'Error')
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
function! s:WorstType(errors)
  let worst = 'CompilHintsNote'
  for type in values(a:errors)
    if         (type == 'CompilHintsError')
          \ || (type == 'CompilHintsWarning' && worst != 'CompilHintsError') 
          \ || (type == 'CompilHintsContext' && worst == 'CompilHintsNote') 
      let worst = type
    endif
  endfor
  return worst
endfunction

" Function: Supdate() {{{3
let s:first_sign_id = 27000
function! s:Supdate()
  if !g:compil_hints_running | return | endif

  call s:Sclear()

  let qflist = getqflist()
  let qflist = filter(qflist, 'v:val.bufnr>0')
  let errors = s:ReduceQFList(qflist)

  let s:signs_buffers = {}

  let nb = s:first_sign_id
  for [bufnr, file_with_errors] in items(errors)
    for [lnum, what] in items(file_with_errors)
      let type = s:WorstType(what)
      let cmd = 'sign place '.nb
            \ .' line='.lnum
            \ .' name='.type
            \ .' buffer='.bufnr
      exe cmd
      let nb += 1
      call extend(s:signs_buffers, { bufnr : 1}) 
    endfor
  endfor
  let s:signs=range(s:first_sign_id, nb-1)
endfunction

" # Ballons {{{2
" Function: s:Bstart() {{{3
function! s:Bstart()
  set beval bexpr=lh#compil_hints#ballon_expr()
endfunction

" Function: s:Bstop() {{{3
function! s:Bstop()
  if &bexpr=='lh#compil_hints#ballon_expr()'
    " reset to default
    set beval& bexpr&
  endif
endfunction

" Function: lh#compil_hints#ballon_expr() {{{3
function! lh#compil_hints#ballon_expr()
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
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
