# ezdap-adapters

A registry of ready-made DAP adapters for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim).

Each file is a self-contained *adapter*: a Lua module describing one debugger — how it is
started or connected to, and the launch and attach profiles it supports. An adapter is
configuration only. The debugger itself — `codelldb`, `lldb-dap`, `gdb`, `dlv` — is a
separate program you install, and the adapter says how to find and drive it. Profile
inputs are self-describing, so ezdap.nvim can prompt for them and validate them. Adapters
are installed individually, as needed.

## Requirements

- Neovim with [ezdap.nvim](https://github.com/mbfoss/ezdap.nvim) installed.
- The debugger itself, on `PATH`, installed via
  [mason.nvim](https://github.com/mason-org/mason.nvim), or in one of the usual locations
  each adapter searches - see [Locating the debugger](#locating-the-debugger).
  [Available adapters](#available-adapters) lists what each one needs.

## Quick start

Copy the adapter you want into your own config under `~/.config/nvim/lua/ezdap-adapters/`:

```sh
mkdir -p ~/.config/nvim/lua/ezdap-adapters
curl -o ~/.config/nvim/lua/ezdap-adapters/debugpy.lua \
  https://raw.githubusercontent.com/mbfoss/ezdap-adapters/main/adapters/debugpy.lua
```

Restart Neovim, then:

```vim
" verify the adapter and its debugger are found
:checkhealth ezdap

" one-off session: adapter, profile, and the profile's inputs as key=value
:Debug run debugpy launch_program command=./main.py

" or write a reusable run file for the adapter
:Debug new_run_file debugpy
```

ezdap.nvim globs `lua/ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename — `debugpy.lua` becomes the `debugpy` adapter, the name `:Debug run`
takes. A copy on your own runtimepath takes precedence, so an adapter's `command`,
profiles, and defaults can be customised by editing the local file directly. Installed
adapters are not updated automatically.

## Available adapters

ezdap.nvim itself ships only a generic `remote` adapter; every debugger-specific adapter
is published here. Each row lists the profiles an adapter defines and the software
required to run it.

| Adapter | Language | Profiles | Needs |
| --- | --- | --- | --- |
| [`debugpy`](adapters/debugpy.lua) | Python | `launch_program` `launch_module` `launch_code` `attach_process` `remote` `listen` | any Python that can import [debugpy](https://github.com/microsoft/debugpy) — an active virtualenv, a project `.venv`, the mason `debugpy` venv, or a system `python3` |
| [`codelldb`](adapters/codelldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH` |
| [`lldb`](adapters/lldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | `lldb-dap`, LLVM's native DAP interface to LLDB — on `PATH`, or from Xcode's toolchains on macOS |
| [`gdb`](adapters/gdb.lua) | C / C++ | `launch_program` `attach_process` `remote` | [GDB](https://sourceware.org/gdb/) 14.1+, for the DAP interface (`gdb --interpreter=dap`); |
| [`delve`](adapters/delve.lua) | Go | `launch_program` `launch_test` `launch_exec` `replay` `core` `attach_process` | [`dlv`](https://github.com/go-delve/delve) on `PATH`, under `$GOBIN` / `$GOPATH/bin` / `~/go/bin`, or from mason |
| [`netcoredbg`](adapters/netcoredbg.lua) | .NET | `launch_program` `attach_process` | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` or from mason |
| [`java-debug-server`](adapters/java-debug-server.lua) | Java | `attach_server` | an already-running java-debug server, e.g. started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) |
| [`js-debug`](adapters/js-debug.lua) | JavaScript / TypeScript | `launch_program` `attach_process` `remote` `launch_browser` | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) |
| [`php-debug`](adapters/php-debug.lua) | PHP | `listen` `launch_program` | `node`, plus the mason `php-debug-adapter` package ([vscode-php-debug](https://github.com/xdebug/vscode-php-debug)); the PHP being debugged needs [Xdebug](https://xdebug.org/) |
| [`rdbg`](adapters/rdbg.lua) | Ruby | `launch_program` `launch_command` `remote` | [`rdbg`](https://github.com/ruby/debug), from the `debug` gem — on `PATH`, under `$GEM_HOME/bin`, or from mason |
| [`dart`](adapters/dart.lua) | Dart / Flutter | `launch_program` `launch_test` `attach_vm_service` `launch_flutter` `launch_flutter_test` `attach_flutter` | the [Dart](https://dart.dev) or [Flutter](https://flutter.dev) SDK on `PATH`, or under `$DART_SDK` / `$FLUTTER_ROOT` — the debuggers ship inside it, so there is nothing else to install |
| [`bash-debug-adapter`](adapters/bash-debug-adapter.lua) | Bash | `bash_script` | `bash-debug-adapter` on `PATH`, plus the bashdb library — from mason, `$BASHDB_HOME`, or `/usr/share/bashdb` ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)) |
| [`local-lua-debugger`](adapters/local-lua-debugger.lua) | Lua | `launch_program` `launch_command` | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) |

Profile names follow a common convention: `launch_*` starts a new process, `attach_*`
connects to a running one, and `core` / `replay` load a post-mortem artifact. Every input
carries a description, so `:Debug new_run_file <adapter>` and `quick_run` completion
document the accepted fields within Neovim.

## Locating the debugger

Where an adapter has paths to resolve — the debugger executable, and anything that ships
beside it — they are usually variables at the top of its file. These can be customised if
needed.

## Writing your own

An adapter is a single Lua file returning one `ezdap.AdapterDef` — the field-by-field
contract, the `setup`/`teardown` lifecycle, the `ezdap.shared` helpers, and which existing
adapters make the best templates are in
[Writing an adapter](WRITING-ADAPTERS.md).

Contributions of new adapters are welcome.
