"=============================================================================
" File:         plugin/compil-hints.vim    {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://github.com/LucHermitte/vim-compil-hints>
" Version:      1.1.0
let s:k_version = 110
" Created:      10th Apr 2012
" Last Update:  25th Jun 2018
" License:      GPLv3
"------------------------------------------------------------------------
" Description:
"       Add ballons and signs to show where compilation errors have occured.
"
" Commands:
"       :CompilHintsToggle -- to start/stop using the plugin
"       :CompilHintsUpdate -- to update the signs to display
" Options:
"       g:compil_hints.use_balloons                   - boolean: [1]/0
"             Activates the display of balloons
"       g:compil_hints.use_signs                      - boolean: [1]/0
"             Activates the display of signs
"       g:compil_hints.autostart                      - boolean: 1/[0]
"             When sets, the plugin is automatically started.
"       (bpg):compil_hints.harsh_signs_removal_enabled  boolean: [1]/0
"             Improves greatly the removal of signs. However, this options does
"             remove all signs in a buffer, even the one not placed by
"             compil_hints.
"
" States:
"       enabled/disabled <=> running
"
"------------------------------------------------------------------------
" Installation:
"       Requires Vim7+ and +bexpr
"       Best installed with VAM/vim-pi
" History:
"       This plugin is strongly inspired by syntastic, but it restricts its work
"       to the result of the compilation.
"       NB: it doesn't copy qflist() but always fetch the last version in
"       order to automagically rely on vim to update the line numbers.
" TODO:
"       Handle local options for balloon use
"       When the quickfix list changes (background compilation with BTW), the
"       balloons stop displaying anything.
" }}}1
"=============================================================================

" Avoid global reinclusion {{{1
if &cp || (exists("g:loaded_compil_hints")
      \ && (g:loaded_compil_hints >= s:k_version)
      \ && !exists('g:force_reload_compil_hints'))
  finish
endif
if  !has('balloon_eval') && !has('signs')
  " Necessary requirements aren't fulfilled
  finish
endif
let g:loaded_compil_hints = s:k_version
let s:cpo_save=&cpo
set cpo&vim
" Avoid global reinclusion }}}1
"------------------------------------------------------------------------
" Commands and Mappings {{{1
command! CompilHintsUpdate call lh#compil_hints#update()
command! CompilHintsToggle Toggle ProjectShowcompilationhints
" Commands and Mappings }}}1
"------------------------------------------------------------------------
let g:compil_hints = get(g:, 'compil_hints', {})
"------------------------------------------------------------------------
" Auto-start {{{1

" Centralize the access to the option
function! s:shall_autostart()
  " v1.1.0. Let's suppose that if the plugin is installed, we want it to
  " automatically "highlight" errors.
  return get(g:compil_hints, 'autostart', 1)
endfunction

" Auto-commands
function! s:define_autocommands() abort
  let qf_cmds = ['make', 'grep', 'vimgrep', 'cscope', 'cfile', 'cgetfile', 'helpgrep', 'cexpr', 'cgetexpr', 'cbuffer', 'cgetbuffer']
  let qf_add_cmds = ['grepadd', 'vimgreadd', 'caddfile', 'caddexpr', 'caddbuffer']
  augroup CompilHints
    au!
    for cmd in qf_cmds + qf_add_cmds
      exe "au QuickFixCmdPost ".cmd." call lh#compil_hints#update('".cmd."')"
    endfor
    if get(g:compil_hints, 'reset_on_qf_window_commands', 1)
      " Intercepts :copen, but not cnewer, colder => don't use it
      " au BufWinEnter * if getbufvar(eval(expand('<abuf>')), '&ft') =~ 'qf' | Toggle ProjectShowcompilationhints yes | else | echomsg "BufWinEnter" | endif
      " Intercepts :copen, :cnewer, :colder...
      " Make sure it's reset => no + yes
      au FileType qf Toggle ProjectShowcompilationhints no | Toggle ProjectShowcompilationhints yes
      " Intercepts :cclose
      au BufWinLeave * if getbufvar(eval(expand('<abuf>')), '&ft') =~ 'qf' | Toggle ProjectShowcompilationhints no  | endif
    endif
  augroup END
endfunction

" Always define the commands
call s:define_autocommands()

" Auto-start }}}1
"------------------------------------------------------------------------
" Menus  -- "running" state {{{1
" s:getSNR([func_name]) {{{3
function! s:getSNR(...)
  if !exists("s:SNR")
    let s:SNR=matchstr(expand('<sfile>'), '<SNR>\d\+_\zegetSNR$')
  endif
  return s:SNR . (a:0>0 ? (a:1) : '')
endfunction
function! s:stop() abort
  " Defining the menu, even with autostart==0 will always call the action
  " associated to compil_hints.running variable. Which means, this'll trigger
  " the call to lh#compil_hints#stop().
  " Hence this trick. It permits to not load the autoload plugin when the menu
  " is defined.
  "
  " Yet, if g:compil_hints.running is true, the correct stop() function needs
  " to be called when stopping (for the first time).
  " echomsg "next time, let's use the correct lh#compil_hints#stop()"
  let s:compil_hints_menu.actions[0] = function("lh#compil_hints#stop")
endfunction

let g:compil_hints.running = get(g:compil_hints, 'running', s:shall_autostart())

" The following, will automatically start on the first run
let s:compil_hints_menu= {
      \ 'variable': 'compil_hints.running',
      \ 'values': [0, 1],
      \ 'texts': ['no', 'yes'],
      \ 'menu': {'priority': '50.110', 'name': 'Project.&Show compilation hints'},
      \ 'actions': [g:compil_hints.running ? function('lh#compil_hints#stop') : function(s:getSNR('stop')),
      \             function("lh#compil_hints#start")],
      \ }
call lh#menu#def_toggle_item(s:compil_hints_menu)

" For debugging purposes...
let g:compil_hints.__menu = s:compil_hints_menu

" Menus }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
