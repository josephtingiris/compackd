# Notes

Everything in here is automatically sourced.

- *.vim are sourced by both nvim and vim
- *.lua are only sourced by nvim

# Useful commands

* :verbose set autoindent? smartindent? cindent? cinkeys? indentexpr? " show what set it
* :echo &autoindent " show the value of it

* let          " list all variables
* let g:...    " g: global
* let s:...    " s: local (to script)
* let l:...    " l: local (to function)

* :e scp://remoteuser@host//path/to/document " edit a remote file with local vim

* :lua print(vim.inspect(vim.api.nvim_get_mode()))

# Helpful links

https://github.com/nanotee/nvim-lua-guide

https://hiphish.github.io/blog/2021/12/05/managing-vim-plugins-without-plugin-manager/

# Interesting links

https://docs.astronvim.com/
