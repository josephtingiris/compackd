an easy, lazy, & small [neo]vim package manager hacked from plug

- Lazier than [Lazy.nvim](https://github.com/folke/lazy.nvim)
- More minimal than [vim-plug](https://github.com/junegunn/vim-plug)
- Package based like [pckr.nvim](https://github.com/lewis6991/pckr.nvim)
- && a tiny bit more 😁 hard core than a wrapper for [vim.pack](https://neovim.io/doc/user/pack/)

## Features

- Works with all version of Neovim and Vim 8.0039+.
- Super fast parallel installs and updates.
- Lazy load functions and/or filetypes.
- Only one file with no dependencies.
- Git branch/tag/commit support.
- Review and rollback updates.
- Concise, intuitive syntax.
- Easy to set up and use.
- Local package support.
- Post-command hooks.
- Extremely stable.
- Extensible.

## Installation

#### Linux, macOS, UNIX, WSL

# Neovim
```
curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/compackd.vim --create-dirs https://raw.githubusercontent.com/josephtingiris/compackd/main/autoload/compackd.vim
```

# Vim
```
curl -fLo ~/.vim/autoload/compackd.vim --create-dirs  https://raw.githubusercontent.com/josephtingiris/compackd/main/autoload/compackd.vim
```

#### Windows (PowerShell:)

```powershell
iwr -useb https://raw.githubusercontent.com/josephtingiris/compackd/main/autoload/pack.vim | ni $HOME/vimfiles/autoload/pack.vim -Force
```

## Usage

Add a section to your `~/.vimrc` (or `~/.config/nvim/init.vim` for Neovim), and/or add individual files to your `plugin/` directory.

For example,

```vim
call compackd#()

Pack 'vim-airline/vim-airline'
```

Once `compackd#()` is called, the following options are available:

* `:PackInstall` install all packages
* `:PackUpdate` install or update all packages
* `:PackClean` remove packages no longer in use
* `:PackDiff` review the changes since the last update
* `:PackSnapshot` create a snapshot file of all packages at their current versions
* `:PackStatus` check the status of installed packages
* `:PackUgrade` upgrade pack.vim

## Examples

The following examples demonstrate some of the features of compackd.

### vim script example for [neo]vim

```vim
call compackd#()

" The default package directory will be as follows:
"   - [neo]vim (Linux/macOS/UNIX): '~/.vim/pack/.d/pack/compackd/opt/'
"   - [neo]vim (Windows): '~/vimfiles/pack/.d/pack/compackd/opt/'
"   - Neovim (Linux/macOS/Windows): stdpath('data') . '/pack/.d/pack/compackd/opt/'
" You can specify a custom package directory by passing it as the argument
"   - e.g. `call compackd#('~/.vim/mypackages/pack/compackd/opt/')`
"   - The package directory *must* include '/pack/<name>/opt', as per [neo]vim package requirements

" Make sure you use single quotes; any valid URL is allowed.  Simple URIs will automatically be prefixed with https://github.com/
"   Pack 'vim-airline/vim-airline'

" Using a tagged release; wildcard allowed (requires git 1.9.2 or above)
Pack 'fatih/vim-go', { 'tag': '*' }

" Using a non-default branch
Pack 'neoclide/coc.nvim', { 'branch': 'release' }

" Post-command hook: run a shell command after installing or updating the package
Pack 'junegunn/fzf', { 'plugin_dir': '~/.fzf', 'post_update': './install --all' }

" Lazy loaded when the specified command is executed
Pack 'preservim/nerdtree', { 'lazy_functions': [ 'NERDTreeToggle' ] }
```

### lua example for neovim

The following code is the Lua script equivalent to the [neo]vim script example above.

```lua
local vim = vim
local Pack = vim.fn[ 'compackd#' ]

vim.call('compackd#')

-- Make sure you use single quotes; any valid URL is allowed.  Simple URIs will automatically be prefixed with https://github.com/
Pack('vim-airline/vim-airline')

-- Using a tagged release; wildcard allowed (requires git 1.9.2 or above)
Pack('fatih/vim-go', { [ 'tag' ] = '*' })

-- Using a non-default branch
Pack('neoclide/coc.nvim', { [ 'branch' ] = 'release' })

-- Post-command hook: run a shell command after installing or updating the package
Pack('junegunn/fzf', { [ 'plugin_dir' ] = '~/.fzf', [ 'post_update' ] = './install --all' })

-- Lazy loaded when the specified command is executed
Pack('preservim/nerdtree', { [ 'lazy_functions' ] = [ 'NERDTreeToggle' ] })
```

## Commands

+==========================================================================================================+
| Command                             | Description                                                        |
| ----------------------------------- | ------------------------------------------------------------------ |
| `Pack [{}]`                         | Define the package URL and options to be installed or updated      |
| `PackDiff`                          | Examine changes from the previous update and the pending changes   |
| `PackInstall [name ...] [#threads]` | Install packages                                                   |
| `PackUpdate [name ...] [#threads]`  | Install or update packages                                         |
| `PackClean[!]`                      | Remove unlisted packages (bang will clean without promptng)        |
| `PackUpgrade`                       | Upgrade compackd itself                                            |
| `PackSnapshot[!] [output path]`     | Generate script for restoring the current snapshot of the packages |
| `PackStatus`                        | Check the status of packages                                       |
+==========================================================================================================+

## `Pack` command options

+=======================================================================================+
| Option                  | Description                                                 |
| ----------------------- | ----------------------------------------------------------- |
| `branch`/`tag`/`commit` | Branch/tag/commit of the repository to use                  |
| `package_dir`           | Subdirectory that contains [neo]vim packages                |
| `plugin_dir`            | Custom plugin directory for the package                     |
| `package_name`          | Use different name for the packages                         |
| `post_update`           | Post-command hook (executable or :function reference)       |
| `lazy_functions`        | On-demand loading: Commands or `<Pack>`-mappings            |
| `lazy_filetypes`        | On-demand loading: File types                               |
| `frozen`                | Do not remove and do not update unless explicitly specified |
+=======================================================================================+

## Global options

+==================================================================================================================+
| Flag                | Default                           | Description                                            |
| ------------------- | --------------------------------- | ------------------------------------------------------ |
| `g:pack_threads`    | 16                                | Default number of threads to use                       |
| `g:pack_shallow`    | 1                                 | Use shallow clone                                      |
| `g:pack_window`     | `-tabnew`                         | Command to open pack window                            |
| `g:pack_pwindow`    | `vertical rightbelow new`         | Command to open preview window in `PackDiff`           |
| `g:pack_url_format` | `https://git::@github.com/%s.git` | `printf` format to build repo URL                      |
+==================================================================================================================+

## Keybindings

- `D` - `PackDiff`
- `S` - `PackStatus`
- `R` - Retry failed update or installation tasks
- `U` - Update pack in the selected range
- `q` - Abort the running tasks or close the window
- `:PackStatus`
    - `L` - Load plugin
- `:PackDiff`
    - `X` - Revert the update

## Post-command hooks

There are some plugins that require extra steps after installation or update. In that case, use the `post_update` option to describe the task to be performed.

If the value does not start with `:`, it will be recognized as executable.

```vim
Pack 'Shougo/vimproc.vim', { 'post_update': 'make' }
Pack 'ycm-core/YouCompleteMe', { 'post_update': './install.py' }
```

If the value starts with `:`, it will be recognized as a [neo]vim command.

```vim
Pack 'fatih/vim-go', { 'post_update': ':GoInstallBinaries' }
```

To call a [neo]vim function, you can pass a lambda expression like so:

```vim
Pack 'junegunn/fzf', { 'post_update': { -> fzf#install() } }
```

The post-update hook is executed inside the directory of the plugin and only run when the repository has changed, but you can force it to run unconditionally with the bang-versions of the commands: `PackInstall!` and `PackUpdate!`.

### `PackInstall!` and `PackUpdate!`

The installer takes the following steps when installing/updating a plugin:

1. `git clone` or `git fetch` from its origin
2. Check out branch, tag, or commit and optionally `git merge` remote branch
3. If the plugin was updated (or installed for the first time)
    1. Update submodules
    2. Execute post-update hooks

The commands with the `!` suffix ensure that all steps are run unconditionally.

## On-demand loading of plugins

```vim
" NERD tree will be loaded on the first invocation of NERDTreeToggle command
Pack 'preservim/nerdtree', { 'lazy_functions': [ 'NERDTreeToggle' ] }

" Lazy load via multiple functions
Pack 'scrooloose/nerdtree', { 'lazy_functions' : [ 'NERDTreeExplore', 'NERDTreeFind', 'NERDTreeToggle', 'NERDTreeToggleVCS', 'NERDTreeVCS' ] }

" Lazy loaded when clojure file is opened
Pack 'tpope/vim-fireplace', { 'lazy_filetypes': [ 'clojure' ] }

" Multiple file types
Pack 'kovisoft/paredit', { 'lazy_filetypes': [ 'clojure', 'scheme' ] }

" On-demand loading on both conditions
Pack 'junegunn/vader.vim',  { 'lazy_functions': [ 'Vader' ], 'lazy_filetypes': [ 'vader' ] }

" Code to execute when the plugin is lazily loaded on demand
Pack 'junegunn/goyo.vim', { 'lazy_filetypes': [ 'markdown' ] }
autocmd! User goyo.vim echom 'Goyo is now loaded!'
```
## Shoulders (Thanks for sharing!)

- Junegunn Choi for [vim-plug](https://github.com/junegunn/vim-plug) and his many contributions to the [neo]vim community.  Plus, a significant portion of the original vim script that was used in compackd and his inspiration in our chat regarding `:h startup`; The user config step (e.g. `.vimrc`) should be an option, not a requirement.
- Folke Lemaitre for providing the very popular [Lazy.nvim](https://github.com/folke/lazy.nvim) and making lazy sound fun, despite its numerous complexities. Not easy.
- Wil Thomason & Lewis Russell for giving us [pckr.nvim](https://github.com/lewis6991/pckr.nvim) and proving that a better way to manage [neo]vim plugins is via the package facilities.  If it were written in vim script I wouldn't be writing this.

## License

MIT
