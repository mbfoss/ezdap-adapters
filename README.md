# ezdap-adapters

A Neovim plugin bundling ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim). Install it and every adapter below is
registered at once: Python, C/C++/Rust, Go, .NET, Java, JavaScript, PHP, Ruby, Dart, Bash,
Lua. Nothing is loaded at startup: the definitions are read the first time ezdap.nvim builds
its adapter registry, which is when you first debug. They are plain tables of configuration,
so the ones you never use cost a file read and nothing more.

Each adapter is one self-contained *adapter definition*: a Lua file describing one debug
adapter, how it is started or connected to, and the launch and attach modes it supports. A
definition is configuration only. The adapter itself (`codelldb`, `lldb-dap`, `gdb`, `dlv`) is
a separate program you install, and the definition says how to find and drive it. Mode inputs
are self-describing, so ezdap.nvim can prompt for them and validate them.

Because the files are self-contained, any one of them also works on its own: copy a single
definition into your own config and it behaves exactly the same, with or without this
plugin installed. See [A single definition instead](#a-single-definition-instead).

## Requirements

- Neovim with [ezdap.nvim](https://github.com/mbfoss/ezdap.nvim) installed.
- The debug adapter itself, on `PATH`, installed via
  [mason.nvim](https://github.com/mason-org/mason.nvim), or in one of the usual locations
  each definition searches; see [Locating the adapter](#locating-the-adapter).
  [Available adapters](#available-adapters) lists what each one needs.

## Quick start

Install the plugin, with Neovim 0.12's built-in plugin manager (`:h vim.pack`), in your
`init.lua`:

```lua
vim.pack.add({
  "https://github.com/mbfoss/ezdap.nvim",
  "https://github.com/mbfoss/ezdap-adapters",
})
```

with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mbfoss/ezdap.nvim",
  dependencies = { "mbfoss/ezdap-adapters" },
}
```

or any other plugin manager.

Restart Neovim, then:

```vim
" verify the definitions load and their adapters are found
:checkhealth ezdap

" what an adapter takes: its modes, and each mode's inputs
:Debug adapters debugpy

" one-off session: adapter, mode, and the mode's inputs as key=value
:Debug run debugpy script command=./main.py

" or write a reusable run file for it
:Debug new_run_file debugpy
```

### A single definition instead <!-- tag: single-definition -->

Nothing forces the whole set. Copy just the file you want into your own config:

```sh
mkdir -p ~/.config/nvim/ezdap-adapters
curl -o ~/.config/nvim/ezdap-adapters/debugpy.lua \
  https://raw.githubusercontent.com/mbfoss/ezdap-adapters/main/ezdap-adapters/debugpy.lua
```

ezdap.nvim globs `ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename, `debugpy.lua` becomes the `debugpy` adapter, the name `:Debug run`
takes. The directory sits beside `lsp/` and `plugin/`, not under `lua/`: these are
definitions read by filename, not Lua modules. That is the same mechanism the plugin
install uses; the plugin simply puts its own `ezdap-adapters/` directory on the
runtimepath.

A copy in your own config takes precedence over the plugin's, so you can install the plugin
for everything and still keep your own edited `debugpy.lua`, or customise a definition's
`command`, modes, and defaults by editing the local file directly. Hand-copied definitions
are not updated automatically; the ones from the plugin update with it.

## Available adapters <!-- tag: adapters -->

ezdap.nvim itself ships only a generic `remote` definition; every language-specific one is
published here. One row per definition: the software it needs — the debug adapter, plus the
separate debugger beneath it where there is one — and the modes it offers.

| Adapter | Debugs | Needs | Modes |
| --- | --- | --- | --- |
| [`debugpy`](ezdap-adapters/debugpy.lua) | Python | a Python that can import [debugpy](https://github.com/microsoft/debugpy): the active virtualenv, `$CONDA_PREFIX`, a project `.venv`/`venv`, the mason venv, then system `python3`/`python` | `attach`, `code`, `listen`, `module`, `remote`, `script` |
| [`codelldb`](ezdap-adapters/codelldb.lua) | C / C++ / Rust | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH`; it bundles LLDB, so no separate debugger | `attach`, `binary`, `core`, `gdb_remote`, `process_name` |
| [`lldb`](ezdap-adapters/lldb.lua) | C / C++ / Rust | `lldb-dap`, LLVM's own DAP adapter, on `PATH` or from Xcode's toolchains on macOS | `attach`, `binary`, `core`, `gdb_remote`, `process_name` |
| [`gdb`](ezdap-adapters/gdb.lua) | C / C++ | [GDB](https://sourceware.org/gdb/) 14.1 or newer; it is its own adapter, driven as `gdb --interpreter=dap` | `attach`, `binary`, `core`, `remote` |
| [`delve`](ezdap-adapters/delve.lua) | Go | [`dlv`](https://github.com/go-delve/delve) on `PATH`, under `$GOBIN` / `$GOPATH/bin` / `~/go/bin`, or from mason; its own adapter, driven as `dlv dap` | `attach`, `binary`, `core`, `package`, `replay`, `test` |
| [`netcoredbg`](ezdap-adapters/netcoredbg.lua) | .NET | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` or from mason | `attach`, `binary` |
| [`java-debug-server`](ezdap-adapters/java-debug-server.lua) | Java | an already-running java-debug server, e.g. one started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls); this definition only connects to it | `attach` |
| [`js-debug`](ezdap-adapters/js-debug.lua) | JavaScript / TypeScript | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) | `attach`, `browser`, `remote`, `script` |
| [`php-debug`](ezdap-adapters/php-debug.lua) | PHP | `node`, plus the mason `php-debug-adapter` package ([vscode-php-debug](https://github.com/xdebug/vscode-php-debug)); it fronts [Xdebug](https://xdebug.org/), loaded into the PHP being debugged | `listen`, `script` |
| [`rdbg`](ezdap-adapters/rdbg.lua) | Ruby | [`rdbg`](https://github.com/ruby/debug), from the `debug` gem, on `PATH`, under `$GEM_HOME/bin`, or from mason | `command`, `remote`, `script` |
| [`dart`](ezdap-adapters/dart.lua) | Dart / Flutter | the [Dart](https://dart.dev) or [Flutter](https://flutter.dev) SDK on `PATH`, or under `$DART_SDK` / `$FLUTTER_ROOT`; the adapters ship inside the SDK | `attach`, `flutter`, `flutter_attach`, `flutter_test`, `script`, `test` |
| [`bash-debug-adapter`](ezdap-adapters/bash-debug-adapter.lua) | Bash | `bash-debug-adapter` on `PATH` ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)); it fronts bashdb, taken from mason, `$BASHDB_HOME`, `/usr/local/share/bashdb` or `/usr/share/bashdb` | `script` |
| [`local-lua-debugger`](ezdap-adapters/local-lua-debugger.lua) | Lua | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) | `executable`, `script` |

Mode names are short and say what they run: `binary`, `script`, `package` and the other
launch modes start a new process, `attach` / `process_name` / `remote` / `gdb_remote` /
`listen` connect to a running one, and `core` / `replay` load a post-mortem artifact.

**What each mode takes is not listed here.** The definitions describe their own inputs, so
Use ezdap Debug command the show the support input modes and fields:

```vim
:Debug adapters                 " every registered adapter and its modes
:Debug adapters debugpy         " every mode, with its inputs and their types
:Debug adapters debugpy script  " just that mode
```

See [`:Debug adapters`](https://github.com/mbfoss/ezdap.nvim#debug-adapters), help tag
|ezdap-adapters-command|. The same descriptions reach you while typing: completion after
`:Debug run <adapter> <mode> ` lists the mode's inputs, and `:Debug new_run_file <adapter>
<mode>` writes them all out, commented. A definition you copy and edit documents itself the
same way, which no listing here could.

## Locating the adapter <!-- tag: locating -->

Where a definition has paths to resolve (the adapter executable, and anything that ships
beside it), they are usually variables at the top of its file. These can be customised if
needed. With the plugin installed, change a definition by copying it into
`~/.config/nvim/ezdap-adapters/` and editing it there.

## Writing your own <!-- tag: writing -->

An adapter definition is a single Lua file returning one `ezdap.AdapterDef`.
See [Writing an adapter
definition](https://github.com/mbfoss/ezdap.nvim/blob/main/WRITING-DEFINITIONS.md).

Contributions of new definitions are welcome.
