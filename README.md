compil-hints
============

Add _ballons_ and _signs_ to show where compilation errors have occured.
The information is extracted from the [quickfix list](http://vimhelp.appspot.com/eval.txt.html#getqflist%28%29).


[![Last release](https://img.shields.io/github/tag/LucHermitte/vim-compil-hints.svg)](https://github.com/LucHermitte/vim-compil-hints/releases) [![Project Stats](https://www.openhub.net/p/21020/widgets/project_thin_badge.gif)](https://www.openhub.net/p/21020)

## Features
 * Parses the quickfix list and present its entries as
   [_signs_](http://vimhelp.appspot.com/sign.txt.html#signs) and/or
   [_balloons_](http://vimhelp.appspot.com/debugger.txt.html#balloon%2deval) --
   when supported by Vim.
 * Multiple issues happening on a same line are merged together, the highest
   error level is kept (_error_ > _warning_ > _note_ > _context_)
 * Plugins that update the quickfix list are expected to explicitly refresh the
   signs by calling `lh#compil_hints#update()` --
   [BuildToolsWrapper](https://github.com/LucHermitte/vim-build-tools-wrapper/))
   already does that. Balloons are automatically updated.

## Commands

 * `:CompilHintsToggle` -- to start/stop using the plugin
 * `:CompilHintsUpdate` -- to update the signs to display

## Demo

TODO: Here is a little screencast to see how things are displayed with vim-compil-hints.

![vim-compil-hints demo](doc/screencast-vim-compil-hints.gif "vim-compil-hints demo")

## Options

The
[options](https://github.com/LucHermitte/lh-vim-lib/blob/master/doc/Options.md) are:

#### `g:compil_hints.use_balloons`
Activates the display of balloons -- boolean: [1]/0

Requires Vim to be compiled with
[`+balloon_eval`](http://vimhelp.appspot.com/various.txt.html#%2bballoon_eval)
support.

#### `g:compil_hints.use_signs`
Activates the display of signs -- boolean: [1]/0

Requires Vim to be compiled with
[`+signs`](http://vimhelp.appspot.com/various.txt.html#%2bsigns) support.

#### `g:compil_hints.autostart`
When sets, the plugin is automatically started -- boolean: 1/[0]

#### `(bpg):compil_hints.context_re`
Regular expression used to recognize and display differently messages like:

```
instantiated from
within this context
required from here
```

#### `(bpg):compil_hints.harsh_signs_removal_enabled`
Improves greatly the time required to remove signs. However, this options does
remove all signs in a buffer, even the one not placed by compil-hints.

boolean: 1/0; default: `! exists('*execute')` => false with recent versions of
Vim

## Requirements / Installation

  * Requirements: Vim 7.+,
    [`+balloon_eval`](http://vimhelp.appspot.com/various.txt.html#%2bballoon_eval),
    [`+signs`](http://vimhelp.appspot.com/various.txt.html#%2bsigns),
    [lh-vim-lib](http://github.com/LucHermitte/lh-vim-lib)

  * With [vim-addon-manager](https://github.com/MarcWeber/vim-addon-manager), install vim-compil-hints.

    ```vim
    ActivateAddons vim-compil-hints
    ```

  * or with [vim-flavor](http://github.com/kana/vim-flavor) which also supports
    dependencies:

    ```
    flavor 'LucHermitte/vim-compil-hints'
    ```

  * or with Vundle/NeoBundle (expecting I haven't forgotten anything):

    ```vim
    Bundle 'LucHermitte/lh-vim-lib'
    Bundle 'LucHermitte/vim-compil-hints'
    ```

## TO DO
- Handle local options for balloon use
- When the quickfix list changes (background compilation with
  [BuildToolsWrapper](https://github.com/LucHermitte/vim-build-tools-wrapper/)), the balloons
  stop displaying anything.
- Test UTF-8 glyphs when icons cannot be used
- Listen for `QuickFixCmdPost`, avoid parsing multiple times when doing
  background compilation...

## History
* V 1.0.1.
    * Detect when XPM icons cannot be used.
    * USe the first UTF-8 glyphs
* V 1.0.0.
    * The XPM icons used come from Vim source code, they're under
      [Vim License](doc/uganda.txt).
    * Options have been renamed from `compil_hint_xxx` to `compil_hints.xxx`

* V 0.2.x.
    * This plugin is strongly inspired by syntastic, but it restricts its work to
    the result of the compilation.

## Notes
NB: it doesn't copy qflist() but always fetch the last version in order to
automagically rely on vim to update the line numbers.
