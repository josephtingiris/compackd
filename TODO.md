# 🧭 TODO

- ensure examples for all to see, ie. how to do a lua require('').setup via vimscript, cc eg. https://github.com/josephtingiris/dotfiles/blob/master/.config/nvim/plugin/024-compackd/200-nvim-treesitter.vim
- better doxing, e.g. here is how my .vimrc is decomposing ... my contents are not included because we are many and who knows what others want ... more examples
```
[jtingiris@d0 ~/.vim/plugin]$ realpath .; ls -ld ~/.vim                                                                                 │
/home/jtingiris/.config/nvim/plugin                                                                                                     │
lrwxrwxrwx jtingiris jtingiris 12 B Wed Aug 12 20:03:15 2026 /home/jtingiris/.vim ⇒ .config/nvim
|
├── 000-diagnostic.vim
├── 000-init.lua
├── 000-init.vim
├── 001-vimrc-first.vim
├── 010-preferences.vim
├── 010-providers.vim
├── 012-compackd.vim
├── 024-compackd
│   ├── 100-coc.nvim.vim
│   ├── 100-telescope.nvim.vim
│   ├── 200-nvim-treesitter.vim
│   ├── 200-render-markdown.nvim.vim
│   ├── 201-nvim-treesitter-context.vim
│   ├── 300-blink.lib.vim
│   ├── 301-blink.cmp.vim
│   ├── PHP-Indenting-for-VIm.vim
│   ├── YouCompleteMe.vim
│   ├── ale.vim
│   ├── ansible-vim.vim
│   ├── copilot.vim.vim
│   ├── ctrlp.vim.vim
│   ├── d2-vim.vim
│   ├── delimitMate.vim
│   ├── harpoon2.vim
│   ├── lazy.nvim.vim
│   ├── mini.nvim.vim
│   ├── minuet-ai.nvim.vim
│   ├── neoformat.vim
│   ├── nerdtree-git-plugin.vim
│   ├── nerdtree.vim
│   ├── nvim-cmp.vim
│   ├── nvim-lualine.vim
│   ├── nvim-web-devicons.vim
│   ├── open-browser.vim.vim
│   ├── plantuml-previewer.vim.vim
│   ├── plenary.nvim.vim
│   ├── presence.nvim.vim
│   ├── rainbow.vim
│   ├── snacks.nvim.vim
│   ├── syntastic.vim
│   ├── tree-sitter-markdown.vim
│   ├── vim-anyfold.vim
│   ├── vim-devicons.vim
│   ├── vim-fugitive.vim
│   ├── vim-go.vim
│   ├── vim-gutentags.vim
│   ├── vim-instant-markdown.vim
│   ├── vim-markdown-composer.vim
│   ├── vim-php-cs-fixer.vim
│   ├── vim-polyglot.vim
│   ├── vim-powershell.vim
│   ├── vim-ps1.vim
│   ├── vim-sh-indent.vim
│   ├── vim-shfmt.vim
│   ├── yyy-vim-airline.vim
│   └── zzz-vim-airline-themes.vim
├── 200-characters.vim
├── 200-colors.vim
├── 200-cursor.vim
├── 200-indent.vim
├── 200-swap.vim
├── 300-myBufEvents.vim
├── 300-myCursorEvents.vim
├── 300-myFileTypeEvents.vim
├── 300-myOptionEvents.vim
├── 300-mySourceEvents.vim
├── 300-myStdEvents.vim
├── 300-myUserEvents.vim
├── 300-myVimEvents.vim
├── 50-highlight-names.vim
├── 500-clipboard.lua
├── 500-clipboard.vim
├── 500-paste.vim
├── 500-spell.vim
├── 500-tags.vim
├── 500-undo.vim
├── 800-keyboard.vim
├── 900-copilot.lua
├── README.md
├── zzz-runtimepath.vim
└── zzz-vimrc-last.vim
```
