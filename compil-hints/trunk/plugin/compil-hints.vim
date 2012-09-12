"=============================================================================
" $Id$
" File:         addons/lh-compil-hints/plugin/compil-hints.vim    {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://code.google.com/p/lh-vim/>
" Version:      002
let s:k_version = 2
" Created:      10th Apr 2012
" Last Update:  $Date$
" License:      GPLv3
"------------------------------------------------------------------------
" Description:
"       Add ballons and signs to show where compilation errors have occured.
"
" Commands:
"       :CompilHintsToggle -- to start/stop using the plugin
"       :CompilHintsUpdate -- to update the signs to display
" Options:
"       g:compil_hints_use_balloons - boolean: [1]/0
"       g:compil_hints_use_signs    - boolean: [1]/0
"       g:compil_hints_autostart   - boolean: 1/[0]
" 
"------------------------------------------------------------------------
" Installation:
"       Requires Vim7+
"       Best installed with VAM
" History:      
"       This plugin is strongly inspired by syntastic, but it restricts its work
"       to the result of the compilation.
"       NB: it doesn't copy qflist() but always fetch the last version in
"       order to automagically rely on vim to update the line numbers.
" TODO:         
"       Handle local options for ballon use
" }}}1
"=============================================================================

" Avoid global reinclusion {{{1
if &cp || (exists("g:loaded_compil_hints")
      \ && (g:loaded_compil_hints >= s:k_version)
      \ && !exists('g:force_reload_compil_hints'))
  finish
endif
let g:loaded_compil_hints = s:k_version
let s:cpo_save=&cpo
set cpo&vim
" Avoid global reinclusion }}}1
"------------------------------------------------------------------------
" Commands and Mappings {{{1
command! CompilHintsUpdate call lh#compil_hints#update()
command! CompilHintsToggle call lh#compil_hints#toggle()
" Commands and Mappings }}}1
"------------------------------------------------------------------------
" Auto-start {{{1
if lh#option#get('compil_hints_autostart', 0, 'g')
  call lh#compil_hints#start()
endif
" Auto-start }}}1
"------------------------------------------------------------------------
" Menus {{{1
let g:compil_hints_menu= {
      \ 'variable': 'lh#compil_hint#running',
      \ 'idx_crt_value': lh#option#get('compil_hints_autostart', 0, 'g'),
      \ 'values': [0, 1],
      \ 'texts': ['no', 'yes'],
      \ 'menu': {'priority': '50.110', 'name': 'Project.&Show compilation hints'},
      \ }
function! g:compil_hints_menu.hook() dict
  call lh#compil_hints#toggle()
endfunction
call lh#menu#def_toggle_item(g:compil_hints_menu)

" Menus }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
