# ezdap-adapters

A Neovim plugin bundling ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim). Install it and every adapter below is
registered at once: Python, C/C++/Rust, Go, .NET, Java, JavaScript, PHP, Ruby, Dart, Bash,
Lua. Nothing is loaded until you debug; a definition is read only when its adapter is used.

Each adapter is one self-contained *adapter definition*: a Lua file describing one debug
adapter, how it is started or connected to, and the launch and attach modes it supports. A
definition is configuration only. The adapter itself (`codelldb`, `lldb-dap`, `gdb`, `dlv`) is a separate program you install, and the definition
says how to find and drive it. Mode inputs are self-describing, so ezdap.nvim can prompt for
them and validate them.

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

" one-off session: adapter, mode, and the mode's inputs as key=value
:Debug run debugpy script command=./main.py

" or write a reusable run file for it
:Debug new_run_file debugpy
```

### A single definition instead

Nothing forces the whole set. Copy just the file you want into your own config:

```sh
mkdir -p ~/.config/nvim/lua/ezdap-adapters
curl -o ~/.config/nvim/lua/ezdap-adapters/debugpy.lua \
  https://raw.githubusercontent.com/mbfoss/ezdap-adapters/main/lua/ezdap-adapters/debugpy.lua
```

ezdap.nvim globs `lua/ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename, `debugpy.lua` becomes the `debugpy` adapter, the name `:Debug run`
takes. That is the same mechanism the plugin install uses; the plugin simply puts its own
`lua/ezdap-adapters/` directory on the runtimepath.

A copy in your own config takes precedence over the plugin's, so you can install the plugin
for everything and still keep your own edited `debugpy.lua`, or customise a definition's
`command`, modes, and defaults by editing the local file directly. Hand-copied definitions
are not updated automatically; the ones from the plugin update with it.

## Available adapters

ezdap.nvim itself ships only a generic `remote` definition; every language-specific one is
published here. Each row lists the modes a definition offers and the software
required to run it: the debug adapter, plus the separate debugger beneath it where there is one.

| Adapter | Language | Modes | Needs |
| --- | --- | --- | --- |
| [`debugpy`](lua/ezdap-adapters/debugpy.lua) | Python | `script` `module` `code` `attach` `remote` `listen` | any Python that can import [debugpy](https://github.com/microsoft/debugpy), an active virtualenv, a project `.venv`, the mason `debugpy` venv, or a system `python3` |
| [`codelldb`](lua/ezdap-adapters/codelldb.lua) | C / C++ / Rust | `binary` `attach` `process_name` `core` `gdb_remote` | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH`, an adapter over LLDB, which it bundles |
| [`lldb`](lua/ezdap-adapters/lldb.lua) | C / C++ / Rust | `binary` `attach` `process_name` `core` `gdb_remote` | `lldb-dap`, LLVM's own DAP adapter for LLDB, on `PATH`, or from Xcode's toolchains on macOS |
| [`gdb`](lua/ezdap-adapters/gdb.lua) | C / C++ | `binary` `attach` `remote` | [GDB](https://sourceware.org/gdb/) 14.1+, it is its own adapter (`gdb --interpreter=dap`) |
| [`delve`](lua/ezdap-adapters/delve.lua) | Go | `package` `test` `binary` `replay` `core` `attach` | [`dlv`](https://github.com/go-delve/delve) on `PATH`, under `$GOBIN` / `$GOPATH/bin` / `~/go/bin`, or from mason, its own adapter (`dlv dap`) |
| [`netcoredbg`](lua/ezdap-adapters/netcoredbg.lua) | .NET | `binary` `attach` | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` or from mason |
| [`java-debug-server`](lua/ezdap-adapters/java-debug-server.lua) | Java | `attach` | an already-running java-debug server, e.g. started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) |
| [`js-debug`](lua/ezdap-adapters/js-debug.lua) | JavaScript / TypeScript | `script` `attach` `remote` `browser` | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) |
| [`php-debug`](lua/ezdap-adapters/php-debug.lua) | PHP | `listen` `script` | `node`, plus the mason `php-debug-adapter` package ([vscode-php-debug](https://github.com/xdebug/vscode-php-debug)), the debugger it fronts is [Xdebug](https://xdebug.org/), loaded into the PHP being debugged |
| [`rdbg`](lua/ezdap-adapters/rdbg.lua) | Ruby | `script` `command` `remote` | [`rdbg`](https://github.com/ruby/debug), from the `debug` gem, on `PATH`, under `$GEM_HOME/bin`, or from mason |
| [`dart`](lua/ezdap-adapters/dart.lua) | Dart / Flutter | `script` `test` `attach` `flutter` `flutter_test` `flutter_attach` | the [Dart](https://dart.dev) or [Flutter](https://flutter.dev) SDK on `PATH`, or under `$DART_SDK` / `$FLUTTER_ROOT`, the adapters ship inside it and front the VM Service, so there is nothing else to install |
| [`bash-debug-adapter`](lua/ezdap-adapters/bash-debug-adapter.lua) | Bash | `script` | `bash-debug-adapter` on `PATH` ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)), the debugger it fronts is bashdb, from mason, `$BASHDB_HOME`, or `/usr/share/bashdb` |
| [`local-lua-debugger`](lua/ezdap-adapters/local-lua-debugger.lua) | Lua | `script` `executable` | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) |

Mode names are short and say what they run: `binary`, `script`, `package` and the other
launch modes start a new process, `attach` / `process_name` / `remote` / `gdb_remote` /
`listen` connect to a running one, and `core` / `replay` load a post-mortem artifact. Every
input carries a description, so `:Debug new_run_file <adapter>` and `quick_run` completion
document the accepted fields within Neovim.

## Locating the adapter

Where a definition has paths to resolve (the adapter executable, and anything that ships
beside it), they are usually variables at the top of its file. These can be customised if
needed. With the plugin installed, change a definition by copying it into
`~/.config/nvim/lua/ezdap-adapters/` and editing it there.

## Writing your own

An adapter definition is a single Lua file returning one `ezdap.AdapterDef`.
See [Writing an adapter definition](https://github.com/mbfoss/ezdap.nvim/blob/main/WRITING-DEFINITIONS.md).

Contributions of new definitions are welcome.
