"=============================================================================
" $Id$
" File:         addons/lh-compil-hints/autoload/lh/compil_hints.vim {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://code.google.com/p/lh-vim/>
" Version:      002
let s:k_version = 2
" Created:      10th Apr 2012
" Last Update:  $Date$
" License:      GPLv3
"------------------------------------------------------------------------
" Description/Installation/...:
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


"------------------------------------------------------------------------
" ## Exported functions {{{1

" Function: lh#compil_hints#start() {{{3
function! lh#compil_hints#start()
  let s:running = 1
  if lh#option#get('compil_hints_use_balloons', 1, 'g')
    call s:Bstart()
  endif
  if lh#option#get('compil_hints_use_signs', 1, 'g')
    call s:Sstart()
  endif
endfunction

" Function: lh#compil_hints#stop() {{{3
function! lh#compil_hints#stop()
  let s:running = 0
  call s:Bstop()
  call s:Sstop()
endfunction

" Function: lh#compil_hints#update() {{{3
function! lh#compil_hints#update()
  if lh#option#get('compil_hints_use_signs', 1, 'g')
    call s:Supdate()
  endif
endfunction

" Function: lh#compil_hints#toggle() {{{3
function! lh#compil_hints#toggle()
  if s:running | call lh#compil_hints#stop()
  else         | call lh#compil_hints#start()
  endif
  let lh#compil_hint#running = s:running
endfunction

" Signs {{{3
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
  for s in s:signs
    exe 'sign unplace '.(s) 
  endfor
  let s:signs=[]
endfunction

" Function: Supdate() {{{3
let s:first_sign_id = 27000
function! s:Supdate()
  call s:Sclear()
  if !s:running | return | endif

  let qflist = getqflist()
  let qflist = filter(qflist, 'v:val.bufnr>0')
  let nb = s:first_sign_id
  for qf in qflist
    let type = 'CompilHints' . (
          \ (qf.type ==? 'w') ? 'Warning' 
          \ : (qf.text =~? '^\s*note:') ? 'Note'
          \ : 'Error')
    let cmd = 'sign place '.nb
          \ .' line='.get(qf,'lnum',-1)
          \ .' name='.type
          \ .' buffer='.(qf.bufnr)
    exe cmd
    let nb += 1
  endfor
  let s:signs=range(s:first_sign_id, nb-1)
endfunction

" Ballons {{{3
" Function: s:Bstart() {{{4
function! s:Bstart()
  set beval bexpr=lh#compil_hints#ballon_expr()
endfunction

" Function: s:Bstop() {{{4
function! s:Bstop()
  if &bexpr=='lh#compil_hints#ballon_expr()'
    " reset to default
    set beval& bexpr&
  endif
endfunction

" Function: lh#compil_hints#ballon_expr() {{{4
function! lh#compil_hints#ballon_expr()
  " do we need to cache the info obtained ?
  let qflist = getqflist()
  " let crt_buf = bufnr('%')
  let crt_qflist = filter(qflist, 'v:val.bufnr == '.v:beval_bufnr)
  let crt_qf = filter(crt_qflist, 'v:val.lnum == '.v:beval_lnum)
  let crt_text = !empty(crt_qf) ? get(crt_qf[0], 'text', '') : ''
  return crt_text
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" Function: s:Init() {{{2
function! s:Init()
  " State: s:running                  {{{3
  if !exists('s:running')
    let s:running = 0
  endif

  " Signs {{{3
  if !exists('s:signs')
    let s:signs=[]
  endif
  sign define CompilHintsError text=>> texthl=error
  sign define CompilHintsWarning text=>> texthl=todo
  sign define CompilHintsNote text=>> texthl=comment
endfunction

call s:Init()
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
