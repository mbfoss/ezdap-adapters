# ezdap-adapters

A registry of ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim).

Each file is a self-contained *adapter definition*: a Lua module describing one debug
adapter — how it is started or connected to, and the launch and attach profiles it
supports. A definition is configuration only. The adapter itself — `codelldb`, `lldb-dap`,
`gdb --interpreter=dap`, `dlv dap` — is a separate program you install, and the definition
says how to find and drive it. Some of these adapters front a separate debugger (`codelldb`
drives LLDB, `php-debug` drives Xdebug); others are the debugger, speaking DAP directly
(`gdb`, `dlv`, `debugpy`). Profile inputs are self-describing, so ezdap.nvim can prompt for
them and validate them. Definitions are installed individually, as needed.

## Requirements

- Neovim with [ezdap.nvim](https://github.com/mbfoss/ezdap.nvim) installed.
- The debug adapter itself, on `PATH`, installed via
  [mason.nvim](https://github.com/mason-org/mason.nvim), or in one of the usual locations
  each definition searches — see [Locating the adapter](#locating-the-adapter).
  [Available adapters](#available-adapters) lists what each one needs.

## Quick start

Copy the definition you want into your own config under `~/.config/nvim/lua/ezdap-adapters/`:

```sh
mkdir -p ~/.config/nvim/lua/ezdap-adapters
curl -o ~/.config/nvim/lua/ezdap-adapters/debugpy.lua \
  https://raw.githubusercontent.com/mbfoss/ezdap-adapters/main/adapters/debugpy.lua
```

Restart Neovim, then:

```vim
" verify the definition loads and its adapter is found
:checkhealth ezdap

" one-off session: adapter, profile, and the profile's inputs as key=value
:Debug run debugpy launch_program command=./main.py

" or write a reusable run file for it
:Debug new_run_file debugpy
```

ezdap.nvim globs `lua/ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename — `debugpy.lua` becomes the `debugpy` adapter, the name `:Debug run`
takes. A copy on your own runtimepath takes precedence, so a definition's `command`,
profiles, and defaults can be customised by editing the local file directly. Installed
definitions are not updated automatically.

## Available adapters

ezdap.nvim itself ships only a generic `remote` definition; every language-specific one is
published here. Each row lists the profiles a definition offers and the software required
to run it — the debug adapter, plus the separate debugger beneath it where there is one.

| Adapter | Language | Profiles | Needs |
| --- | --- | --- | --- |
| [`debugpy`](adapters/debugpy.lua) | Python | `script` `module` `code` `attach` `remote` `listen` | any Python that can import [debugpy](https://github.com/microsoft/debugpy) — an active virtualenv, a project `.venv`, the mason `debugpy` venv, or a system `python3` |
| [`codelldb`](adapters/codelldb.lua) | C / C++ / Rust | `binary` `attach` `process_name` `core` `gdb_remote` | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH` — an adapter over LLDB, which it bundles |
| [`lldb`](adapters/lldb.lua) | C / C++ / Rust | `binary` `attach` `process_name` `core` `gdb_remote` | `lldb-dap`, LLVM's own DAP adapter for LLDB — on `PATH`, or from Xcode's toolchains on macOS |
| [`gdb`](adapters/gdb.lua) | C / C++ | `binary` `attach` `remote` | [GDB](https://sourceware.org/gdb/) 14.1+ — it is its own adapter (`gdb --interpreter=dap`) |
| [`delve`](adapters/delve.lua) | Go | `package` `test` `binary` `replay` `core` `attach` | [`dlv`](https://github.com/go-delve/delve) on `PATH`, under `$GOBIN` / `$GOPATH/bin` / `~/go/bin`, or from mason — its own adapter (`dlv dap`) |
| [`netcoredbg`](adapters/netcoredbg.lua) | .NET | `binary` `attach` | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` or from mason |
| [`java-debug-server`](adapters/java-debug-server.lua) | Java | `attach` | an already-running java-debug server, e.g. started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) |
| [`js-debug`](adapters/js-debug.lua) | JavaScript / TypeScript | `script` `attach` `remote` `browser` | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) |
| [`php-debug`](adapters/php-debug.lua) | PHP | `listen` `script` | `node`, plus the mason `php-debug-adapter` package ([vscode-php-debug](https://github.com/xdebug/vscode-php-debug)) — the debugger it fronts is [Xdebug](https://xdebug.org/), loaded into the PHP being debugged |
| [`rdbg`](adapters/rdbg.lua) | Ruby | `script` `command` `remote` | [`rdbg`](https://github.com/ruby/debug), from the `debug` gem — on `PATH`, under `$GEM_HOME/bin`, or from mason |
| [`dart`](adapters/dart.lua) | Dart / Flutter | `script` `test` `attach` `flutter` `flutter_test` `flutter_attach` | the [Dart](https://dart.dev) or [Flutter](https://flutter.dev) SDK on `PATH`, or under `$DART_SDK` / `$FLUTTER_ROOT` — the adapters ship inside it and front the VM Service, so there is nothing else to install |
| [`bash-debug-adapter`](adapters/bash-debug-adapter.lua) | Bash | `script` | `bash-debug-adapter` on `PATH` ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)) — the debugger it fronts is bashdb, from mason, `$BASHDB_HOME`, or `/usr/share/bashdb` |
| [`local-lua-debugger`](adapters/local-lua-debugger.lua) | Lua | `script` `executable` | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) |

Profile names are short and say what they run: `binary`, `script`, `package` and the
other launch profiles start a new process, `attach` / `process_name` / `remote` /
`gdb_remote` / `listen` connect to a running one, and `core` / `replay` load a post-mortem
artifact. Every input
carries a description, so `:Debug new_run_file <adapter>` and `quick_run` completion
document the accepted fields within Neovim.

## Locating the adapter

Where a definition has paths to resolve — the adapter executable, and anything that ships
beside it — they are usually variables at the top of its file. These can be customised if
needed.

## Writing your own

An adapter definition is a single Lua file returning one `ezdap.AdapterDef`.
See [Writing an adapter definition](https://github.com/mbfoss/ezdap.nvim/blob/main/WRITING-DEFINITIONS.md).

Contributions of new definitions are welcome.
