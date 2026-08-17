" +======================================+
" | [neo]vim script diagnostic functions |
" +======================================+
"
"
" Copyright (c) 2025 Joseph Tingiris
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

" Diagnostic(str, ...) : conditionally echo a custom diagnostic message
function! Diagnostic(str, ...)
    let msg_level = empty(a:000) ? 1 : a:1

    let echo_command_line = 0
    let echo_log = 0
    let echo_tab = 0

    if exists('$VIM_DIAGNOSTIC_COMMAND_LINE') && $VIM_DIAGNOSTIC_COMMAND_LINE != ''
        let echo_command_line = 1
        let $VIM_DIAGNOSTIC=$VIM_DIAGNOSTIC_COMMAND_LINE
    endif

    if exists('$VIM_DIAGNOSTIC_TAB') && $VIM_DIAGNOSTIC_TAB != ''
        let echo_tab = 1
        let $VIM_DIAGNOSTIC=$VIM_DIAGNOSTIC_TAB
    endif

    if exists('$VIM_DIAGNOSTIC') && $VIM_DIAGNOSTIC != ''
        let diagnostic_level = $VIM_DIAGNOSTIC =~ '[^0-9]' ? 20 : str2nr($VIM_DIAGNOSTIC)
    else
        return 0
    endif

    if msg_level > diagnostic_level
        return 0
    endif

    if !echo_command_line && !echo_tab
        let echo_log = 1

        if !exists('$VIM_DIAGNOSTIC_LOG') || $VIM_DIAGNOSTIC_LOG == ''
            let $VIM_DIAGNOSTIC_LOG=$HOME."/vim-diagnostic.log"
        endif
    endif

    if empty(a:str)
        if echo_log
            call Diagnostic_log(' ', msg_level)
        else
            if echo_command_line || has('vim_starting')
                echo ' '
            endif

            if echo_tab && !has('vim_starting')
                call Diagnostic_tab(' ')
            endif
        endif
    endif

    if echo_command_line || has('vim_starting')
        " highlight to command-line
        call Diagnostic_highlight(1, msg_level)
    endif

    let msg_prefix='DIAGNOSTIC[' . string(msg_level) . '/' . string(diagnostic_level) . '] : '

    let diagnostic_msg=''

    if type(a:str) == 1
        let diagnostic_msg=msg_prefix . a:str
    else
        let diagnostic_msg=msg_prefix . string(a:str)
    endif

    if echo_log
        call Diagnostic_log(diagnostic_msg, msg_level)
    else
        if echo_command_line || has('vim_starting')
            echo diagnostic_msg
        endif

        if echo_tab && !has('vim_starting')
            call Diagnostic_tab(diagnostic_msg)
        endif
    endif

    echohl None
endfunction

" Diagnostic_highlight(echo_tab, msg_level) : conditionally colorize output
function! Diagnostic_highlight(echo_to, msg_level)
    let msg_level = a:msg_level

    let echo_ansi=0
    let echo_command_line=0
    let echo_tab=0

    if a:echo_to == 0
        let echo_ansi=1
    endif

    if a:echo_to == 1
        let echo_command_line=1
    endif

    if a:echo_to == 2
        let echo_tab=1
    endif

    if echo_ansi
        if msg_level == 99999 | return "\e[0m" | endif " reset all attributes

        " default
        let sequence="\e[48;5;238m" " darkgrey background

        " 1-3
        if msg_level > 0 && msg_level < 3 | let sequence="\e[96m" | endif " cyan

        " 3-4
        if msg_level > 2 && msg_level < 5 | let sequence="\e[94m" | endif " blue

        " 5-6
        if msg_level > 4 && msg_level < 7 | let sequence="\e[92m" | endif  " green

        " 7-8
        if msg_level > 6 && msg_level < 9 | let sequence="\e[93m" | endif " yellow

        " 9-10
        if msg_level > 8 && msg_level < 11 | let sequence="\e[91m" | endif " red

        " 11-12
        if msg_level > 10 && msg_level < 13 | let sequence="\e[38;5;249m" | endif " grey

        " 13-14
        if msg_level > 12 && msg_level < 15 | let sequence="\e[7m" | endif " (reverse)

        " 15-16
        if msg_level > 14 && msg_level < 17 | let sequence="\e[102m"  | let sequence.="\e[30m" | endif " green background, black foreground

        " 17-18
        if msg_level > 16 && msg_level < 19 | let sequence="\e[103m"  | let sequence.="\e[30m" | endif " yellow background, black foreground

        " 19-20
        if msg_level > 18 && msg_level < 21 | let sequence="\e[101m" | endif " red background

        " 21-40
        if msg_level > 20 && msg_level < 41 | let sequence="\e[106m" | let sequence.="\e[30m" | endif " cyan background black foreground

        " 41-60
        if msg_level > 40 && msg_level < 61 | let sequence="\e[48;5;249m" | let sequence.="\e[30m" | endif " grey background black foreground

        " 61-80
        if msg_level > 60 && msg_level < 81 | let sequence="\e[48;5;22m" | endif " darkgreen background

        " 81-99
        if msg_level > 80 && msg_level < 100 | let sequence="\e[48;5;214m" | let sequence.="\e[30m" | endif " orange background black foreground

        " 100-299
        if msg_level > 99 && msg_level < 300 | let sequence="\e[48;5;127m" | endif " magenta background black foreground

        return sequence
    endif

    if echo_command_line
        " NOTE: by default, the following highlight groups only work for Neovim (dev) [not vim]. see vim.lua

        " default
        echohl DiagnosticDeprecated " (strikethrough)

        " 0
        if msg_level == 0 | echohl Debug | endif " Special

        " 1-3
        if msg_level > 0 && msg_level < 3 | echohl DiagnosticInfo | endif " cyan

        " 3-4
        if msg_level > 2 && msg_level < 5 | echohl DiagnosticHint | endif " blue

        " 5-6
        if msg_level > 4 && msg_level < 7 | echohl DiagnosticOk | endif  " green

        " 7-8
        if msg_level > 6 && msg_level < 9 | echohl DiagnosticWarn | endif " yellow

        " 9-10
        if msg_level > 8 && msg_level < 11 | echohl DiagnosticError | endif " red

        " 11-12
        if msg_level > 10 && msg_level < 13 | echohl DiagnosticUnnecessary | endif " Comment

        " 13-14
        if msg_level > 12 && msg_level < 15 | echohl RedrawDebugNormal | endif " (reverse)

        " 15-16
        if msg_level > 14 && msg_level < 17 | echohl RedrawDebugComposed | endif " green background

        " 17-18
        if msg_level > 16 && msg_level < 19 | echohl RedrawDebugClear | endif " yellow background

        " 19-20
        if msg_level > 18 && msg_level < 21 | echohl RedrawDebugRecompose | endif " red background

        " 21-40
        if msg_level > 20 && msg_level < 41 | echohl DiagnosticUnderlineInfo | endif " lightblue (underlined)

        " 41-60
        if msg_level > 40 && msg_level < 61 | echohl DiagnosticUnderlineHint | endif " lightgrey (underlined)

        " 61-80
        if msg_level > 60 && msg_level < 81 | echohl DiagnosticUnderlineOk | endif " lightgreen (underlined)

        " 81-99
        if msg_level > 80 && msg_level < 100 | echohl DiagnosticUnderlineWarn | endif " orange (underlined)

        " 100-299
        if msg_level > 99 && msg_level < 300 | echohl DiagnosticUnderlineError | endif " red (underlined)
    endif

    if echo_tab
        highlight DiagnosticInfo ctermfg=cyan guifg=cyan
        highlight DiagnosticHint ctermfg=blue guifg=blue
        highlight DiagnosticOk ctermfg=green guifg=green
        highlight DiagnosticWarn ctermfg=yellow guifg=yellow
        highlight DiagnosticError ctermfg=red guifg=red
        highlight DiagnosticUnnecessary ctermfg=darkgrey guifg=darkgrey

        highlight RedrawDebugNormal cterm=reverse gui=reverse
        highlight RedrawDebugComposed ctermfg=white guifg=white ctermbg=green guibg=green
        highlight RedrawDebugClear ctermfg=black guifg=black ctermbg=yellow guibg=yellow

        syntax clear

        " default
        syntax match DiagnosticDeprecated /^.*$/ " (strikethrough

        " 0
        syntax match Debug /^\[.*DIAGNOSTIC\[0\/.*$/ " Special

        " 1-10
        syntax match DiagnosticInfo /^\[.*DIAGNOSTIC\[[1-2]\/.*$/ " cyan
        syntax match DiagnosticHint /^\[.*DIAGNOSTIC\[[3-4]\/.*$/ " blue
        syntax match DiagnosticOk /^\[.*DIAGNOSTIC\[[5-6]\/.*$/ " green
        syntax match DiagnosticWarn /^\[.*DIAGNOSTIC\[[7-8]\/.*$/ " yellow
        syntax match DiagnosticError /^\[.*DIAGNOSTIC\[9\/.*$/ " red
        syntax match DiagnosticError /^\[.*DIAGNOSTIC\[10\/.*$/ " red

        " 11-12
        syntax match DiagnosticUnnecessary /^\[.*DIAGNOSTIC\[1[1-2]\/.*$/ " Comment

        " 13-20
        syntax match RedrawDebugNormal /^\[.*DIAGNOSTIC\[1[3-4]\/.*$/ " (reverse)
        syntax match RedrawDebugComposed /^\[.*DIAGNOSTIC\[1[5-6]\/.*$/ " green background
        syntax match RedrawDebugClear /^\[.*DIAGNOSTIC\[1[7-8]\/.*$/ " yellow background
        syntax match RedrawDebugRecompose /^\[.*DIAGNOSTIC\[19\/.*$/ " red background
        syntax match RedrawDebugRecompose /^\[.*DIAGNOSTIC\[20\/.*$/ " red background

        " 21-40
        syntax match DiagnosticUnderlineInfo /^\[.*DIAGNOSTIC\[2[1-9]\/.*$/ " lightblue (underlined)
        syntax match DiagnosticUnderlineInfo /^\[.*DIAGNOSTIC\[3[0-9]\/.*$/ " lightblue (underlined)
        syntax match DiagnosticUnderlineInfo /^\[.*DIAGNOSTIC\[40\/.*$/ " lightblue (underlined)

        " 41-60
        syntax match DiagnosticUnderlineHint /^\[.*DIAGNOSTIC\[4[1-9]\/.*$/ " lightgrey (underlined)
        syntax match DiagnosticUnderlineHint /^\[.*DIAGNOSTIC\[5[0-9]\/.*$/ " lightgrey (underlined)
        syntax match DiagnosticUnderlineHint /^\[.*DIAGNOSTIC\[60\/.*$/ " lightgrey (underlined)

        " 61-80
        syntax match DiagnosticUnderlineOk /^\[.*DIAGNOSTIC\[6[1-9]\/.*$/ " lightgreen (underlined)
        syntax match DiagnosticUnderlineOk /^\[.*DIAGNOSTIC\[7[0-9]\/.*$/ " lightgreen (underlined)
        syntax match DiagnosticUnderlineOk /^\[.*DIAGNOSTIC\[80\/.*$/ " lightgreen (underlined)

        " 81-99
        syntax match DiagnosticUnderlineWarn /^\[.*DIAGNOSTIC\[8[1-9]\/.*$/ " orange (underlined)
        syntax match DiagnosticUnderlineWarn /^\[.*DIAGNOSTIC\[9[0-9]\/.*$/ " orange (underlined)

        " 100-299
        syntax match DiagnosticUnderlineError /^\[.*DIAGNOSTIC\[1[0-9][0-9]\/.*$/ " red (underlined)
        syntax match DiagnosticUnderlineError /^\[.*DIAGNOSTIC\[2[0-9][0-9]\/.*$/ " red (underlined)

    endif

endfunction

" Diagnostic_log(str, msg_level) : conditionally echo a custom diagnostic message
function! Diagnostic_log(str, msg_level)
    let msg_level = a:msg_level

    let log_string=''
    let log_string.=Diagnostic_highlight(0, msg_level)
    let log_string.=a:str
    let log_string.=Diagnostic_highlight(0, 99999)

    call writefile([log_string], $VIM_DIAGNOSTIC_LOG, 'a')
endfunction

" Diagnostic_tab(message, ...) : echo a custom message to a separate tab
function! Diagnostic_tab(message, ...)
    let echo_tab_name = empty(a:000) ? '[diagnostic]' : a:1

    " save current tab number
    let echo_tab_current_pagenr = tabpagenr()

    " determine if a previous echo_tab_name is open and has the same buffname
    for open_tab in gettabinfo()
        let open_tabnr=open_tab.tabnr
        silent! execute 'normal!' open_tabnr.'gt'
        if echo_tab_name == bufname()
            let echo_tab_pagenr = open_tab.tabnr
            break
        endif
    endfor

    if exists('echo_tab_pagenr')
        " go to previously open tab number
        silent! execute 'normal!' echo_tab_pagenr.'gt'
    else
        " open a new tab number
        silent! execute 'tabnew' fnameescape(echo_tab_name)
        let echo_tab_pagenr = tabpagenr()

        " disable writing to a file
        setlocal buftype=nofile
    endif

    " echo the message into the diagnostic tab buffer
    execute 'normal! Go' . a:message
    "execute 'normal! Go' . "echo_tab_pagenr = " . echo_tab_pagenr
    "execute 'normal! Go' . "echo_tab_current_pagenr = " . echo_tab_current_pagenr

    " highlight to tab
    call Diagnostic_highlight(2, 0)

    " go back to current tab number
    silent! execute 'normal!' echo_tab_current_pagenr.'gt'
endfunction
