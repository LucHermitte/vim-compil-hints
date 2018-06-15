"=============================================================================
" File:         addons/lh-compil-hints/plugin/compil-hints.vim    {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://github.com/LucHermitte/vim-compil-hints>
" Version:      1.0.0
let s:k_version = 100
" Created:      10th Apr 2012
" Last Update:  14th Jun 2018
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
if &cp || !has('balloon_eval') || (exists("g:loaded_compil_hints")
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
command! CompilHintsToggle Toggle ProjectShowcompilationhints
" Commands and Mappings }}}1
"------------------------------------------------------------------------
" Auto-start {{{1
let g:compil_hints = get(g:, 'compil_hints', {})

if get(g:compil_hints, 'autostart', 0)
  call lh#compil_hints#start()
endif
" Auto-start }}}1
"------------------------------------------------------------------------
" Menus {{{1
let g:compil_hints.running = get(g:compil_hints, 'running', 0)

let s:compil_hints_menu= {
      \ 'variable': 'compil_hints_running',
      \ 'idx_crt_value': lh#option#get('compil_hints.autostart', 0, 'g'),
      \ 'values': [0, 1],
      \ 'texts': ['no', 'yes'],
      \ 'menu': {'priority': '50.110', 'name': 'Project.&Show compilation hints'},
      \ 'actions': [function("lh#compil_hints#stop"), function("lh#compil_hints#start")]
      \ }
call lh#menu#def_toggle_item(s:compil_hints_menu)

" Menus }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
