" +===========================================================+
" | compackd: an easy, lazy, & small [neo]vim package manager |
" +===========================================================+
"
" 1. Download compackd.vim and put it in 'autoload' directory
"
"   # Neovim
"   curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/compackd.vim --create-dirs \
"     https://raw.githubusercontent.com/josephtingiris/compackd/master/autoload/compackd.vim
"
"   # Vim
"   curl -fLo ~/.vim/autoload/compackd.vim --create-dirs \
"     https://raw.githubusercontent.com/josephtingiris/compackd/master/autoload/compackd.vim
"
" 2. Add a compackd section to your ~/.vimrc (or ~/.config/nvim/init.vim for Neovim)
"
"   call compackd#()
"
"   " Load packages and their configs, e.g.
"   Pack 'vim-airline/vim-airline'
"   let g:airline_detect_iminsert=1
"
" 3. Reload the file or restart Vim, then you can,
"
"     :PackInstall to install packages
"     :PackUpdate  to update packages
"     :PackDiff    to review the changes from the last update
"     :PackClean   to remove packages no longer in the list
"
" For more information, see https://github.com/josephtingiris/compackd
"
"
" Copyright (c) 2025 Joseph Tingiris
" Copyright (c) 2024 Junegunn Choi
"
" MIT License
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software"), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
"
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"
" bootstrap
"

" if compackd.vim has been previously loaded then finish
if exists('g:compackd_loaded')
  finish
endif

" global defaults
let g:compackd_loaded = 1
let g:compackd_specs = {}
let g:compackd_supported = get(g:, 'compackd_supported', 1)

" script-local variables used to conditionally define the following functions and values within them
let s:compackd_is_win = has('win32') || has('win64')
let s:compackd_is_wsl = has('win32unix') || has('wsl')
let s:compackd_is_nvim = has('nvim-0.2') || (has('nvim') && exists('*jobwait') && !s:compackd_is_win)
let s:compackd_is_vim = !s:compackd_is_nvim && has('patch-8.0.0039') && exists('*job_start')

"
" compackd# autoload functions
"

" compackd#(...) : validate compackd_packages_dir & hand off to compackd_commands
function! compackd#(...)
  " require a supported [neo]vim version
  if !g:compackd_supported  | return | endif

  call s:diagnostic("function! compackd#(" . string(a:000) . ")", 5)

  let g:compackd_vim_dir = get(g:, 'compackd_vim_dir', '')

  if empty(g:compackd_vim_dir)
    if s:compackd_is_nvim
      let g:compackd_vim_dir = stdpath("config")
    elseif !empty(&rtp)
      let g:compackd_vim_dir = s:compackd_get_path(split(&rtp, ',')[0])
    else
      return s:echo_err('Unable to automatically determine the vim directory. Try calling compackd#() with a path argument.')
    endif
  endif

  if a:0 > 0
    let s:compackd_packpath = s:compackd_get_path(s:compackd_get_fnamemodify(s:compackd_get_expand(a:1), ':p'))
  elseif exists('g:pack_path')
    let s:compackd_packpath = s:compackd_get_path(g:pack_path)
  else
    let s:compackd_packpath = s:compackd_get_path(g:compackd_vim_dir . '/pack/.d')
  endif

  call s:diagnostic("function! compackd#(" . string(a:000) . ") - s:compackd_packpath = " . s:compackd_packpath, 7)

  " only append s:compackd_packpath to packpath once
  let compackd_packpath_last=split(&packpath, '\\\@<!,')[-1]

  if s:compackd_packpath != compackd_packpath_last
    let &packpath.=',' . s:compackd_packpath
  else
    let &rtp=&rtp
    let &packpath=&packpath
  endif

  call s:diagnostic("function! compackd#(" . string(a:000) . ") - &packpath = " . &packpath, 17)

  if s:compackd_is_match(s:compackd_packpath, g:compackd_vim_dir . "/plugin")
    return s:echo_err('Invalid package directory "'.s:compackd_packpath.'" is a standard Vim runtime path and is not allowed.')
  endif

  let g:compackd_packages_dir = s:compackd_packpath . "/pack/compackd/opt"

  call s:diagnostic("g:compackd_packages_dir = " . g:compackd_packages_dir, 3)

  call s:compackd_spec_set_requirements()
  call s:compackd_commands()

  return 1
endfunction

" compackd#begin(...) : this is for backward compatibility with vim-plug
function! compackd#begin(...)
  " require a supported [neo]vim version
  if !g:compackd_supported  | return | endif

  call s:diagnostic("function! compackd#begin(" . string(a:000) . ")", 5)

  compackd#(a:000)
endfunction

" compackd#end() : this for backward compatibility with vim-plug
function! compackd#end()
  " require a supported [neo]vim version
  if !g:compackd_supported  | return | endif

  call s:diagnostic("function! compackd#end()", 5)

  if !exists('g:compackd_specs')
    return s:echo_err('compackd#end() called without calling compackd#begin() first')
  endif

  call s:compackd_package_add_all()

  filetype plugin indent on

  if has('vim_starting')
    if has('syntax') && !exists('g:syntax_on')
      syntax enable
    endif
  endif
endfunction

"
" script-local : initialization
"

" s:echo_err(str) : echo a custom error message
function! s:echo_err(str)
  echohl ErrorMsg
  echom '[compackd] ERROR : ' . string(a:str)
  echohl None
endfunction


" require a supported [neo]vim version; if not running under nvim or vim then share requirements and finish
if !s:compackd_is_nvim && !s:compackd_is_vim
  g:compackd_supported = 0
  call s:echo_err("Neovim or Vim 8.0.0039+ is required.")
  finish
endif

" require git 2+
if !executable('git')
  g:compackd_supported = 0
  call s:echo_err('git not found executable.  git version 2+ is required.')
  finish
endif

" for vim on windows, require multi_byte
if !s:compackd_is_nvim && (s:compackd_is_win || s:compackd_is_wsl) && !has('multi_byte')
  g:compackd_supported = 0
  call s:echo_err('Vim with +multi_byte is required on Windows to run shell commands. Enable +iconv for best results.')
  finish
endif

" disallow certain shells if shellslash is set
if s:compackd_is_win && &shellslash && (&shell =~# 'cmd\(\.exe\)\?$' || s:compackd_is_powershell(&shell))
  g:compackd_supported = 0
  call s:echo_err(&shell . ' is not supported when shellslash is set.')
  finish
endif

"
" script-local : compackd_ command functions
"

" s:compackd_Pack(repo, ...) : processes Pack statements
function! s:compackd_Pack(repo, ...)
  call s:diagnostic("function! s:compackd_Pack(" . string(a:repo) . ", " . string(a:000) . ")", 5)

  if a:0 > 1
    return s:echo_err('compackd_Pack() : invalid number of arguments (1..2)')
  endif

  try
    let repo = s:compackd_get_trim(a:repo)
    let opts = a:0 == 1 ? s:compackd_spec_get_options(a:1) : s:compackd_spec_default_options
    let name = get(opts, 'package_name', s:compackd_get_fnamemodify(repo, ':t:s?\.git$??'))
    let spec = extend(s:compackd_spec_get_properties(name, repo), opts)

    let g:compackd_specs[name] = spec

    if isdirectory(spec.package_dir)
      call s:compackd_package_add(name)
    else
      call s:echo_warn("package '" . name . "' is not installed; run :PackInstall")

      " install on the fly? (this functions but output is ugly; the setup/output tab needs work)
      "call s:compackd_PackInstall(0, [name])
    endif

    call s:diagnostic("s:compackd_Pack() : Pack name = '" . string(name) . "', packadd = " . string(spec.packadd), 3)

    " install function(s) to load the package
    if has_key(spec, 'lazy_functions')
      call s:compackd_package_add_lazy_functions(name, spec, 'lazy_functions')
    endif

    " install filtype(s) to load the package
    if has_key(spec, 'lazy_filetypes')
      call s:compackd_package_add_lazy_filetypes(name, spec, 'lazy_filetypes')
    endif

  catch
    return s:echo_err(repo . ' ' . v:exception)
  endtry
endfunction

" s:compackd_PackClean(force) : removed ununsed packages
function! s:compackd_PackClean(force)
  call s:diagnostic("function! s:compackd_PackClean(" . string(a:force) . ")", 5)

  call s:compackd_tab_prepare()
  call append(0, 'Searching for invalid packages in '.g:compackd_packages_dir)
  call append(1, '')

  " List of valid directories
  let dirs = []
  let errs = {}
  let [cnt, total] = [0, len(g:compackd_specs)]
  for [name, spec] in items(g:compackd_specs)
    if !s:compackd_spec_get_uri(name) || get(spec, 'frozen', 0)
      call add(dirs, spec.package_dir)
    else
      let [err, clean] = s:compackd_git_validate(spec, 1)
      if clean
        let errs[spec.package_dir] = s:compackd_get_lines(err)[0]
      else
        call add(dirs, spec.package_dir)
      endif
    endif
    let cnt += 1
    call s:compackd_tab_progress_bar(2, repeat('=', cnt), total)
    normal! 2G
    redraw
  endfor

  let allowed = {}
  for dir in dirs
    let allowed[s:compackd_get_dir_path(s:compackd_get_fnamemodify(dir, ':h:h'))] = 1
    let allowed[dir] = 1
    for child in s:compackd_get_dir_glob_subdir(dir)
      let allowed[child] = 1
    endfor
  endfor

  let pending = []
  let found = sort(s:compackd_get_dir_glob_subdir(g:compackd_packages_dir))
  while !empty(found)
    let f = remove(found, 0)
    if !has_key(allowed, f) && isdirectory(f)
      call add(pending, f)
      call append(line('$'), '- ' . f)
      if has_key(errs, f)
        call append(line('$'), '    ' . errs[f])
      endif
      let found = filter(found, 'stridx(v:val, f) != 0')
    endif
  endwhile

  " what is this 4?

  4
  redraw
  if empty(pending)
    call append(line('$'), 'Already clean.')
  else
    let s:clean_count = 0
    call append(3, ['Directories to delete:', ''])
    redraw!
    if a:force || s:compackd_tab_ask_no_interrupt('Delete all directories?')
      call s:compackd_package_delete([6, line('$')], 1)
    else
      call setline(4, 'Cancelled.')
      nnoremap <silent> <buffer> d :set opfunc=<SID>compackd_package_delete_opfunc<CR>g@
      nmap <silent> <buffer> dd d_
      xnoremap <silent> <buffer> d :<C-U>call <SID>compackd_package_delete_opfunc(visualmode(), 1)<CR>
      echo 'Delete the lines (d{motion}) to delete the corresponding directories'
    endif
  endif
  4
  setlocal nomodifiable
endfunction

" s:compackd_PackDiff() : identify which packages differ from their origin urls
function! s:compackd_PackDiff()
  call s:diagnostic("function! s:compackd_PackDiff()", 5)

  call s:compackd_tab_prepare()
  call append(0, ['Collecting changes ...', ''])
  let cnts = [0, 0]
  let bar = ''
  let total = filter(copy(g:compackd_specs), 's:compackd_spec_get_uri(v:key) && isdirectory(v:val.package_dir)')
  call s:compackd_tab_progress_bar(2, bar, len(total))
  for origin in [1, 0]
    let packs = reverse(sort(items(filter(copy(total), (origin ? '' : '!').'(has_key(v:val, "commit") || has_key(v:val, "tag"))'))))
    if empty(packs)
      continue
    endif
    call s:compackd_tab_append_ul(2, origin ? 'Pending updates:' : 'Last update:')
    for [k, v] in packs
      let branch = s:compackd_git_get_origin_branch(v)
      if len(branch)
        let range = origin ? '..origin/'.branch : 'HEAD@{1}..'
        let cmd = ['git', 'log', '--graph', '--color=never']
        if s:compackd_git_is_minimum_version(2, 10, 0)
          call add(cmd, '--no-show-signature')
        endif
        call extend(cmd, ['--pretty=format:%x01%h%x01%d%x01%s%x01%cr', range])
        if has_key(v, 'plugin_dir')
          call extend(cmd, ['--', v.plugin_dir])
        endif
        let diff = s:compackd_exec_cd_trim_newlines(cmd, v.package_dir)
        if !empty(diff)
          let ref = has_key(v, 'tag') ? (' (tag: '.v.tag.')') : has_key(v, 'commit') ? (' '.v.commit) : ''
          call append(5, extend(['', '- '.k.':'.ref], map(s:compackd_get_lines(diff), 's:compackd_git_get_line_format(v:val)')))
          let cnts[origin] += 1
        endif
      endif
      let bar .= '='
      call s:compackd_tab_progress_bar(2, bar, len(total))
      normal! 2G
      redraw
    endfor
    if !cnts[origin]
      call append(5, ['', 'N/A'])
    endif
  endfor
  call setline(1, printf('%d package(s) updated.', cnts[0])
        \ . (cnts[1] ? printf(' %d package(s) have pending updates.', cnts[1]) : ''))

  if cnts[0] || cnts[1]
    nnoremap <silent> <buffer> <Plug>(pack-preview) :silent! call <SID>compackd_git_commit()<CR>
    if empty(maparg("\<CR>", 'n'))
      nmap <buffer> <CR> <Plug>(pack-preview)
    endif
    if empty(maparg('o', 'n'))
      nmap <buffer> o <Plug>(pack-preview)
    endif
  endif
  if cnts[0]
    nnoremap <silent> <buffer> X :call <SID>compackd_git_reset()<CR>
    echo "Press 'X' on each block to revert the update"
  endif
  normal! gg
  setlocal nomodifiable
endfunction

"! s:compackd_PackInstall(force, names) : install packages
function! s:compackd_PackInstall(force, names)
  call s:diagnostic("function! s:compackd_PackInstall(" . string(a:force) . "," . string(a:names) . ")", 5)

  call s:compackd_package_setup(0, a:force, a:names)
endfunction

" s:compackd_PackSnapshot(force, ...) : create a snapshot of the git hashes for all installed packages
function! s:compackd_PackSnapshot(force, ...) abort
  call s:diagnostic("function! s:compackd_PackSnapshot(" . string(a:force) . ", " . string(a:000) . ")", 5)

  let snapshot_file = empty(a:000) ? 'compackd-snapshot.vim' : s:compackd_get_expand(a:1)

  call s:compackd_tab_prepare()
  setf vim
  call append(0, ['" Generated by compackd on '. strftime("%c"),
        \ '"',
        \ '" To restore this snapshot file, in vim:',
        \ '"',
        \ '" :source ' . snapshot_file,
        \ '"',
        \ '" Or from the shell, execute:',
        \ '"',
        \ '" vim -S ' . snapshot_file,
        \ '', '', 'PackUpdate!'])

  let anchor = line('$') - 3
  let names = sort(keys(filter(copy(g:compackd_specs),
        \'has_key(v:val, "uri") && isdirectory(v:val.package_dir)')))
  for name in reverse(names)
    let sha = has_key(g:compackd_specs[name], 'commit') ? g:compackd_specs[name].commit : s:compackd_git_get_revision(g:compackd_specs[name].package_dir)
    if !empty(sha)
      call append(anchor, printf("silent! let g:compackd_specs['%s'].commit = '%s'", name, sha))
      redraw
    endif
  endfor

  if filereadable(snapshot_file) && !(a:force || s:compackd_tab_ask(snapshot_file . ' exists. Overwrite?'))
    return
  endif

  call writefile(getline(1, '$'), snapshot_file)
  echo 'Saved as ' . snapshot_file
  silent execute 'e' s:compackd_get_escape_space(snapshot_file)
  setf vim
endfunction

" s:compackd_PackStatus() : display package status
function! s:compackd_PackStatus()
  call s:diagnostic("function! s:compackd_PackStatus()", 5)

  call s:compackd_tab_prepare()
  call append(0, 'Checking packages')
  call append(1, '')

  let ecnt = 0
  let unloaded = 0
  let [cnt, total] = [0, len(g:compackd_specs)]
  for [name, spec] in items(g:compackd_specs)
    let is_dir = isdirectory(spec.package_dir)
    if has_key(spec, 'uri')
      if is_dir
        let [err, _] = s:compackd_git_validate(spec, 1)
        let [valid, msg] = [empty(err), empty(err) ? 'OK' : err]
      else
        let [valid, msg] = [0, 'Not found. Try PackInstall.']
      endif
    else
      if is_dir
        let [valid, msg] = [1, 'OK']
      else
        let [valid, msg] = [0, 'Not found.']
      endif
    endif
    let cnt += 1
    let ecnt += !valid

    if is_dir && !spec.packadd
      let unloaded = 1
      let msg .= ' (not loaded)'
    endif

    call s:compackd_tab_progress_bar(2, repeat('=', cnt), total)
    call append(3, s:compackd_tab_get_formatted_line(valid ? '-' : 'x', name, msg))
    normal! 2G
    redraw
  endfor

  call setline(1, 'Finished. '.ecnt.' error(s).')

  normal! gg

  setlocal nomodifiable
  if unloaded
    echo "Press 'L' on each line to load package, or 'U' to update"

    nnoremap <silent> <buffer> L :call <SID>compackd_tab_bindings_status_load(line('.'))<CR>
    xnoremap <silent> <buffer> L :call <SID>compackd_tab_bindings_status_load(line('.'))<CR>
  endif
endfunction

" s:compackd_PackUpdate(force, names) : update all packages
function! s:compackd_PackUpdate(force, names)
  call s:diagnostic("function! s:compackd_PackUpdate(" . string(a:force) . "," . string(a:names) . ")", 5)

  call s:compackd_package_setup(1, a:force, a:names)
endfunction

" s:compackd_PackUpgrade() : git clone and upgrade this source file
function! s:compackd_PackUpgrade()
  call s:diagnostic("function! s:compackd_PackUpgrade()", 5)

  echo 'Downloading the latest version of compackd'
  redraw
  let tmp_dir = s:compackd_get_tempname()
  let tmp_file = tmp_dir . '/autoload/compackd.vim'

  try
    let out = s:compackd_exec_cd(['git', 'clone', '--depth', '2', s:compackd_git_url, tmp_dir])
    if v:shell_error
      return s:echo_err('Error upgrading compackd: '. out)
    endif

    if readfile(s:compackd_sfile) ==# readfile(tmp_file)
      echo 'compackd is up-to-date'
      return 0
    else
      call rename(s:compackd_sfile, s:compackd_sfile . '.old')
      call rename(tmp_file, s:compackd_sfile)

      unlet g:compackd_loaded

      echo 'compackd has been upgraded'
      return 1
    endif
  finally
    " this doesn't remove the directory itself?
    silent! call s:compackd_do_rm_rf(tmp_dir . '/')
  endtry
endfunction

"
" script-local : compackd_ interactive functions
"

" s:compackd_commands() : define Pack* user commands
function! s:compackd_commands()
  call s:diagnostic("function! s:compackd_commands()", 7)

  command! -nargs=+ -bar Pack call s:compackd_Pack(<args>)
  command! -nargs=0 -bar -bang PackClean call s:compackd_PackClean(<bang>0)
  command! -nargs=0 -bar PackDiff call s:compackd_PackDiff()
  command! -nargs=* -bar -bang -complete=customlist,s:compackd_spec_get_names PackInstall call s:compackd_PackInstall(<bang>0, [<f-args>])
  command! -nargs=? -bar -bang -complete=file PackSnapshot call s:compackd_PackSnapshot(<bang>0, <f-args>)
  command! -nargs=0 -bar PackStatus  call s:compackd_PackStatus()
  command! -nargs=* -bar -bang -complete=customlist,s:compackd_spec_get_names PackUpdate  call s:compackd_PackUpdate(<bang>0, [<f-args>])
  command! -nargs=0 -bar PackUpgrade
        \ if s:compackd_PackUpgrade() | execute 'source' s:compackd_get_escape_space(s:compackd_sfile) | endif

  " for backward compatibility with vim-plug
  command! -nargs=+ -bar Plug :Pack <args>
  command! -nargs=0 -bar -bang PlugClean :PackClean
  command! -nargs=0 -bar PlugDiff :PackDiff
  command! -nargs=* -bar -bang -complete=customlist,s:compackd_spec_get_names PlugInstall :PackInstall <args>
  command! -nargs=? -bar -bang -complete=file PlugSnapshot :PackSnapshot <args>
  command! -nargs=0 -bar PlugStatus :PackStatus
  command! -nargs=* -bar -bang -complete=customlist,s:compackd_spec_get_names PlugUpdate :PackUpdate <args>
  command! -nargs=0 -bar PlugUpgrade :PackUpgrade
endfunction

"
" script-local : compackd_ do functions
"

" s:compackd_do_autocmd(...) : doautocmd joined arguments
function! s:compackd_do_autocmd(...)
  call s:diagnostic("function! s:compackd_do_autocmd(" . string(a:000) . ")", 41)

  if exists('#'.join(a:000, '#'))
    execute 'doautocmd' ((v:version > 703 || has('patch442')) ? '<nomodeline>' : '') join(a:000)
  endif
endfunction

"" s:compackd_do_dict_add(dict, key, val) : add a key/value pair to a dictionary
function! s:compackd_do_dict_add(dict, key, val)
  call s:diagnostic("function! s:compackd_do_dict_add(" . string(a:dict) . ", " . string(a:key) . ", " . string(a:val) . ")", 41)

  let a:dict[a:key] = add(get(a:dict, a:key, []), a:val)
endfunction

" s:compackd_do_rm_rf(dir) : recursively remove a directory
function! s:compackd_do_rm_rf(dir)
  call s:diagnostic("s:compackd_do_rm_rf(" . string(a:dir) . ")", 41)

  if isdirectory(a:dir)
    " FIXME: this should be more safe (what if it's running as root?  or removes the home directory?  etc)
    return s:compackd_exec_cd(s:compackd_is_win ? 'rmdir /S /Q '.s:compackd_get_escape_shell_args(a:dir) : ['rm', '-rf', a:dir])
  endif
endfunction

" s:compackd_do_source(from, ...) : [deprecated] source all files in a directory that match a pattern
function! s:compackd_do_source(from, ...)
  call s:diagnostic("function! s:compackd_do_source(" . string(a:from) . ", " . string(a:000) . ")", 9)

  " needed?
  return
  let found = 0
  for pattern in a:000
    for vim in s:compackd_get_dir_glob(a:from, pattern)
      execute 'source' s:compackd_get_escape_space(vim)
      let found = 1
    endfor
  endfor
  return found
endfunction

"
" script-local : compackd_ exec functions
"

" s:compackd_do_exec_bang(cmd, ...) : (attempt to) silently execute a system command
function! s:compackd_exec_bang(cmd, ...)
  call s:diagnostic("function! s:compackd_exec_bang(" . string(a:cmd) . ", " . string(a:000) . ")", 9)

  let batchfile = ''
  try
    let [sh, shellcmdflag, shrd] = s:compackd_os_set_shell(a:0)

    " FIXME: Escaping is isn't finished. We could use shellescape with eval, but it won't work on Windows.
    let cmd = a:0 ? s:compackd_get_cd_with_command(a:cmd, a:1) : a:cmd

    if s:compackd_is_win
      let [batchfile, cmd] = s:compackd_os_do_batchfile(cmd)
    endif

    let g:compackd_exec_bang_cmd = (s:compackd_is_win && has('gui_running') ? 'silent ' : '').'!'.escape(cmd, '#!%')

    execute "normal! :execute g:compackd_exec_bang_cmd\<CR>\<CR>"
  finally

    unlet g:compackd_exec_bang_cmd

    let [&shell, &shellcmdflag, &shellredir] = [sh, shellcmdflag, shrd]
    if s:compackd_is_win && filereadable(batchfile)
      call delete(batchfile)
    endif
  endtry
  return v:shell_error ? 'Exit status: ' . v:shell_error : ''
endfunction

" s:compackd_exec_cd(cmd, ...) : cd to a directory and execute a system command
function! s:compackd_exec_cd(cmd, ...)
  call s:diagnostic("function! s:compackd_exec_cd(" . string(a:cmd) . ", " . string(a:000) . ")", 9)

  let batchfile = ''
  try
    let [sh, shellcmdflag, shrd] = s:compackd_os_set_shell(1)
    if type(a:cmd) == s:compackd_type.list
      " Neovim's system() supports list argument to bypass the shell
      " but it cannot set the working directory for the command.
      " Assume that the command does not rely on the shell.
      if s:compackd_is_nvim && a:0 == 0
        return system(a:cmd)
      endif
      let cmd = join(map(copy(a:cmd), 's:compackd_get_escape_shell_args(v:val, {"shell": &shell, "script": 0})'))
      if s:compackd_is_powershell(&shell)
        let cmd = '& ' . cmd
      endif
    else
      let cmd = a:cmd
    endif
    if a:0 > 0
      let cmd = s:compackd_get_cd_with_command(cmd, a:1, type(a:cmd) != s:compackd_type.list)
    endif
    if s:compackd_is_win && type(a:cmd) != s:compackd_type.list
      let [batchfile, cmd] = s:compackd_os_do_batchfile(cmd)
    endif
    return system(cmd)
  finally
    let [&shell, &shellcmdflag, &shellredir] = [sh, shellcmdflag, shrd]
    if s:compackd_is_win && filereadable(batchfile)
      call delete(batchfile)
    endif
  endtry
endfunction

" s:compackd_exec_cd_trim_newlines(...) : cd to a directory, execute a sytem command, and return a dictionary sans newlines
function! s:compackd_exec_cd_trim_newlines(...)
  call s:diagnostic("function! s:compackd_exec_cd_trim_newlines(" . string(a:000) . ")", 9)

  let ret = call('s:compackd_exec_cd', a:000)
  return v:shell_error ? '' : substitute(ret, '\n$', '', '')
endfunction

"
" script-local : compackd_ get functions
"

" s:compackd_get_buffer_position(word) : return the coordinates of a word in a buffer
function! s:compackd_get_buffer_position(word)
  call s:diagnostic("function! s:compackd_get_buffer_position(" . string(a:word) . ")", 61)

  let max = line('$')
  for i in range(4, max > 4 ? max : 4)
    if getline(i) =~# '^[-+x*] '.a:word.':'
      for j in range(i + 1, max > 5 ? max : 5)
        if getline(j) !~ '^ '
          return [i, j - 1]
        endif
      endfor
      return [i, i]
    endif
  endfor
  return [0, 0]
endfunction

" s:compackd_get_cd_with_command(cmd, dir, ...) : return a string that will cd to a directory and then execute a command
function! s:compackd_get_cd_with_command(cmd, dir, ...)
  call s:diagnostic("function! s:compackd_get_cd_with_command(" . string(a:cmd) . ", " . string(a:dir) . ", " . string(a:000) . ")", 61)

  let script = a:0 > 0 ? a:1 : 1
  let pwsh = s:compackd_is_powershell(&shell)
  let cd = s:compackd_is_win && !pwsh ? 'cd /d' : 'cd'
  let sep = pwsh ? ';' : '&&'

  return printf('%s %s %s %s', cd, s:compackd_get_escape_shell_args(a:dir, {'script': script, 'shell': &shell}), sep, a:cmd)
endfunction

" s:compackd_get_cwd() : return current working directory
function! s:compackd_get_cwd()
  call s:diagnostic("function! s:compackd_get_cwd()", 61)

  return s:compackd_os_call('getcwd')
endfunction

" s:compackd_get_dir_glob(from, pattern) : return a list of files from a directory that match a glob pattern
function! s:compackd_get_dir_glob(dir, pattern)
  call s:diagnostic("function! s:compackd_get_dir_glob(" . string(a:dir) . ", " . string(a:pattern) . ")", 61)

  return s:compackd_get_lines(globpath(a:dir, a:pattern))
endfunction

" s:compackd_get_dir_glob_subdir(path) : return a list of all sub-directories in a path?
function! s:compackd_get_dir_glob_subdir(path)
  call s:diagnostic("function! s:compackd_get_dir_glob_subdir(" . string(a:path) . ")", 61)

  return map(filter(s:compackd_get_dir_glob(a:path, '**'), 'isdirectory(v:val)'), 's:compackd_get_dir_path(v:val)')
endfunction

" s:compackd_get_dir_path(path) : return a valid drectory path
function! s:compackd_get_dir_path(path)
  call s:diagnostic("function! s:compackd_get_dir_path(" . string(a:path) . ")", 61) " this function gets called a LOT

  if s:compackd_is_win
    return s:compackd_get_path(a:path) . '\'
  else
    return substitute(a:path, '[/\\]*$', '/', '')
  endif
endfunction

" s:compackd_get_escape_shell_args() : return an escaped shell argument based on the shell variant
function! s:compackd_get_escape_shell_args(arg, ...)
  call s:diagnostic("function! s:compackd_get_escape_shell_args(" . string(a:arg) . ", ...)", 61)

  if a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  endif

  let opts = a:0 > 0 && type(a:1) == s:compackd_type.dict ? a:1 : {}
  let shell = get(opts, 'shell', s:compackd_is_win ? 'cmd.exe' : 'sh')
  let script = get(opts, 'script', 1)

  if shell =~# 'cmd\(\.exe\)\?$'
    return s:compackd_get_escape_shell_cmd(a:arg, script)
  elseif s:compackd_is_powershell(shell)
    return s:compackd_get_escape_shell_pwsh(a:arg)
  endif

  return s:compackd_get_escape_shell_sh(a:arg)
endfunction

" s:compackd_get_escape_shell_cmd(arg, script) : return an escaped shell command
function! s:compackd_get_escape_shell_cmd(arg, script)
  call s:diagnostic("function! s:compackd_get_escape_shell_cmd(" . string(a:arg) . ", " . string(a:script) . ")", 61)

  let escaped = substitute('"'.a:arg.'"', '[&|<>()@^!"]', '^&', 'g')
  return substitute(escaped, '%', (a:script ? '%' : '^') . '&', 'g')
endfunction

" s:compackd_get_escape_shell_pwsh(arg) : return an escaped command for powershell
function! s:compackd_get_escape_shell_pwsh(arg)
  call s:diagnostic("function! s:compackd_get_escape_shell_pwsh(" . string(a:arg) . ")", 61)

  return "'".substitute(escape(a:arg, '\"'), "'", "''", 'g')."'"
endfunction

" s:compackd_get_escape_shell_sh(arg) : return an escaped command for sh
function! s:compackd_get_escape_shell_sh(arg)
  call s:diagnostic("function! s:compackd_get_escape_shell_sh(" . string(a:arg) . ")", 61)

  return "'".substitute(a:arg, "'", "'\\\\''", 'g')."'"
endfunction

" s:compackd_get_escape_space(path) : return a space escaped string
function! s:compackd_get_escape_space(path)
  call s:diagnostic("function! s:compackd_get_escape_space(" . string (a:path) . ")", 61)

  return escape(a:path, ' ')
endfunction

" s:compackd_get_escape_space_comman(path) : return a space+comma escaped string
function! s:compackd_get_escape_space_comma(path)
  call s:diagnostic("function! s:compackd_get_escape_space_comma(" . string(a:path) . ")", 61)

  return escape(a:path, ' ,')
endfunction

" s:compackd_get_expand() : return an expanded string
function! s:compackd_get_expand(fmt)
  call s:diagnostic("function! s:compackd_get_expand(" . string(a:fmt) . ")", 61)

  return s:compackd_os_call('expand', a:fmt, 1)
endfunction

" s:compackd_get_fnamemodify() : return  a modified filename
function! s:compackd_get_fnamemodify(fname, mods)
  call s:diagnostic("function! s:compackd_get_fnamemodify(" . string(a:fname) . ", " . string(a:mods) . ")", 61)

  return s:compackd_os_call('fnamemodify', a:fname, a:mods)
endfunction

" s:compackd_get_lines(str) : return a list of lines separated by \r\n
function! s:compackd_get_lines(str)
  call s:diagnostic("function! s:compackd_get_lines(" . string(a:str) . ")", 61)

  return split(a:str, "[\r\n]")
endfunction

" s:compackd_get_lines_last(str) : return the last line from a list
function! s:compackd_get_lines_last(str)
  call s:diagnostic("function! s:compackd_get_lines_last(" . string(a:str) . ")", 61)

  return get(s:compackd_get_lines(a:str), -1, '')
endfunction

" s:compackd_get_lines_last_not_empty(list) : return the last non-empty line from a list
function! s:compackd_get_lines_last_not_empty(list)
  call s:diagnostic("function! s:compackd_get_lines_last_not_empty(" . string(a:list) . ")", 61)

  let len = len(a:list)
  for idx in range(len)
    let line = a:list[len-idx-1]
    if !empty(line)
      return line
    endif
  endfor
  return ''
endfunction

" s:compackd_get_pad_left(str, len) : return a left padded string
function! s:compackd_get_pad_left(str, len)
  call s:diagnostic("function! s:compackd_get_pad_left(" . string(a:str) . ", " . string(a:len) . ")", 61)

  return a:str . repeat(' ', a:len - len(a:str))
endfunction

" s:compackd_get_path(path) ; return a trimmed path
function! s:compackd_get_path(path)
  call s:diagnostic("function! s:compackd_get_path(" . string(a:path) . ")", 61)

  if s:compackd_is_win
    return s:compackd_get_trim(substitute(a:path, '/', '\', 'g'))
  else
    return s:compackd_get_trim(a:path)
  endif
endfunction

" s:compackd_get_rtp() : return a dictionary of paths from the runtimepath separated by ,
function! s:compackd_get_rtp()
  call s:diagnostic("function! s:compackd_get_rtp()", 61)

  return split(&rtp, '\\\@<!,')
endfunction

"s:compackd_get_tempname() : return a temporary filename
function! s:compackd_get_tempname()
  call s:diagnostic("function! s:compackd_get_tempname()", 61)

  return s:compackd_os_call('tempname')
endfunction

" s:compackd_get_trim(str) : return a string without any trailing spaces
function! s:compackd_get_trim(str)
  call s:diagnostic("function! s:compackd_get_trim(" . string(a:str) . ")", 61)

  return substitute(a:str, '[\/]\+$', '', '')
endfunction

"
" script-local : compackd_ git functions
"

" s:compackd_git_checkout(spec) : git checkout a spec
function! s:compackd_git_checkout(spec)
  call s:diagnostic("function! s:compackd_git_checkout(" . string(a:spec) . ")", 13)

  let sha = a:spec.commit
  let output = s:compackd_git_get_revision(a:spec.package_dir)
  let error = 0
  if !empty(output) && !s:compackd_is_match(sha, s:compackd_get_lines(output)[0])
    let credential_helper = s:compackd_git_is_credential_helper_disabled() ? '-c credential.helper= ' : ''
    let output = s:compackd_exec_cd(
          \ 'git '.credential_helper.'fetch --depth 999999 && git checkout '.s:compackd_get_escape_shell_args(sha).' --', a:spec.package_dir)
    let error = v:shell_error
  endif
  return [output, error]
endfunction

" s:compackd_git_commit() : git commit a package via compackd_PackDiff
function! s:compackd_git_commit()
  call s:diagnostic("function! s:compackd_git_commit()", 13)

  if b:pack_preview < 0
    let b:pack_preview = !s:compackd_is_preview_window_open()
  endif

  let sha = matchstr(getline('.'), '^  \X*\zs[0-9a-f]\{7,9}')
  if empty(sha)
    let name = matchstr(getline('.'), '^- \zs[^:]*\ze:$')
    if empty(name)
      return
    endif
    let title = 'HEAD@{1}..'
    let command = 'git diff --no-color HEAD@{1}'
  else
    let title = sha
    let command = 'git show --no-color --pretty=medium '.sha
    let name = s:compackd_tab_get_package_name_from_line(line('.'))
  endif

  if empty(name) || !has_key(g:compackd_specs, name) || !isdirectory(g:compackd_specs[name].package_dir)
    return
  endif

  if !s:compackd_is_preview_window_open()
    execute get(g:, 'pack_pwindow', 'vertical rightbelow new')
    execute 'e' title
  else
    execute 'pedit' title
    wincmd P
  endif
  setlocal previewwindow filetype=git buftype=nofile bufhidden=wipe nobuflisted modifiable
  let batchfile = ''
  try
    let [sh, shellcmdflag, shrd] = s:compackd_os_set_shell(1)
    let cmd = 'cd '.s:compackd_get_escape_shell_args(g:compackd_specs[name].package_dir).' && '.command
    if s:compackd_is_win
      let [batchfile, cmd] = s:compackd_os_do_batchfile(cmd)
    endif
    execute 'silent %!' cmd
  finally
    let [&shell, &shellcmdflag, &shellredir] = [sh, shellcmdflag, shrd]
    if s:compackd_is_win && filereadable(batchfile)
      call delete(batchfile)
    endif
  endtry
  setlocal nomodifiable

  nnoremap <silent> <buffer> q :q<CR>

  wincmd p
endfunction

" s:compackd_git_get_branch_or_head(dir) abort : return the git branch name or HEAD from a git directory
function! s:compackd_git_get_branch_or_head(dir) abort
  call s:diagnostic("function! s:compackd_git_get_branch_or_head(" . string(a:dir) . ") abort", 61)

  let git_dir = s:compackd_git_get_dir(a:dir)
  let head = git_dir . '/HEAD'

  if empty(git_dir) || !filereadable(head)
    return ''
  endif

  let branch = matchstr(get(readfile(head), 0, ''), '^ref: refs/heads/\zs.*')
  return len(branch) ? branch : 'HEAD'
endfunction

" s:compackd_git_get_checkout_command(spec) : return a list of the git checkout arguments for a spec
function! s:compackd_git_get_checkout_command(spec)
  call s:diagnostic("function! s:compackd_git_get_checkout_command(" . string(a:spec) . ")", 61)

  let a:spec.branch = s:compackd_git_get_origin_branch(a:spec)
  return ['git', 'checkout', '-q', a:spec.branch, '--']
endfunction

" s:compackd_git_get_dir(dir) abort : return a valid .git directory path
function! s:compackd_git_get_dir(dir) abort
  call s:diagnostic("function! s:compackd_git_get_dir(" . string(a:dir) . ") abort", 61)

  let git_dir = s:compackd_get_trim(a:dir) . '/.git'

  if isdirectory(git_dir)
    return git_dir
  endif

  if !filereadable(git_dir)
    return ''
  endif

  " FIXME: what is this logic doing, and why??
  " what is the purpose of sending ^gitdir:/some/path/ ?? to explicitly specify the .git directory?
  let git_dir = matchstr(get(readfile(git_dir), 0, ''), '^gitdir: \zs.*')

  if len(git_dir) && !s:compackd_is_absolute_path(git_dir)
    let git_dir = a:dir . '/' . git_dir
  endif

  return isdirectory(git_dir) ? git_dir : ''
endfunction

" s:compackd_git_get_line_format(line) : return a reformatted version of git log ... --pretty=format:%x01%h%x01%d%x01%s%x01%cr
function! s:compackd_git_get_line_format(line)
  call s:diagnostic("function! s:compackd_git_get_line_format(" . string(a:line) . ")", 61)

  let indent = '  '
  let tokens = split(a:line, nr2char(1))
  if len(tokens) != 5
    return indent.substitute(a:line, '\s*$', '', '')
  endif
  let [graph, sha, refs, subject, date] = tokens
  let tag = matchstr(refs, 'tag: [^,)]\+')
  let tag = empty(tag) ? ' ' : ' ('.tag.') '
  return printf('%s%s%s%s%s (%s)', indent, graph, sha, tag, subject, date)
endfunction

" s:compackd_git_get_merge_command(spec) : return a list of the git merge arguments for a spec
function! s:compackd_git_get_merge_command(spec)
  call s:diagnostic("function! s:compackd_git_get_merge_command(" . string(a:spec) . ")", 61)

  let a:spec.branch = s:compackd_git_get_origin_branch(a:spec)
  return ['git', 'merge', '--ff-only', 'origin/'.a:spec.branch]
endfunction

" s:compackd_git_get_option_progress(boolean) : return the git --progress argument for git 1.7.1+ (or nothing)
function! s:compackd_git_get_option_progress(base)
  call s:diagnostic("function! s:compackd_git_get_option_progress(" . string(a:base) . ")", 61)

  return a:base && !s:compackd_is_win && s:compackd_git_is_minimum_version(1, 7, 1) ? '--progress' : ''
endfunction

" s:compackd_git_get_origin_branch(spec) : return the git origin branch name for a spec
function! s:compackd_git_get_origin_branch(spec)
  call s:diagnostic("function! s:compackd_git_get_origin_branch(" . string(a:spec) . ")", 61)

  if len(a:spec.branch)
    return a:spec.branch
  endif

  " if this is a local repository then this file may not be present
  let git_dir = s:compackd_git_get_dir(a:spec.package_dir)
  let origin_head = git_dir.'/refs/remotes/origin/HEAD'
  if len(git_dir) && filereadable(origin_head)
    return matchstr(get(readfile(origin_head), 0, ''),
          \ '^ref: refs/remotes/origin/\zs.*')
  endif

  " this command may not return the name of a branch in detached HEAD state
  let result = s:compackd_get_lines(s:compackd_exec_cd('git symbolic-ref --short HEAD', a:spec.package_dir))
  return v:shell_error ? '' : result[-1]
endfunction

" s:compackd_git_get_origin_url(dir) abort : return the git origin url from a git directory
function! s:compackd_git_get_origin_url(dir) abort
  call s:diagnostic("function! s:compackd_git_get_origin_url(" . string(a:dir) . ") abort", 61)

  let git_dir = s:compackd_git_get_dir(a:dir)
  let config = git_dir . '/config'
  if empty(git_dir) || !filereadable(config)
    return ''
  endif
  return matchstr(join(readfile(config)), '\[remote "origin"\].\{-}url\s*=\s*\zs\S*\ze')
endfunction

" s:compackd_git_get_revision(dir) abort : return the (matching) HEAD ref: hash (revision) of a git directory
function! s:compackd_git_get_revision(dir) abort
  call s:diagnostic("function! s:compackd_git_get_revision(" . string(a:dir) . ") abort", 61)

  let git_dir = s:compackd_git_get_dir(a:dir)
  let head = git_dir . '/HEAD'
  if empty(git_dir) || !filereadable(head)
    return ''
  endif

  let line = get(readfile(head), 0, '')
  let ref = matchstr(line, '^ref: \zs.*')
  if empty(ref)
    return line
  endif

  if filereadable(git_dir . '/' . ref)
    return get(readfile(git_dir . '/' . ref), 0, '')
  endif

  if filereadable(git_dir . '/packed-refs')
    for line in readfile(git_dir . '/packed-refs')
      if line =~# ' ' . ref
        return matchstr(line, '^[0-9a-f]*')
      endif
    endfor
  endif

  return ''
endfunction

" s:compackd_git_get_uri(remote, uri) : return a remote if it matches all or part of an uri
function! s:compackd_git_get_uri(remote, uri)
  call s:diagnostic("function! s:compackd_git_get_uri(" . string(a:remote) . ", " . string(a:uri) . ")", 61)

  " See `git help clone'
  " https:// [user@] github.com[:port] / josephtingiris/compackd [.git]
  "          [git@]  github.com[:port] : josephtingiris/compackd [.git]
  " file://                            / josephtingiris/compackd        [/]
  "                                    / josephtingiris/compackd        [/]

  let pattern = '^\%(\w\+://\)\='.'\%([^@/]*@\)\='.'\([^:/]*\%(:[0-9]*\)\=\)'.'[:/]'.'\(.\{-}\)'.'\%(\.git\)\=/\?$'
  let match_remote = matchlist(a:remote, pattern)
  let match_uri = matchlist(a:uri, pattern)
  return match_remote[1:2] ==# match_uri[1:2]
endfunction

" s:compackd_git_is_credential_helper_disabled() : return true if git credential.helper is disabled via its global variable
function! s:compackd_git_is_credential_helper_disabled()
  call s:diagnostic("function! s:compackd_git_is_credential_helper_disabled()", 81)

  return s:compackd_git_is_minimum_version(2) && get(g:, 'pack_disable_credential_helper', 1)
endfunction

" s:compackd_git_is_minimum_version(...) : return true if git meets the minimum version requirement
function! s:compackd_git_is_minimum_version(...)
  call s:diagnostic("function! s:compackd_git_is_minimum_version(" . string(a:000) . ")", 81)

  if !exists('s:compackd_git_version')
    let s:compackd_git_version = map(split(split(s:compackd_exec_cd(['git', '--version']))[2], '\.'), 'str2nr(v:val)')
  endif

  return s:compackd_is_version(s:compackd_git_version, a:000)
endfunction

" s:compackd_git_reset() : git reset a package via compackd_PackDiff
function! s:compackd_git_reset()
  call s:diagnostic("function! s:compackd_git_reset()", 13)

  if search('^Pending updates', 'bnW')
    return
  endif

  let name = s:compackd_tab_get_package_name_from_line(line('.'))
  if empty(name) || !has_key(g:compackd_specs, name) ||
        \ input(printf('Revert the update of %s? (y/N) ', name)) !~? '^y'
    return
  endif

  call s:system('git reset --hard HEAD@{1} && git checkout ' . s:compackd_get_escape_shell_args(g:compackd_specs[name].branch) . ' --', g:compackd_specs[name].dir)
  setlocal modifiable
  normal! "_dap
  setlocal nomodifiable
  echo 'Reverted'
endfunction

" s:compackd_git_validate(spec, check_branch) : validate a spec has a git package_dir that has not diverged from its remote
function! s:compackd_git_validate(spec, check_branch)
  call s:diagnostic("function! s:compackd_git_validate(" . string(a:spec) . ", " . string(a:check_branch) . ")", 13)

  let err = ''
  if isdirectory(a:spec.package_dir)
    let result = [s:compackd_git_get_branch_or_head(a:spec.package_dir), s:compackd_git_get_origin_url(a:spec.package_dir)]
    let remote = result[-1]
    if empty(remote)
      let err = join([remote, 'PackClean required.'], "\n")
    elseif !s:compackd_git_get_uri(remote, a:spec.uri)
      let err = join(['Invalid URI: '.remote,
            \ 'Expected:    '.a:spec.uri,
            \ 'PackClean required.'], "\n")
    elseif a:check_branch && has_key(a:spec, 'commit')
      let sha = s:compackd_git_get_revision(a:spec.package_dir)
      if empty(sha)
        let err = join(add(result, 'PackClean required.'), "\n")
      elseif !s:compackd_is_match(sha, a:spec.commit)
        let err = join([printf('Invalid HEAD (expected: %s, actual: %s)',
              \ a:spec.commit[:6], sha[:6]),
              \ 'PackUpdate required.'], "\n")
      endif
    elseif a:check_branch
      let current_branch = result[0]
      " Check tag
      let origin_branch = s:compackd_git_get_origin_branch(a:spec)
      if has_key(a:spec, 'tag')
        let tag = s:compackd_exec_cd_trim_newlines('git describe --exact-match --tags HEAD 2>&1', a:spec.package_dir)
        if a:spec.tag !=# tag && a:spec.tag !~ '\*'
          let err = printf('Invalid tag: %s (expected: %s). Try PackUpdate.',
                \ (empty(tag) ? 'N/A' : tag), a:spec.tag)
        endif
        " Check branch
      elseif origin_branch !=# current_branch
        let err = printf('Invalid branch: %s (expected: %s). Try PackUpdate.',
              \ current_branch, origin_branch)
      endif
      if empty(err)
        let ahead_behind = split(s:compackd_get_lines_last(s:compackd_exec_cd([
              \ 'git', 'rev-list', '--count', '--left-right',
              \ printf('HEAD...origin/%s', origin_branch)
              \ ], a:spec.package_dir)), '\t')
        if v:shell_error || len(ahead_behind) != 2
          let err = "Failed to compare with the origin. The default branch might have changed.\nPackClean required."
        else
          let [ahead, behind] = ahead_behind
          if ahead && behind
            " Only mention PackClean if diverged, otherwise it's likely to be pushable (and probably not that messed up).
            let err = printf(
                  \ "Diverged from origin/%s (%d commit(s) ahead and %d commit(s) behind!\n"
                  \ .'Backup local changes and run PackClean and PackUpdate to reinstall it.', origin_branch, ahead, behind)
          elseif ahead
            let err = printf("Ahead of origin/%s by %d commit(s).\n"
                  \ .'Cannot update until local changes are pushed.',
                  \ origin_branch, ahead)
          endif
        endif
      endif
    endif
  else
    let err = 'Not found'
  endif
  return [err, err =~# 'PackClean']
endfunction

"
" script-local : compackd_ is functions
"

" s:compackd_is_absolute_path() : return true if a path is an absolute path
function! s:compackd_is_absolute_path(path) abort
  call s:diagnostic("function! s:compackd_is_absolute_path(" . string(a:path) . ") abort", 81)

  return a:path =~# '^/' || (s:compackd_is_win && a:path =~? '^\%(\\\|[A-Z]:\)')
endfunction

" s:compackd_is_match(str1, str2) : return true if two strings match
function! s:compackd_is_match(str1, str2)
  call s:diagnostic("function! s:compackd_is_match(" . string(a:str1) . ", " . string(a:str2) . ")", 81)

  return stridx(a:str1, a:str2) == 0 || stridx(a:str2, a:str1) == 0
endfunction

" s:compackd_is_powershell(shell) : return true if the shell is powershell
function! s:compackd_is_powershell(shell)
  call s:diagnostic("function! s:compackd_is_powershell(" . string(a:shell) . ")", 81)

  return a:shell =~# 'powershell\(\.exe\)\?$' || a:shell =~# 'pwsh\(\.exe\)\?$'
endfunction

" s:compackd_is_preview_window_open() : return true if a preview window is open
function! s:compackd_is_preview_window_open()
  call s:diagnostic("function! s:compackd_is_preview_window_open()", 81)

  silent! wincmd P
  if &previewwindow
    wincmd p
    return 1
  endif
endfunction

" s:compackd_is_version(list1, list2) : return true if list1 meets the minimum version requirement of list2
function! s:compackd_is_version(list1, list2)
  call s:diagnostic("function! s:compackd_is_version(" . string(a:list1) . ", " . string(a:list2) . ")", 81)

  for idx in range(0, len(a:list2) - 1)
    let v = get(a:list1, idx, 0)
    if     v < a:list2[idx] | return 0
    elseif v > a:list2[idx] | return 1
    endif
  endfor

  return 1
endfunction

"
" script-local : compackd_ job functions
"

" s:compackd_job(name, spec, queue, opts) : start a job (thread) to setup (install or upgrade) a spec
function! s:compackd_job(name, spec, queue, opts)
  call s:diagnostic("function! s:compackd_job(" . string(a:name) . ", " . string(a:spec) . ", " . string(a:queue) . ", " . string(a:opts) .")", 21)

  let job = { 'name': a:name, 'spec': a:spec, 'running': 1, 'error': 0, 'lines': [''],
        \ 'installed': get(a:opts, 'installed', 0), 'queue': copy(a:queue) }

  let Item = remove(job.queue, 0)
  let argv = type(Item) == s:compackd_type.funcref ? call(Item, [a:spec]) : Item

  let s:compackd_jobs[a:name] = job

  if s:compackd_is_nvim
    " nvim calls it 'jobstart'
    if has_key(a:opts, 'package_dir')
      let job.cwd = a:opts.package_dir
    endif

    call extend(job, {
          \ 'on_stdout': function('s:compackd_job_callback_nvim'),
          \ 'on_stderr': function('s:compackd_job_callback_nvim'),
          \ 'on_exit': function('s:compackd_job_callback_nvim'),
          \ })

    let jid = s:compackd_os_call('jobstart', argv, job)
    if jid > 0
      let job.jobid = jid
    else
      let job.running = 0
      let job.error   = 1
      let job.lines   = [jid < 0 ? argv[0].' is not executable' :
            \ 'Invalid arguments (or job table is full)']
    endif
  elseif s:compackd_is_vim
    " vim calls it 'job_start'
    let cmd = join(map(copy(argv), 's:compackd_get_escape_shell_args(v:val, {"script": 0})'))
    if has_key(a:opts, 'package_dir')
      let cmd = s:compackd_get_cd_with_command(cmd, a:opts.package_dir, 0)
    endif

    let argv = s:compackd_is_win ? ['cmd', '/s', '/c', '"'.cmd.'"'] : ['sh', '-c', cmd]

    let jid = job_start(s:compackd_is_win ? join(argv, ' ') : argv, {
          \ 'out_callback': function('s:compackd_job_callback', ['s:compackd_job_callback_out',  job]),
          \ 'err_callback': function('s:compackd_job_callback', ['s:compackd_job_callback_out',  job]),
          \ 'exit_callback': function('s:compackd_job_callback', ['s:compackd_job_callback_exit', job]),
          \ 'err_mode': 'raw',
          \ 'out_mode': 'raw'
          \})

    if job_status(jid) == 'run'
      let job.jobid = jid
    else
      let job.running = 0
      let job.error = 1
      let job.lines = ['Failed to start job']
    endif
  else
    let job.lines = s:compackd_get_lines(call('s:compackd_exec_cd', has_key(a:opts, 'package_dir') ? [argv, a:opts.package_dir] : [argv]))
    let job.error = v:shell_error != 0
    let job.running = 0
  endif
endfunction

" s:compackd_job_abort(cancel) : abort a job
function! s:compackd_job_abort(cancel)
  call s:diagnostic("function! s:compackd_job_abort(" . string(a:cancel) . ")", 21)

  if (!s:compackd_is_nvim && !s:compackd_is_vim) || !exists('s:compackd_jobs')
    return
  endif

  for [name, job] in items(s:compackd_jobs)
    if s:compackd_is_nvim
      silent! call jobstop(job.jobid)
    elseif s:compackd_is_vim
      silent! call job_stop(job.jobid)
    endif
    if job.installed
      call s:compackd_do_rm_rf(g:compackd_specs[name].package_dir)
    endif
    if a:cancel
      call s:compackd_job_set_aborted(name, 'Aborted')
    endif
  endfor

  if a:cancel
    for pending in values(s:compackd_setup_status.pending)
      let pending.abort = 1
    endfor
  else
    let s:compackd_jobs = {}
  endif
endfunction

" s:compackd_job_callback(fn, job, ch, data) : call back a (job) function with a data dictionary (for a job id)
function! s:compackd_job_callback(fn, job, ch, data)
  call s:diagnostic("function! s:compackd_job_callback(" . string(a:fn) . ", " . string(a:job) . ", " . string(a:ch) . ", " . string(a:data) . ")", 21)

  if !s:compackd_tab_is_open()
    return s:compackd_job_abort(0)
  endif

  call call(a:fn, [a:job, a:data])
endfunction

" s:compackd_job_callback_exit(self, data) abort : when a job exits, reap its (self) dictionary and call (run) the next job
function! s:compackd_job_callback_exit(self, data) abort
  call s:diagnostic("function! s:compackd_job_callback_exit(" . string(a:self) . ", " . string(a:data) . ") abort", 21)

  let a:self.running = 0
  let a:self.error = a:data != 0

  call s:compackd_job_reap(a:self.name)
  call s:compackd_job_runner()
endfunction

" s:compackd_job_callback_nvim(job_id, data, event) dict abort : an nvim wrapper for s:compackd_job_callback
function! s:compackd_job_callback_nvim(job_id, data, event) dict abort
  call s:diagnostic("function! s:compackd_job_callback_nvim(" . string(a:job_id) . ", " . string(a:data) . ", " . string(a:event) . ") dict abort", 21)

  return (a:event == 'stdout' || a:event == 'stderr') ?
        \ s:compackd_job_callback('s:compackd_job_callback_out',  self, 0, join(a:data, "\n")) :
        \ s:compackd_job_callback('s:compackd_job_callback_exit', self, 0, a:data)
endfunction

" s:compackd_job_callback_out(self, data) abort : when a job is running, remove it from the data dictionary and append the job output to its (self) dictionary
function! s:compackd_job_callback_out(self, data) abort
  call s:diagnostic("function! s:compackd_job_callback_out(" . string(a:self) . ", " . string(a:data) . ") abort", 21)

  let self = a:self
  let data = remove(self.lines, -1) . a:data
  let lines = map(split(data, "\n", 1), 'split(v:val, "\r", 1)[-1]')

  call extend(self.lines, lines)

  " To reduce the number of buffer updates
  let self.tick = get(self, 'tick', -1) + 1

  if !self.running || self.tick % len(s:compackd_jobs) == 0
    let result = self.error ? join(self.lines, "\n") : s:compackd_get_lines_last_not_empty(self.lines)
    if len(result)
      call s:compackd_tab_append_line(s:compackd_tab_get_formatted_job_bullet(self), self.name, result)
    endif
  endif
endfunction

" s:compackd_job_reap(name) : remove a concluded job from the job queue and update the progress status
function! s:compackd_job_reap(name)
  call s:diagnostic("function! s:compackd_job_reap(" . string(a:name) . ")", 21)

  let job = remove(s:compackd_jobs, a:name)

  if job.error
    call add(s:compackd_setup_status.errors, a:name)
  elseif get(job, 'installed', 0)
    let s:compackd_setup_status.installed[a:name] = 1
  endif

  let more = len(get(job, 'queue', []))
  let result = job.error ? join(job.lines, "\n") : s:compackd_get_lines_last_not_empty(job.lines)

  if len(result)
    call s:compackd_tab_append_line(s:compackd_tab_get_formatted_job_bullet(job), a:name, result)
  endif

  if !job.error && more
    let job.spec.queue = job.queue
    let s:compackd_setup_status.pending[a:name] = job.spec
  else
    let s:compackd_setup_status.progress_bar .= s:compackd_tab_get_formatted_job_bullet(job, '=')

    call s:compackd_tab_set_status()
  endif
endfunction

" s:compackd_job_runner() : run the next job in the (s:compackd_jobs) dictionary
function! s:compackd_job_runner()
  echo s:diagnostic("function! s:compackd_job_runner()", 21)

  let pull = s:compackd_setup_status.pull

  let progress_option = s:compackd_git_get_option_progress(s:compackd_is_nvim || s:compackd_is_vim)

  " FIXME: there should be max limit on this loop
  while 1
    if empty(s:compackd_setup_status.pending)
      if empty(s:compackd_jobs) && !s:compackd_setup_status.concluded
        call s:compackd_package_setup_conclude()

        let s:compackd_setup_status.concluded = 1
      endif
      return
    endif

    let name = keys(s:compackd_setup_status.pending)[0]
    let spec = remove(s:compackd_setup_status.pending, name)

    if get(spec, 'abort', 0)
      call s:compackd_job_set_aborted(name, 'Skipped')
      call s:compackd_job_reap(name)
      continue
    endif

    let queue = get(spec, 'queue', [])
    let installed = empty(globpath(spec.package_dir, '.git', 1))

    if empty(queue)
      call s:compackd_tab_append_line(installed ? '+' : '*', name, pull ? 'Updating ...' : 'Installing ...')
    endif

    let has_tag = has_key(spec, 'tag')

    if len(queue)
      call s:compackd_job(name, spec, queue, { 'package_dir': spec.package_dir })
    elseif !installed
      let [error, _] = s:compackd_git_validate(spec, 0)
      if empty(error)
        if pull
          let cmd = s:compackd_git_is_credential_helper_disabled() ? ['git', '-c', 'credential.helper=', 'fetch'] : ['git', 'fetch']
          if has_tag && !empty(globpath(spec.package_dir, '.git/shallow'))
            call extend(cmd, ['--depth', '99999999'])
          endif
          if !empty(progress_option)
            call add(cmd, progress_option)
          endif
          let queue = [cmd, split('git remote set-head origin -a')]
          if !has_tag && !has_key(spec, 'commit')
            call extend(queue, [function('s:compackd_git_get_checkout_command'), function('s:compackd_git_get_merge_command')])
          endif
          call s:compackd_job(name, spec, queue, { 'package_dir': spec.package_dir })
        else
          let s:compackd_jobs[name] = { 'running': 0, 'lines': ['Already installed.'], 'error': 0 }
        endif
      else
        let s:compackd_jobs[name] = { 'running': 0, 'lines': s:compackd_get_lines(error), 'error': 1 }
      endif
    else
      let cmd = ['git', 'clone']
      if !has_tag
        call extend(cmd, s:clone_opt)
      endif
      if !empty(progress_option)
        call add(cmd, progress_option)
      endif
      call s:compackd_job(name, spec, [extend(cmd, [spec.uri, s:compackd_get_trim(spec.package_dir)]), function('s:compackd_git_get_checkout_command'), function('s:compackd_git_get_merge_command')], { 'installed': 1 })
    endif

    if !s:compackd_jobs[name].running
      call s:compackd_job_reap(name)
    endif

    if len(s:compackd_jobs) >= s:compackd_setup_status.threads
      break
    endif
  endwhile
endfunction

" s:compackd_job_set_aborted(name, str) : set attributes for an aborted job
function! s:compackd_job_set_aborted(name, str)
  call s:diagnostic("function! s:compackd_job_set_aborted(" . string(a:name) . ", " . string(a:str) . ")", 21)

  let attrs = { 'running': 0, 'error': 1, 'abort': 1, 'lines': [a:str] }
  let s:compackd_jobs[a:name] = extend(get(s:compackd_jobs, a:name, {}), attrs)
endfunction

"
" script-local : compackd_ os functions
"

" s:compackd_os_call() : call a function with a forward or back slash
function! s:compackd_os_call(fn, ...)
  call s:diagnostic("function! s:compackd_os_call(" . string(a:fn) . ", " . string(a:000) . ")", 9)

  if s:compackd_is_win
    let shellslash = &shellslash
    try
      set noshellslash
      return call(a:fn, a:000)
    finally
      let &shellslash = shellslash
    endtry
  else
    return call(a:fn, a:000)
  endif
endfunction

" s:compackd_os_do_batchfile(cmd) : on windows, write a series of commands to a batch file and execute it
function! s:compackd_os_do_batchfile(cmd)
  call s:diagnostic("function! s:compackd_os_do_batchfile(cmd)", 41)

  if s:compackd_is_win
    let batchfile = s:compackd_get_tempname().'.bat'
    call writefile(s:compackd_os_map_cmds(a:cmd), batchfile)
    let cmd = s:compackd_get_escape_shell_args(batchfile, {'shell': &shell, 'script': 0})
    if s:compackd_is_powershell(&shell)
      let cmd = '& ' . cmd
    endif
    return [batchfile, cmd]
  endif
endfunction

" s:compackd_os_map_cmds(cmds) : on windows, map commands via iconv
function! s:compackd_os_map_cmds(cmds)
  call s:diagnostic("function! s:compackd_os_map_cmds(" . string(a:cmds) . ")", 9)

  if s:compackd_is_win
    let cmds = [
          \ '@echo off',
          \ 'setlocal enabledelayedexpansion']
          \ + (type(a:cmds) == type([]) ? a:cmds : [a:cmds])
          \ + ['endlocal']
    if has('iconv')
      if !exists('s:codepage')
        let s:codepage = libcallnr('kernel32.dll', 'GetACP', 0)
      endif
      return map(cmds, printf('iconv(v:val."\r", "%s", "cp%d")', &encoding, s:codepage))
    endif
    return map(cmds, 'v:val."\r"')
  endif
endfunction

" s:compackd_os_set_shell(swap) : conditiaonlly set the shell options based on the operating system
function! s:compackd_os_set_shell(swap)
  call s:diagnostic("function! s:compackd_os_set_shell(" . string(a:swap) . ")", 9)

  let prev = [&shell, &shellcmdflag, &shellredir]

  if !s:compackd_is_win
    set shell=sh
  endif

  if a:swap
    if s:compackd_is_powershell(&shell)
      let &shellredir = '2>&1 | Out-File -Encoding UTF8 %s'
    elseif &shell =~# 'sh' || &shell =~# 'cmd\(\.exe\)\?$'
      set shellredir=>%s\ 2>&1
    endif
  endif

  return prev
endfunction

"
" script-local : compackd_ package functions
"

" s:compackd_package_add(name) : add a package to the rtp and source its autoload/*, plugin/*, etc. (:help packadd)
function! s:compackd_package_add(name, ...)
  call s:diagnostic("function! s:compackd_package_add(" . string(a:name) . ", " . string(a:000) . ")", 11)

  let force = empty(a:000) ? 0 : a:1
  let loaded = 0

  if !empty(g:compackd_specs[a:name])
    let spec=g:compackd_specs[a:name]
    if isdirectory(spec.package_dir)
      "call s:diagnostic("function! s:compackd_package_add(" . string(a:name) . ") : found " . string(a:name) . " directory = " . spec.package_dir, 20)

      if  !s:compackd_spec_do_option(spec, 'lazy_functions') && !s:compackd_spec_do_option(spec, 'lazy_filetypes')
        execute 'packadd' a:name
        let loaded = 1
      else
        if force
          call s:diagnostic("function! s:compackd_package_add(" .  string(a:name) . ") : should be lazy, but is being force loaded", 33)
          execute 'packadd' a:name
          let loaded = 1
        else
          call s:diagnostic("function! s:compackd_package_add(" .  string(a:name) . ") : will be lazy loaded", 33)
          let loaded = 0
        endif
      endif
    endif
  endif

  let g:compackd_specs[a:name].packadd = loaded

  return loaded
endfunction

" s:compackd_package_add_all() : add all qualifying packages to the rtp and source their autoload/*, plugin/*, etc. (TODO: WIP)
function! s:compackd_package_add_all()
  call s:diagnostic("function! s:compackd_package_add_all()", 11)

  for name in keys(g:compackd_specs)
    call s:compackd_package_add(name)
  endfor
endfunction

" s:compackd_package_add_lazy_filetypes(name, spec, opt) : add autocmds for lazy loading a package
function! s:compackd_package_add_lazy_filetypes(name, spec, opt)
  call s:diagnostic("function! s:compackd_package_add_lazy_filetypes(" . string(a:name) . ", " . string(a:spec) . ", " . string(a:opt) . ")", 11)

  if a:opt == 'lazy_filetypes'
    let name_substitute = a:name

    " substitute (valid url) characters that are invalid in a function name
    for sub in [ "-", "\\.", "\\~", ":", "/", "?", "#", "[", "]", "@", "!", "\\$", "&", "'", "(", ")", "*", "+", ",", ";", "%", "=" ]
      let name_substitute = substitute(name_substitute, sub, '_', 'g')
    endfor

    for ft in s:compackd_type_is_list(a:spec[a:opt])
      call s:diagnostic("function! s:compackd_package_add_lazy_filetypes(" . string(a:name) . ", " . string(a:spec) . ", " . string(a:opt) . ") - name = " . a:name . ", name_substitute = " . name_substitute . ", ft = " . ft, 20)

      let lazy_filetypes_function = "PackLazyFileType_" . name_substitute . "_" . ft

      " create the function that lazy loads the package & deletes the augroup
      execute printf("function! %s()\npackadd %s\nlet g:compackd_specs['%s'].packadd=1\nsilent! augroup! %s\nendfunction", lazy_filetypes_function, a:name, a:name, lazy_filetypes_function)

      " create an augroup for the autocmd
      execute printf("augroup %s\nautocmd!", lazy_filetypes_function)
      " call the function that lazy loads the package & deletes this augroup, then delete the function
      execute printf("autocmd FileType %s execute ':call %s()' | :delfunction %s", ft, lazy_filetypes_function, lazy_filetypes_function)
      execute printf("augroup end")
    endfor
  endif

endfunction

" s:compackd_package_add_lazy_functions(name, spec, opt) : add commands for lazy loading a package
function! s:compackd_package_add_lazy_functions(name, spec, opt)
  call s:diagnostic("function! s:compackd_package_add_lazy_functions(" . string(a:name) . ", " . string(a:spec) . ", " . string(a:opt) . ")", 11)

  if a:opt == 'lazy_functions'
    for cmd in s:compackd_type_is_list(a:spec[a:opt])
      if cmd =~# '^[A-Z]'
        let cmd = substitute(cmd, '!*$', '', '')
        if !exists(":" . cmd)
          " create a command that lazy loads the package by the function name
          execute printf("command! -nargs=* %s execute ':packadd %s' | :let g:compackd_specs['%s'].packadd=1 | :execute ':%s <args>'", cmd, a:name, a:name, cmd)
        endif
      else
        call s:echo_err('ERROR: ' . a:name . ' ' . a:opt . ' option: "' . cmd . '" should start with an uppercase letter.')
      endif
    endfor
  endif
endfunction

" s:compackd_package_delete(range, force) - delete a package directory via compackd_PackClean
function! s:compackd_package_delete(range, force)
  call s:diagnostic("function! s:compackd_package_delete(" . string(a:range) . ", " . string(a:force) . ")", 11)

  let [l1, l2] = a:range
  let force = a:force
  let err_count = 0
  while l1 <= l2
    let line = getline(l1)
    if line =~ '^- ' && isdirectory(line[2:])
      execute l1
      redraw!
      let answer = force ? 1 : s:compackd_tab_ask('Delete '.line[2:].'?', 1)
      let force = force || answer > 1
      if answer
        let err = s:compackd_do_rm_rf(line[2:])
        setlocal modifiable
        if empty(err)
          call setline(l1, '~'.line[1:])
          let s:clean_count += 1
        else
          delete _
          call append(l1 - 1, s:compackd_tab_get_formatted_line('x', line[1:], err))
          let l2 += len(s:compackd_get_lines(err))
          let err_count += 1
        endif
        let msg = printf('Removed %d directories.', s:clean_count)
        if err_count > 0
          let msg .= printf(' Failed to remove %d directories.', err_count)
        endif
        call setline(4, msg)
        setlocal nomodifiable
      endif
    endif
    let l1 += 1
  endwhile
endfunction

" s:compackd_package_delete_opfunc(type, ...) : g@ operator function for compackd_PackClean
function! s:compackd_package_delete_opfunc(type, ...)
  echo s:diagnostic("function! s:compackd_package_delete_opfunc(" . string(a:type) . ", " . string(a:000) . "...)", 11)

  call s:compackd_package_delete(a:0 ? [line("'<"), line("'>")] : [line("'["), line("']")], 0)
endfunction

" s:compackd_package_do_option_post_update(pull, force, pending) : run post_update function
function! s:compackd_package_do_option_post_update(pull, force, pending)
  call s:diagnostic("function! s:compackd_package_do_option_post_update(" . string(a:pull) . ", " . string(a:force) . ", " . string(a:pending) . ")", 41)

  for [name, spec] in items(a:pending)
    if !isdirectory(spec.package_dir)
      continue
    endif
    let installed = has_key(s:compackd_setup_status.installed, name)
    let updated = installed ? 0 : (a:pull && index(s:compackd_setup_status.errors, name) < 0 && s:compackd_spec_is_up_to_date(spec.package_dir))
    if a:force || installed || updated
      execute 'cd' s:compackd_get_escape_space(spec.package_dir)
      call append(3, '- Post-update hook for '. name .' ... ')
      let error = ''
      let type = type(spec.post_update)
      if type == s:compackd_type.string
        if spec.post_update[0] == ':'
          call s:compackd_package_add(name)
          try
            execute spec.post_update[1:]
          catch
            let error = v:exception
          endtry
          if !s:compackd_tab_is_open() " s:compackd_tabpagenr
            cd -
            throw 'Warning: compackd was terminated by the post-update hook of '.name
          endif
        else
          let error = s:compackd_exec_bang(spec.post_update)
        endif
      elseif type == s:compackd_type.funcref
        try
          call s:compackd_package_add(name)
          let status = installed ? 'installed' : (updated ? 'updated' : 'unchanged')
          call spec.post_update({ 'name': name, 'status': status, 'force': a:force })
        catch
          let error = v:exception
        endtry
      else
        let error = 'Invalid hook type'
      endif
      call s:compackd_tab_switch()
      call setline(4, empty(error) ? (getline(4) . 'OK')
            \ : ('x' . getline(4)[1:] . error))
      if !empty(error)
        call add(s:compackd_setup_status.errors, name)
        call s:compackd_tab_progress_bar_regress()
      endif
      cd -
    endif
  endfor
endfunction

" s:compackd_package_get_name_from_string(str, prefix, suffix) : get the package name from a string
function! s:compackd_package_get_name_from_string(str, prefix, suffix)
  call s:diagnostic("function! s:compackd_package_get_name_from_string(" . string(a:str) . ", " . string(a:prefix) . ", " . string(a:suffix) . ")", 61)

  return matchstr(a:str, '^'.a:prefix.' \zs[^:]\+\ze:.*'.a:suffix.'$')
endfunction

" s:compackd_package_is_local(repo) : return true if a repo (string) is a 'local' package (in a directory)?
function! s:compackd_package_is_local(repo)
  call s:diagnostic("function! s:compackd_package_is_local(" . string(a:repo) . ")", 81)

  if s:compackd_is_win
    return a:repo =~? '^[a-z]:\|^[%~]'
  else
    return a:repo[0] =~ '[/$~]'
  endif
endfunction

" s:compackd_package_setup(pull, force, args) abort : setup (install and/or update) a package
function! s:compackd_package_setup(pull, force, args) abort
  call s:diagnostic("function! s:compackd_package_setup(" . string(a:pull) . ", " . string(a:force) . ", " . string(a:args) . ") abort", 11)

  let sync = index(a:args, '--sync') >= 0 || has('vim_starting')
  let args = filter(copy(a:args), 'v:val != "--sync"')
  let threads = (len(args) > 0 && args[-1] =~ '^[1-9][0-9]*$') ? remove(args, -1) : get(g:, 'pack_threads', 16)

  " include all specs with a uri
  let uri_specs = filter(deepcopy(g:compackd_specs), 's:compackd_spec_get_uri(v:key)')

  " include all specs that are not frozen and do not have a package_dir that exists
  let setup_specs = empty(args) ? filter(uri_specs, '!v:val.frozen || !isdirectory(v:val.package_dir)') : filter(uri_specs, 'index(args, v:key) >= 0')

  if empty(setup_specs)
    return s:echo_warn('No package to '. (a:pull ? 'update' : 'install'))
  endif

  if !s:compackd_is_win && s:compackd_git_is_minimum_version(2, 3)
    let s:compackd_git_terminal_prompt = exists('$GIT_TERMINAL_PROMPT') ? $GIT_TERMINAL_PROMPT : ''
    let $GIT_TERMINAL_PROMPT = 0
    for spec in values(setup_specs)
      let spec.uri = substitute(spec.uri, '^https://git::@github\.com', 'https://github.com', '')
    endfor
  endif

  if !isdirectory(g:compackd_packages_dir)
    try
      call mkdir(g:compackd_packages_dir, 'p')
    catch
      return s:echo_err(printf('Unable to mkdir the package directory: %s. '. 'Try to call compackd# with a valid directory', g:compackd_packages_dir))
    endtry
  endif

  if s:compackd_is_nvim && !exists('*jobwait') && threads > 1
    call s:echo_warn('This Neovim does not contain jobwait and cannot execute parallel package installations or updates.')
  endif

  let use_job = 1

  let s:compackd_setup_status = {
        \ 'all': setup_specs,
        \ 'concluded': 0,
        \ 'errors': [],
        \ 'force': a:force,
        \ 'installed': {},
        \ 'pending': copy(setup_specs),
        \ 'progress_bar': '',
        \ 'pull': a:pull,
        \ 'start': reltime(),
        \ 'threads': use_job ? min([len(setup_specs), threads]) : 1
        \ }

  call s:compackd_tab_prepare(1)

  call append(0, ['', ''])
  normal! 2G
  silent! redraw

  " Set remote name, overriding a possible user git config's clone.defaultRemoteName
  let s:clone_opt = ['--origin', 'origin']
  if get(g:, 'pack_shallow', 1)
    call extend(s:clone_opt, ['--depth', '1'])
    if s:compackd_git_is_minimum_version(1, 7, 10)
      call add(s:clone_opt, '--no-single-branch')
    endif
  endif

  if s:compackd_is_wsl
    call extend(s:clone_opt, ['-c', 'core.eol=lf', '-c', 'core.autocrlf=input'])
  endif

  let s:submodule_opt = s:compackd_git_is_minimum_version(2, 8) ? ' --jobs='.threads : ''

  let s:compackd_jobs = {}

  call s:compackd_tab_set_status()

  call s:compackd_job_runner()

  while use_job && sync
    sleep 100m
    if s:compackd_setup_status.concluded
      break
    endif
  endwhile
endfunction

" s:compackd_package_setup_conclude() : conclude a package setup
function! s:compackd_package_setup_conclude()
  call s:diagnostic("function! s:compackd_package_setup_conclude()", 11)

  if exists('s:compackd_git_terminal_prompt')
    let $GIT_TERMINAL_PROMPT = s:compackd_git_terminal_prompt
  endif

  if s:compackd_tab_switch()
    call append(3, '- Updating ...') | 4

    for [name, spec] in items(filter(copy(s:compackd_setup_status.all), 'index(s:compackd_setup_status.errors, v:key) < 0 && (s:compackd_setup_status.force || s:compackd_setup_status.pull || has_key(s:compackd_setup_status.installed, v:key))'))
      let [pos, _] = s:compackd_get_buffer_position(name)
      if !pos
        continue
      endif
      let out = ''
      let error = 0
      if has_key(spec, 'commit')
        call s:compackd_tab_set_line4(name, 'Checking out '.spec.commit)
        let [out, error] = s:compackd_git_checkout(spec)
      elseif has_key(spec, 'tag')
        let tag = spec.tag
        if tag =~ '\*'
          let tags = s:compackd_get_lines(s:compackd_exec_cd('git tag --list '.s:compackd_get_escape_shell_args(tag).' --sort -version:refname 2>&1', spec.package_dir))
          if !v:shell_error && !empty(tags)
            let tag = tags[0]
            call s:compackd_tab_set_line4(name, printf('Latest tag for %s -> %s', spec.tag, tag))
            call append(3, '')
          endif
        endif
        call s:compackd_tab_set_line4(name, 'Checking out '.tag)
        let out = s:compackd_exec_cd('git checkout -q '.s:compackd_get_escape_shell_args(tag).' -- 2>&1', spec.package_dir)
        let error = v:shell_error
      endif
      if !error && filereadable(spec.package_dir.'/.gitmodules') &&
            \ (s:compackd_setup_status.force || has_key(s:compackd_setup_status.installed, name) || s:compackd_spec_is_up_to_date(spec.package_dir))
        call s:compackd_tab_set_line4(name, 'Initializing submodules.')

        let out .= s:compackd_exec_bang('git submodule update --init --recursive'.s:submodule_opt.' 2>&1', spec.package_dir)

        let error = v:shell_error
      endif

      let msg = s:compackd_tab_get_formatted_line(v:shell_error ? 'x': '-', name, out)

      if error
        call add(s:compackd_setup_status.errors, name)
        call s:compackd_tab_progress_bar_regress()
        silent execute pos 'd _'
        call append(4, msg) | 4
      elseif !empty(out)
        call setline(pos, msg[0])
      endif

      redraw
    endfor
    silent 4 d _
    try
      call s:compackd_package_do_option_post_update(s:compackd_setup_status.pull, s:compackd_setup_status.force, filter(copy(s:compackd_setup_status.all), 'index(s:compackd_setup_status.errors, v:key) < 0 && has_key(v:val, "post_update")'))
    catch
      call s:echo_warn(string(v:exception))
      call s:echo_warn('')
      return
    endtry

    let installed_frozen = len(filter(keys(s:compackd_setup_status.installed), 'g:compackd_specs[v:val].frozen'))
    if installed_frozen
      let s = installed_frozen > 1 ? 's' : ''
      call append(3, printf('- Installed %d frozen plugin%s', installed_frozen, s))
    endif

    call append(3, '- Finishing ... ') | 4

    redraw

    call s:compackd_spec_do_helptags()

    call s:compackd_package_add_all()

    call setline(4, getline(4) . 'Done!')
    redraw

    let msgs = []
    if !empty(s:compackd_setup_status.errors)
      call add(msgs, "Press 'R' to retry.")
    endif

    " 'Already up to date.' is what git outputs
    if s:compackd_setup_status.pull && len(s:compackd_setup_status.installed) < len(filter(getline(5, '$'),
          \ "v:val =~ '^- ' && v:val !~# 'Already up.to.date'"))
      call add(msgs, "Press 'D' to see the updated changes.")
    endif
    echo join(msgs, ' ')

    call s:compackd_tab_bindings()

    let line1 = getline(1)
    let line1 = line1 . ' - Elapsed time: ' . split(reltimestr(reltime(s:compackd_setup_status.start)))[0] . ' sec.'
    call setline(1, line1)

    call s:compackd_tab_switch_out('normal! gg')
  endif
endfunction

"
" script-local : compackd_ spec functions
"

" s:compackd_spec_do_bufread_all(names) : doautocmd BufRead for all spec names
function! s:compackd_spec_do_bufread_all(names)
  call s:diagnostic("function! s:compackd_spec_do_bufread_all(names)", 41)

  for name in a:names
    let path = s:compackd_spec_get_plugin_dir(g:compackd_specs[name])
    for dir in ['ftdetect', 'ftplugin', 'after/ftdetect', 'after/ftplugin']
      if len(finddir(dir, path))
        if exists('#BufRead')
          doautocmd BufRead
        endif
        return
      endif
    endfor
  endfor
endfunction

" s:compackd_spec_do_helptags() : execute helptags for all specs with a doc directory
function! s:compackd_spec_do_helptags()
  call s:diagnostic("function! s:compackd_spec_do_helptags()", 41)

  for spec in values(g:compackd_specs)
    let docd = join([s:compackd_spec_get_plugin_dir(spec), 'doc'], '/')
    if isdirectory(docd)
      silent! execute 'helptags' s:compackd_get_escape_space(docd)
    endif
  endfor

  return 1
endfunction

" s:compackd_spec_do_option(spec, opt) : return true if a spec has a specific option, is installed, and has either a plugin and/or after/plugin directory
function! s:compackd_spec_do_option(spec, opt)
  call s:diagnostic("function! s:compackd_spec_do_option(" . string(a:spec) . ", " . string(a:opt) . ")", 41)
  return has_key(a:spec, a:opt) &&
        \ (empty(s:compackd_type_is_list(a:spec[a:opt])) ||
        \  !isdirectory(a:spec.package_dir) ||
        \  len(s:compackd_get_dir_glob(s:compackd_spec_get_plugin_dir(a:spec), 'plugin')) ||
        \  len(s:compackd_get_dir_glob(s:compackd_spec_get_plugin_dir(a:spec), 'after/plugin')))
endfunction

" s:compackd_spec_get_names(...) : return a sorted dict of keys
function! s:compackd_spec_get_names(...)
  call s:diagnostic("function! s:compackd_spec_get_names(" . string(a:000) . ")", 61)

  return sort(filter(keys(g:compackd_specs), 'stridx(v:val, a:1) == 0 && s:compackd_spec_get_uri(v:val)'))
endfunction

" s:compackd_spec_get_options(arg) : return valid spec options
function! s:compackd_spec_get_options(arg)
  call s:diagnostic("function! s:compackd_spec_get_options(" . string(a:arg). ")", 61)

  let opts = copy(s:compackd_spec_default_options)
  let type = type(a:arg)
  let opt_errfmt = 'Invalid argument for "%s" option of :Pack (expected: %s)'
  if type == s:compackd_type.string
    if empty(a:arg)
      throw printf(opt_errfmt, 'tag', 'string')
    endif
    let opts.tag = a:arg
  elseif type == s:compackd_type.dict
    for opt in ['branch', 'tag', 'commit', 'plugin_dir', 'package_dir', 'package_name']
      if has_key(a:arg, opt)
            \ && (type(a:arg[opt]) != s:compackd_type.string || empty(a:arg[opt]))
        throw printf(opt_errfmt, opt, 'string')
      endif
    endfor
    for opt in ['lazy_functions', 'lazy_filetypes']
      if has_key(a:arg, opt)
            \ && type(a:arg[opt]) != s:compackd_type.list
            \ && (type(a:arg[opt]) != s:compackd_type.string || empty(a:arg[opt]))
        throw printf(opt_errfmt, opt, 'string or list')
      endif
    endfor
    if has_key(a:arg, 'post_update')
          \ && type(a:arg.post_update) != s:compackd_type.funcref
          \ && (type(a:arg.post_update) != s:compackd_type.string || empty(a:arg.post_update))
      throw printf(opt_errfmt, 'post_update', 'string or funcref')
    endif
    call extend(opts, a:arg)
    if has_key(opts, 'package_dir')
      let opts.package_dir = s:compackd_get_dir_path(s:compackd_get_expand(opts.package_dir))
    endif
  else
    throw 'Invalid argument type (expected: string or dictionary)'
  endif
  return opts
endfunction

" s:compackd_spec_get_plugin_dir(spec) : return the plugin_dir from a spec
function! s:compackd_spec_get_plugin_dir(spec)
  call s:diagnostic("function! s:compackd_spec_get_plugin_dir(" . string(a:spec) . ")", 61)

  return s:compackd_get_path(a:spec.package_dir . get(a:spec, 'plugin_dir', ''))
endfunction

" s:compackd_spec_get_properties(name, repo) : return spec properties
function! s:compackd_spec_get_properties(name, repo)
  call s:diagnostic("function! s:compackd_spec_get_properties(" . string(a:name) . ", " . string(a:repo) . ")", 61)

  let repo = a:repo
  if s:compackd_package_is_local(repo)
    return { 'package_dir': s:compackd_get_dir_path(s:compackd_get_expand(repo)) }
  else
    if repo =~ ':'
      let uri = repo
    else
      if repo !~ '/'
        throw printf('Invalid argument: %s (implicit `vim-scripts'' expansion is deprecated)', repo)
      endif
      let fmt = get(g:, 'pack_url_format', 'https://git::@github.com/%s.git')
      let uri = printf(fmt, repo)
    endif
    return { 'package_dir': s:compackd_get_dir_path(g:compackd_packages_dir.'/'.a:name), 'uri': uri }
  endif
endfunction

" s:compackd_spec_get_uri(name) : return the spec uri
function! s:compackd_spec_get_uri(name)
  call s:diagnostic("function! s:compackd_spec_get_uri(". string(a:name) . ")", 61)

  return has_key(g:compackd_specs[a:name], 'uri')
endfunction

" s:compackd_spec_is_up_to_date() : return if a git directory is 'up to date'
function! s:compackd_spec_is_up_to_date(dir)
  call s:diagnostic("function! s:compackd_spec_is_up_to_date(" . string(a:dir) . ")", 81)

  return !empty(s:compackd_exec_cd_trim_newlines(['git', 'log', '--pretty=format:%h', 'HEAD...HEAD@{1}'], a:dir))
endfunction

" s:compackd_spec_set_requirements() : set spec requirements
function! s:compackd_spec_set_requirements()
  call s:diagnostic("function! s:compackd_spec_set_requirements()", 11)

  for spec in values(g:compackd_specs)
    let spec.pkgadd = get(spec, 'pkgadd', 0)
    let spec.frozen = get(spec, 'frozen', 0)
  endfor
endfunction

"
" script-local : compackd_ tab functions
"

" s:compackd_tab_append_line(bullet, name, lines) : append a formated line to the compackd tab
function! s:compackd_tab_append_line(bullet, name, lines)
  call s:diagnostic("function! s:compackd_tab_append_line(" . string(a:bullet) . ", " . string(a:name) . ", " . string(a:lines) . ")", 7)

  if s:compackd_tab_switch()
    let [b, e] = s:compackd_get_buffer_position(a:name)
    if b > 0
      silent execute printf('%d,%d d _', b, e)
      if b > winheight('.')
        let b = 4
      endif
    else
      let b = 4
    endif

    " FIXME For some reason, nomodifiable is set after :d in vim
    setlocal modifiable

    call append(b - 1, s:compackd_tab_get_formatted_line(a:bullet, a:name, a:lines))

    call s:compackd_tab_switch_out()
  endif
endfunction

" s:compackd_tab_append_ul(lnum, text) : append an unordered (bulleted) list to the compackd tab
function! s:compackd_tab_append_ul(lnum, text)
  call s:diagnostic("function! s:compackd_tab_append_ul(" . string(a:lnum) . ", " . string(a:text) . ")", 7)

  if s:compackd_tab_switch()
    call append(a:lnum, ['', a:text, repeat('-', len(a:text))])
  endif
endfunction

" s:compackd_tab_ask(str, ...) : ask a question interactively
function! s:compackd_tab_ask(str, ...)
  call s:diagnostic("function! s:compackd_tab_ask(" . string(a:str) . "," .string(a:000) . ")", 7)

  call inputsave()

  echohl WarningMsg
  let answer = input(a:str.(a:0 ? ' (y/N/a) ' : ' (y/N) '))
  echohl None

  call inputrestore()

  echo "\r"
  return (a:0 && answer =~? '^a') ? 2 : (answer =~? '^y') ? 1 : 0
endfunction

" s:compackd_tab_ask_no_interrupt(...) : ask a question interactively without interupting ... ???
function! s:compackd_tab_ask_no_interrupt(...)
  call s:diagnostic("function! s:compackd_tab_ask_no_interrupt(" . string(a:000) . ")", 7)

  try
    return call('s:compackd_tab_ask', a:000)
  catch
    return 0
  endtry
endfunction

" s:compackd_tab_bindings() : set key bindings for the compackd tab
function! s:compackd_tab_bindings()
  call s:diagnostic("function! s:compackd_tab_bindings()", 7)

  nnoremap <silent> <buffer> R  :call <SID>compackd_tab_bindings_retry()<CR>
  nnoremap <silent> <buffer> D  :PackDiff<CR>
  nnoremap <silent> <buffer> S  :PackStatus<CR>
  nnoremap <silent> <buffer> U  :call <SID>compackd_tab_bindings_update()<CR>
  xnoremap <silent> <buffer> U  :call <SID>compackd_tab_bindings_update()<CR>
  nnoremap <silent> <buffer> ]] :silent! call <SID>compackd_tab_bindings_get_section('')<CR>
  nnoremap <silent> <buffer> [[ :silent! call <SID>compackd_tab_bindings_get_section('b')<CR>
endfunction

" s:compackd_tab_bindings_get_section(section) : return the line number for a binding section
function! s:compackd_tab_bindings_get_section(section)
  call s:diagnostic("function! s:compackd_tab_bindings_get_section(" . string(a:section) . ")", 61)

  call search('\(^[x-] \)\@<=[^:]\+:', a:section)
endfunction

" s:compackd_tab_bindings_retry() : retry a failed install via the compackd tab
function! s:compackd_tab_bindings_retry()
  call s:diagnostic("function! s:compackd_tab_bindings_retry()", 7)

  if empty(s:compackd_setup_status.errors)
    return
  endif
  echo
  call s:compackd_package_setup(s:compackd_setup_status.pull, s:compackd_setup_status.force, extend(copy(s:compackd_setup_status.errors), [s:compackd_setup_status.threads]))
endfunction

" s:compackd_tab_bindings_status_load(lnum) : add (load) a package via compackd_PackStatus
function! s:compackd_tab_bindings_status_load(lnum)
  call s:diagnostic("function! s:compackd_tab_bindings_status_load(" . string(a:lnum) . ")", 7)

  let line = getline(a:lnum)
  let name = s:compackd_package_get_name_from_string(line, '-', '(not loaded)')
  if !empty(name)
    call s:compackd_package_add(name, 1)
    setlocal modifiable
    call setline(a:lnum, substitute(line, ' (not loaded)$', '', ''))
    setlocal nomodifiable
  endif
endfunction

" s:compackd_tab_bindings_update() range : update a package via the compackd tab
function! s:compackd_tab_bindings_update() range
  call s:diagnostic("function! s:compackd_tab_bindings_update() range", 7)

  let lines = getline(a:firstline, a:lastline)
  let names = filter(map(lines, 's:compackd_package_get_name_from_string(v:val, "[x-]", "")'), '!empty(v:val)')
  if !empty(names)
    echo
    execute 'PackUpdate' join(names)
  endif
endfunction

" s:compackd_tab_close() : close the compackd tab, abort all jobs, and delete the buffer
function! s:compackd_tab_close()
  call s:diagnostic("function! s:compackd_tab_close()", 7)

  if b:pack_preview == 1
    pclose
    let b:pack_preview = -1
  elseif exists('s:compackd_jobs') && !empty(s:compackd_jobs)
    call s:compackd_job_abort(1)
  else
    bdelete
  endif
endfunction

" s:compackd_tab_get_formatted_job_bullet(job, ...) : return a bullet for compackd formatted lines
function! s:compackd_tab_get_formatted_job_bullet(job, ...)
  call s:diagnostic("function! s:compackd_tab_get_formatted_job_bullet(" . string(a:job) . ", " . string(a:000) . ")", 61)

  if a:job.running
    return a:job.installed ? '+' : '*'
  endif
  if get(a:job, 'abort', 0)
    return '~'
  endif
  return a:job.error ? 'x' : get(a:000, 0, '-')
endfunction

" s:compackd_tab_get_formatted_line(bullet, name, str) : return a formatted line for the compackd tab
function! s:compackd_tab_get_formatted_line(bullet, name, str)
  call s:diagnostic("function! s:compackd_tab_get_formatted_line(" . string(a:bullet) . ", " . string(a:name) . ", " . string(a:str) . ")", 61)

  if a:bullet != 'x'
    return [printf('%s %s: %s', a:bullet, a:name, s:compackd_get_lines_last(a:str))]
  else
    let lines = map(s:compackd_get_lines(a:str), '"    ".v:val')
    return extend([printf('x %s:', a:name)], lines)
  endif
endfunction

" s:compackd_tab_get_package_name_from_line(lnum) : get the package name from a line in the compackd tab
function! s:compackd_tab_get_package_name_from_line(lnum)
  call s:diagnostic("function! s:compackd_tab_get_package_name_from_line(" . string(a:lnum) . ")", 61)

  for lnum in reverse(range(1, a:lnum))
    let line = getline(lnum)
    if empty(line)
      return ''
    endif

    let name = s:compackd_package_get_name_from_string(line, '-', '')
    if !empty(name)
      return name
    endif
  endfor
  return ''
endfunction

" s:compackd_tab_is_open() : return true if the compackd tab is open
function! s:compackd_tab_is_open()
  call s:diagnostic("function! s:compackd_tab_is_open()", 81)

  let l:compackd_tabpagebuflist = tabpagebuflist(s:compackd_tabpagenr)
  return !empty(l:compackd_tabpagebuflist) && index(l:compackd_tabpagebuflist, s:compackd_winbufnr) >= 0
endfunction

" s:compackd_tab_new() : create a new compackd tab
function! s:compackd_tab_new()
  call s:diagnostic("function! s:compackd_tab_new()", 7)

  execute get(g:, 'pack_window', '-tabnew')
endfunction

" s:compackd_tab_prepare(...) : prepare the compackd tab
function! s:compackd_tab_prepare(...)
  call s:diagnostic("function! s:compackd_tab_prepare(" . string(a:000) . ")", 7)

  if empty(s:compackd_get_cwd())
    throw 'Invalid current working directory. Cannot proceed.'
  endif

  for evar in ['$GIT_DIR', '$GIT_WORK_TREE']
    if exists(evar)
      throw evar.' detected. Cannot proceed.'
    endif
  endfor

  call s:compackd_job_abort(0)

  if s:compackd_tab_switch()
    if b:pack_preview == 1
      pclose
    endif
    enew
  else
    call s:compackd_tab_new()
  endif

  nnoremap <silent> <buffer> q :call <SID>compackd_tab_close()<CR>

  if a:0 == 0
    call s:compackd_tab_bindings()
  endif

  let b:pack_preview = -1
  let s:compackd_tabpagenr = tabpagenr()
  let s:compackd_winbufnr = winbufnr(0)

  call s:compackd_tab_set_name("[compactd]")

  for k in ['<CR>', 'L', 'o', 'X', 'd', 'dd']
    execute 'silent! unmap <buffer>' k
  endfor

  setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap cursorline modifiable nospell
  if exists('+colorcolumn')
    setlocal colorcolumn=
  endif
  setf compackd
  if exists('g:syntax_on')
    call s:compackd_tab_syntax()
  endif
endfunction

" s:compackd_tab_progress_bar(line, bar, total) : update the progress bar on the compackd tab
function! s:compackd_tab_progress_bar(line, bar, total)
  call s:diagnostic("function! s:compackd_tab_progress_bar(" . string(a:line) . ", " . string(a:bar) . ", " . string(a:total) . ")", 7)

  call setline(a:line, '[' . s:compackd_get_pad_left(a:bar, a:total) . ']')
endfunction

" s:compackd_tab_progress_bar_regress() : regress the progress bar on the compackd tab
function! s:compackd_tab_progress_bar_regress()
  call s:diagnostic("function! s:compackd_tab_progress_bar_regress()", 7)

  let bar = substitute(getline(2)[1:-2], '.*\zs=', 'x', '')
  call s:compackd_tab_progress_bar(2, bar, len(bar))
endfunction

" s:compackd_tab_set_line4(name, str) : set line 4 of the compackd tab
function! s:compackd_tab_set_line4(name, str)
  call s:diagnostic("function! s:compackd_tab_set_line4(" . string(a:name) . ", " . string(a:str) . ")", 7)

  call setline(4, printf('- %s (%s)', a:str, a:name))
  redraw
endfunction

" s:compackd_tab_set_name(tab_name) : set the compackd tab name
function! s:compackd_tab_set_name(tab_name)
  call s:diagnostic("function! s:compackd_tab_set_name(" . string(a:tab_name) . ")", 7)

  let prefix = a:tab_name
  let prefix_printf = prefix
  let tab_index = 2
  while bufexists(prefix)
    let prefix_printf = printf('%s (%s)', prefix, tab_index)
    let tab_index = tab_index + 1
  endwhile
  silent! execute 'f' fnameescape(prefix_printf)
endfunction

" s:compackd_tab_set_status() : update the status on the compackd tab
function! s:compackd_tab_set_status()
  call s:diagnostic("function! s:compackd_tab_set_status()", 7)

  if s:compackd_tab_switch()
    let total = len(s:compackd_setup_status.all)
    call setline(1, (s:compackd_setup_status.pull ? 'Updating' : 'Installing'). ' packages (' . len(s:compackd_setup_status.progress_bar) . '/' . total . ')')
    call s:compackd_tab_progress_bar(2, s:compackd_setup_status.progress_bar, total)
    call s:compackd_tab_switch_out()
  endif
endfunction

" s:compackd_tab_switch() : switch to the compackd tab
function! s:compackd_tab_switch()
  call s:diagnostic("function! s:compackd_tab_switch()", 7)

  if !s:compackd_tab_is_open()
    return 0
  endif

  if winbufnr(0) != s:compackd_winbufnr
    let s:pos = [tabpagenr(), winnr(), winsaveview()]
    execute 'normal!' s:compackd_tabpagenr.'gt'
    let winnr = bufwinnr(s:compackd_winbufnr)
    execute winnr.'wincmd w'
    call add(s:pos, winsaveview())
  else
    let s:pos = [winsaveview()]
  endif

  setlocal modifiable
  return 1
endfunction

" s:compackd_tab_switch_out(...) : switch to the previous tab and restore the view of the current window
function! s:compackd_tab_switch_out(...)
  call s:diagnostic("function! s:compackd_tab_switch_out(" . string(a:000) . ")", 7)

  call winrestview(s:pos[-1])
  setlocal nomodifiable
  if a:0 > 0
    execute a:1
  endif

  if len(s:pos) > 1
    execute 'normal!' s:pos[0].'gt'
    execute s:pos[1] 'wincmd w'
    call winrestview(s:pos[2])
  endif
endfunction

" s:compackd_tab_syntax() : add color to the compackd tab
function! s:compackd_tab_syntax()
  call s:diagnostic("function! s:compackd_tab_syntax()", 7)

  syntax clear
  syntax region pack1 start=/\%1l/ end=/\%2l/ contains=packNumber
  syntax region pack2 start=/\%2l/ end=/\%3l/ contains=packBracket,packX,packAbort
  syntax match packNumber /[0-9]\+[0-9.]*/ contained
  syntax match packBracket /[[\]]/ contained
  syntax match packX /x/ contained
  syntax match packAbort /\~/ contained
  syntax match packDash /^-\{1}\ /
  syntax match packPlus /^+/
  syntax match packStar /^*/
  syntax match packMessage /\(^- \)\@<=.*/
  syntax match packName /\(^- \)\@<=[^ ]*:/
  syntax match packSha /\%(: \)\@<=[0-9a-f]\{4,}$/
  syntax match packTag /(tag: [^)]\+)/
  syntax match packInstall /\(^+ \)\@<=[^:]*/
  syntax match packUpdate /\(^* \)\@<=[^:]*/
  syntax match packCommit /^  \X*[0-9a-f]\{7,9} .*/ contains=packRelDate,packEdge,packTag
  syntax match packEdge /^  \X\+$/
  syntax match packEdge /^  \X*/ contained nextgroup=packSha
  syntax match packSha /[0-9a-f]\{7,9}/ contained
  syntax match packRelDate /([^)]*)$/ contained
  syntax match packNotLoaded /(not loaded)$/
  syntax match packError /^x.*/
  syntax region packDeleted start=/^\~ .*/ end=/^\ze\S/
  syntax match packH2 /^.*:\n-\+$/
  syntax match packH2 /^-\{2,}/
  syntax keyword Function PackInstall PackStatus PackUpdate PackClean

  highlight def link pack1       Title
  highlight def link pack2       Repeat
  highlight def link packH2      Type
  highlight def link packX       Exception
  highlight def link packAbort   Ignore
  highlight def link packBracket Structure
  highlight def link packNumber  Number

  highlight def link packDash    Special
  highlight def link packPlus    Constant
  highlight def link packStar    Boolean

  highlight def link packMessage Function
  highlight def link packName    Label
  highlight def link packInstall Function
  highlight def link packUpdate  Type

  highlight def link packError   Error
  highlight def link packDeleted Ignore
  highlight def link packRelDate Comment
  highlight def link packEdge    PreProc
  highlight def link packSha     Identifier
  highlight def link packTag     Constant

  highlight def link packNotLoaded Comment
endfunction

"
" script-local : type functions
"

" s:compackd_type_is_list(v) : return a list type
function! s:compackd_type_is_list(v)
  call s:diagnostic("function! s:compackd_type_is_list(" . string(a:v) . ")", 81)

  return type(a:v) == s:compackd_type.list ? a:v : [a:v]
endfunction

" s:compackd_type_is_string(v) : return a string type
function! s:compackd_type_is_string(v)
  call s:diagnostic("function! s:compackd_type_is_string(" . string(a:v) . ")", 81)

  return type(a:v) == s:compackd_type.string ? a:v : join(a:v, "\n") . "\n"
endfunction

"
" script-local : diagnostic functions
"

" s:diagnostic(str, ...) : conditionally output a custom diagnostic message (dependent on plugin/000-diagnostic.vim)
function! s:diagnostic(str, ...)
  "
  " JJT NOTE:
  "
  " diagnostic 5     = autoload & user defined command functions
  " diagnostic 7-8   = interactive/tab functions
  " diagnostic 9-10  = os, call, or exec functions
  " diagnostic 11-12 = compackd second level functions
  " diagnostic 13-14 = compackd third level functions
  " diagnostic 19-20 = compackd deprecated functions
  " diagnostic 21-22 = job functions
  " diagnostic 41-42 = compackd _do_ functions
  " diagnostic 61-62 = compackd _get_ functions
  " diagnostic 81-82 = compackd _is_ functions

  if $COMPACKD_DIAGNOSTIC != ''
    if !exists("*Diagnostic")
      runtime! plugin/000-diagnostic.vim
    endif
    if exists("*Diagnostic")
      let $VIM_DIAGNOSTIC=$COMPACKD_DIAGNOSTIC

      "call Diagnostic_echo(a:str, a:000)
      if empty(a:000)
        call Diagnostic(a:str)
      else
        call Diagnostic(a:str, a:1)
      endif
    endif
  endif
endfunction

"
" script-local : echo functions [in addition to s:echo_err()]
"

" s:echo_warn() : echo a custom warning message
function! s:echo_warn(str)
  echohl WarningMsg
  echom '[compackd] WARNING : ' . a:str
  echohl None
endfunction

"
" script-local : main logic
"

let s:compackd_cpo_save = &cpo

set cpo&vim

let s:compackd_git_url = 'git@git.4b1d.in:compackd.git'
let s:compackd_spec_default_options = { 'branch': '', 'frozen': 0, 'packadd': 0}
let s:compackd_rtp_first = s:compackd_get_escape_space_comma(get(s:compackd_get_rtp(), 0, ''))
let s:compackd_rtp_last  = s:compackd_get_escape_space_comma(get(s:compackd_get_rtp(), -1, ''))

if s:compackd_is_win && &shellslash
  set noshellslash
  let s:compackd_sfile = resolve(expand('<sfile>:p'))
  set shellslash
else
  let s:compackd_sfile = resolve(expand('<sfile>:p'))
endif

let s:compackd_tabpagenr = get(s:, 'compackd_tabpagenr', -1)

let s:compackd_type = {
      \   'string':  type(''),
      \   'list':    type([]),
      \   'dict':    type({}),
      \   'funcref': type(function('call'))
      \ }

let s:compackd_winbufnr = get(s:, 'compackd_winbufnr', -1)

let &cpo = s:compackd_cpo_save
unlet s:compackd_cpo_save
