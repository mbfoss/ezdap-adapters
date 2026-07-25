# ezdap-adapters

A registry of ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim).

ezdap.nvim ships only the generic `remote` adapter. Every debugger-specific adapter lives
here and is downloaded one file at a time, as you need it — no bundled config for
languages you don't debug, and no upstream release to wait on when a field changes.

Each file is a single self-contained Lua module describing one debugger: how to start it,
and a set of **profiles** (launch a program, attach to a pid, load a core file, …) whose
inputs are self-describing, so ezdap.nvim can prompt you for them and validate them.

## Requirements

- Neovim with [ezdap.nvim](https://github.com/mbfoss/ezdap.nvim) installed and on your
  runtimepath. Adapter files `require("ezdap.shared")` and `require("ezdap.util.ui_util")`,
  which the plugin provides.
- The debugger itself, on `PATH` or installed via [mason.nvim](https://github.com/mason-org/mason.nvim).
  See [Available adapters](#available-adapters) for what each one needs.

## Quick start

Copy the adapter you want into your own config under `~/.config/nvim/lua/ezdap-adapters/`:

```sh
mkdir -p ~/.config/nvim/lua/ezdap-adapters
curl -o ~/.config/nvim/lua/ezdap-adapters/debugpy.lua \
  https://raw.githubusercontent.com/mbfoss/ezdap-adapters/main/adapters/debugpy.lua
```

Restart Neovim (or `:source` the file), then:

```vim
" one-off session: adapter, profile, and the profile's inputs as key=value
:Debug quick_run debugpy launch_program command=./main.py

" or write a reusable run file for the adapter
:Debug new_run_file debugpy

" verify the adapter and its debugger are found
:checkhealth ezdap
```

ezdap.nvim globs `lua/ezdap-adapters/*.lua` across the runtimepath and registers each file
under its filename — `debugpy.lua` becomes the `debugpy` adapter. Because your copy is on
your own runtimepath, it always wins: change an adapter's `command`, add a profile, or
tweak a default by editing the local file. Nothing here auto-updates, so re-run the `curl`
when you want a newer version.

## Available adapters

Each row lists the profiles the adapter defines and what has to be installed for it to run.

| Adapter | Language | Profiles | Needs |
| --- | --- | --- | --- |
| [`debugpy`](adapters/debugpy.lua) | Python | `launch_program` `launch_module` `launch_code` `attach_process` `remote` `listen` | [debugpy](https://github.com/microsoft/debugpy) importable by a Python on `PATH` (or the mason `debugpy` venv) |
| [`codelldb`](adapters/codelldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | [`codelldb`](https://github.com/vadimcn/codelldb) on `PATH` |
| [`lldb`](adapters/lldb.lua) | C / C++ / Rust | `launch_program` `attach_process` `attach_by_name` `core` `gdb_remote` | `lldb-dap`, LLVM's native DAP adapter |
| [`gdb`](adapters/gdb.lua) | C / C++ | `launch_program` `attach_process` `remote` `core` | [GDB](https://sourceware.org/gdb/) built with the DAP interface (`gdb --interpreter=dap`) |
| [`delve`](adapters/delve.lua) | Go | `launch_program` `launch_test` `launch_exec` `replay` `core` `attach_process` | [`dlv`](https://github.com/go-delve/delve) on `PATH` |
| [`netcoredbg`](adapters/netcoredbg.lua) | .NET | `launch_program` `attach_process` | [`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` |
| [`java-debug-server`](adapters/java-debug-server.lua) | Java | `attach_server` | an already-running java-debug server, e.g. started by [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) |
| [`js-debug`](adapters/js-debug.lua) | JavaScript / TypeScript | `launch_program` `attach_process` `remote` `launch_browser` | `node`, plus the mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)) |
| [`bash-debug-adapter`](adapters/bash-debug-adapter.lua) | Bash | `bash_script` | the mason `bash-debug-adapter` package ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)) |
| [`local-lua-debugger`](adapters/local-lua-debugger.lua) | Lua | `launch_program` `launch_command` | `node`, plus the mason `local-lua-debugger-vscode` package ([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)) |

Adapters that name a mason package look for it under `stdpath("data")/mason/packages/…`.
If you install the debugger some other way, point the path in your local copy at it.

Profile names follow a convention across adapters: `launch_*` starts a new process,
`attach_*` joins a running one, and `core` / `replay` load a post-mortem artifact. Every
profile's inputs carry a description, so `:Debug new_run_file <adapter>` and the
`quick_run` completion tell you what each one takes without leaving Neovim.

## Writing your own

Each file returns a single `ezdap.AdapterDef`:

- **How to reach the debugger** — `command` for a stdio adapter (`"codelldb"`,
  `{ "gdb", "--interpreter=dap" }`), or `host`/`port` for one you connect to. Adapters
  that need a server started first (debugpy, delve, js-debug) use `setup` to spawn it,
  parse the port it announces, and fill in the connection, with `teardown` to stop it.
- **`profiles`** — a table of launch/attach descriptions. Each profile declares its
  `request` (`"launch"` or `"attach"`), an `inputs` table typing and describing every
  field it accepts, and a `build` function that turns those inputs into the DAP
  configuration body the debugger expects.

The existing files are the intended templates — [`gdb.lua`](adapters/gdb.lua) is the
smallest complete example, [`debugpy.lua`](adapters/debugpy.lua) shows shared input groups
and a spawned adapter process. For the full contract, see the `ezdap.AdapterDef` and
`ezdap.Profile` annotations in `lua/ezdap/adapters/init.lua` in ezdap.nvim.

Contributions of new adapters are welcome — match the shape and comment style of the
existing files, and link the upstream documentation the field set follows at the top.
