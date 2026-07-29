# ezdap-adapters

A registry of ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim).

Each file is a self-contained Lua module defining the configuration profiles for one
debugger: how its adapter is started or connected to, and the launch and attach profiles
it supports. Profile inputs are self-describing, so ezdap.nvim can prompt for them and
validate them. Adapters are installed individually, as needed.

## Requirements

- Neovim with [ezdap.nvim](https://github.com/mbfoss/ezdap.nvim) installed.
- The debugger itself, on `PATH` or installed via [mason.nvim](https://github.com/mason-org/mason.nvim).
  See [Available adapters](#available-adapters) for what each one needs.

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
:Debug quick_run debugpy launch_program command=./main.py

" or write a reusable run file for the adapter
:Debug new_run_file debugpy

" verify the adapter and its debugger are found
:checkhealth ezdap
```

ezdap.nvim globs `lua/ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename — `debugpy.lua` becomes the `debugpy` adapter. A copy on your own
runtimepath takes precedence, so an adapter's `command`, profiles, and defaults can be
customised by editing the local file directly. Installed adapters are not updated
automatically; re-run the `curl` command to obtain a newer revision.

## Available adapters

ezdap.nvim itself ships only the generic `remote` adapter; every debugger-specific adapter
is published here. Each row lists the profiles an adapter defines and the software
required to run it.

| Adapter | Language | Profiles | Needs |
| --- | --- | --- | --- |
| [`debugpy`](adapters/debugpy.lua) | Python | `launch_program` `launch_module` `launch_code` `attach_process` `remote` `listen` | [debugpy](https://github.com/microsoft/debugpy) importable by a Python on `PATH` (or the mason `debugpy` venv) |
| [`codelldb`](adapters/codelldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH` |
| [`lldb`](adapters/lldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | `lldb-dap`, LLVM's native DAP adapter |
| [`gdb`](adapters/gdb.lua) | C / C++ | `launch_program` `attach_process` `remote` `core` | [GDB](https://sourceware.org/gdb/) 14.1+, for the DAP interface (`gdb --interpreter=dap`); `core` needs newer than 17.2 |
| [`delve`](adapters/delve.lua) | Go | `launch_program` `launch_test` `launch_exec` `replay` `core` `attach_process` | [`dlv`](https://github.com/go-delve/delve) on `PATH` |
| [`netcoredbg`](adapters/netcoredbg.lua) | .NET | `launch_program` `attach_process` | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` |
| [`java-debug-server`](adapters/java-debug-server.lua) | Java | `attach_server` | an already-running java-debug server, e.g. started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) |
| [`js-debug`](adapters/js-debug.lua) | JavaScript / TypeScript | `launch_program` `attach_process` `remote` `launch_browser` | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) |
| [`bash-debug-adapter`](adapters/bash-debug-adapter.lua) | Bash | `bash_script` | the mason `bash-debug-adapter` package ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)) |
| [`local-lua-debugger`](adapters/local-lua-debugger.lua) | Lua | `launch_program` `launch_command` | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) |

Adapters that reference a mason package resolve it under
`stdpath("data")/mason/packages/…`. For debuggers installed by other means, adjust the
path in your local copy accordingly.

Profile names follow a common convention: `launch_*` starts a new process, `attach_*`
connects to a running one, and `core` / `replay` load a post-mortem artifact. Every input
carries a description, so `:Debug new_run_file <adapter>` and `quick_run` completion
document the accepted fields within Neovim.

## Writing your own

Each file returns a single `ezdap.AdapterDef`:

- **The adapter connection** — `command` for a stdio adapter (`"codelldb"`,
  `{ "gdb", "--interpreter=dap" }`), or `host`/`port` for an adapter that is connected to.
  Adapters requiring a server to be started first (debugpy, delve, js-debug) implement
  `setup`, which spawns the debug server process, parses the port it reports, and completes the
  connection details; `teardown` stops it at the end of the session.
- **`profiles`** — a table of launch and attach descriptions. Each profile declares its
  `request` (`"launch"` or `"attach"`), an `inputs` table typing and describing every
  field it accepts, and a `build` function that converts those inputs into the DAP
  configuration body the debugger expects.

The existing files serve as templates: [`gdb.lua`](adapters/gdb.lua) is the smallest
complete example, and [`debugpy.lua`](adapters/debugpy.lua) demonstrates shared input
groups alongside a spawned adapter process. For the full contract, refer to the
`ezdap.AdapterDef` and `ezdap.Profile` annotations in `lua/ezdap/adapters/init.lua` in
ezdap.nvim.

Contributions of new adapters are welcome. Please follow the structure and comment style
of the existing files, and cite the upstream documentation the field set is based on at
the top of the file.
