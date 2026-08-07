# ezdap-adapters

A registry of ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim).

Each file is a self-contained Lua module defining the configuration profiles for one
debugger: how its adapter is started or connected to, and the launch and attach profiles
it supports. Profile inputs are self-describing, so ezdap.nvim can prompt for them and
validate them. Adapters are installed individually, as needed.

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
" one-off session: adapter, profile, and the profile's inputs as key=value
:Debug run debugpy launch_program command=./main.py

" or write a reusable run file for the adapter
:Debug new_run_file debugpy

" verify the adapter and its debugger are found
:checkhealth ezdap
```

ezdap.nvim globs `lua/ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename — `debugpy.lua` becomes the `debugpy` adapter. A copy on your own
runtimepath takes precedence, so an adapter's `command`, profiles, and defaults can be
customised by editing the local file directly. Installed adapters are not updated automatically.

## Available adapters

ezdap.nvim itself ships only a generic `remote` adapter; every debugger-specific adapter
is published here. Each row lists the profiles an adapter defines and the software
required to run it.

| Adapter | Language | Profiles | Needs |
| --- | --- | --- | --- |
| [`debugpy`](adapters/debugpy.lua) | Python | `launch_program` `launch_module` `launch_code` `attach_process` `remote` `listen` | any Python that can import [debugpy](https://github.com/microsoft/debugpy) — an active virtualenv, a project `.venv`, the mason `debugpy` venv, or a system `python3` |
| [`codelldb`](adapters/codelldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH` |
| [`lldb`](adapters/lldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | `lldb-dap`, LLVM's native DAP adapter — on `PATH`, or from Xcode's toolchains on macOS |
| [`gdb`](adapters/gdb.lua) | C / C++ | `launch_program` `attach_process` `remote` `core` | [GDB](https://sourceware.org/gdb/) 14.1+, for the DAP interface (`gdb --interpreter=dap`); `core` needs newer than 17.2 |
| [`delve`](adapters/delve.lua) | Go | `launch_program` `launch_test` `launch_exec` `replay` `core` `attach_process` | [`dlv`](https://github.com/go-delve/delve) on `PATH`, under `$GOBIN` / `$GOPATH/bin` / `~/go/bin`, or from mason |
| [`netcoredbg`](adapters/netcoredbg.lua) | .NET | `launch_program` `attach_process` | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` or from mason |
| [`java-debug-server`](adapters/java-debug-server.lua) | Java | `attach_server` | an already-running java-debug server, e.g. started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) |
| [`js-debug`](adapters/js-debug.lua) | JavaScript / TypeScript | `launch_program` `attach_process` `remote` `launch_browser` | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) |
| [`bash-debug-adapter`](adapters/bash-debug-adapter.lua) | Bash | `bash_script` | `bash-debug-adapter` on `PATH`, plus the bashdb library — from mason, `$BASHDB_HOME`, or `/usr/share/bashdb` ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)) |
| [`local-lua-debugger`](adapters/local-lua-debugger.lua) | Lua | `launch_program` `launch_command` | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) |

Profile names follow a common convention: `launch_*` starts a new process, `attach_*`
connects to a running one, and `core` / `replay` load a post-mortem artifact. Every input
carries a description, so `:Debug new_run_file <adapter>` and `quick_run` completion
document the accepted fields within Neovim.

## Locating the debugger

Where an adapter has paths to resolve, they are usually variables at the top of its file. these can be customised if needed.

## Writing your own

Each file returns one `ezdap.AdapterDef`:

```lua
return {
    command  = { "gdb", "--interpreter=dap" }, -- stdio adapter; or host/port to connect
    setup    = function(config, ctx, callback) end, -- optional, see below
    profiles = {
        launch_program = {
            description = "debug a native executable",
            request     = "launch", -- or "attach"
            inputs      = {
                command = { type = "string", format = "command", required = true, description = "command line to debug" },
            },
            build       = function(params, _, inputs) -- inputs -> DAP body
                params.program, params.args = require("ezdap.shared").split_command(inputs.command)
            end,
        },
    },
}
```

`setup` runs before the session. Use it to start a debug server and report its port
(debugpy, delve, js-debug), or to locate a binary and fail with a readable message. Return
errors through `callback("...")`. `teardown` stops what `setup` started.

`ezdap.shared` helps: `split_command`, `resolve_pid`, `spawn`, and
`resolve_path(candidates, accept, opts?)` — which expands `$VAR` and `~` and returns the
first candidate `accept` approves, plus everything tried:

```lua
local shared = require("ezdap.shared")
local exe, tried = shared.resolve_path({ "dlv", "$GOBIN/dlv" }, shared.is_executable)
```

Use `shared.is_directory` for directories, your own predicate when working means more than
present (`gdb.lua` checks the version), and `opts.transform` to test a file inside a found
directory (`debugpy.lua` maps a venv to its `bin/python`).

Templates: [`bash-debug-adapter.lua`](adapters/bash-debug-adapter.lua) is the smallest,
[`netcoredbg.lua`](adapters/netcoredbg.lua) adds a binary lookup,
[`debugpy.lua`](adapters/debugpy.lua) shows shared input groups and a spawned server. The
full contract is in the `ezdap.AdapterDef` and `ezdap.Profile` annotations in
`lua/ezdap/adapters/init.lua`.

Contributions of new adapters are welcome. Please follow the structure and comment style
of the existing files, and cite the upstream documentation the field set is based on at
the top of the file.
