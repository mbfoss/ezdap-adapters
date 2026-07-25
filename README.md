# ezdap-adapters

A registry of ready-made DAP adapter definitions for
[ezdap.nvim](https://github.com/mbfoss/ezdap.nvim). 

Each file define configuration profiles for a specific debugger.

## Requirements

- ezdap.nvim installed and on your Neovim runtimepath. The adapter files
  `require("ezdap.shared")` and `require("ezdap.util.ui_util")`, which are provided by
  the plugin.

## Install an adapter

Copy the adapter file you want into your own config under
`~/.config/nvim/lua/ezdap-adapters/` (create that directory if it doesn't exist):

```sh
mkdir -p ~/.config/nvim/lua/ezdap-adapters
curl -o ~/.config/nvim/lua/ezdap-adapters/debugpy.lua \
  https://raw.githubusercontent.com/mbfoss/ezdap-adapters/main/adapters/debugpy.lua
```

Restart Neovim (or `:source` the file). ezdap.nvim globs
`lua/ezdap-adapters/*.lua` on the runtimepath and registers each file under its
filename — so `debugpy.lua` becomes the `debugpy` adapter. Then:

```
:Debug quick_run debugpy <profile> program=./main.py
:Debug new_run_file debugpy
:checkhealth ezdap
```

Adjust an adapter's `command` (or any other field) by editing your local copy; your
copy always wins.

## Available adapters

| File | Debugger |
| --- | --- |
| `adapters/debugpy.lua` | Python — [debugpy](https://github.com/microsoft/debugpy) |
| `adapters/codelldb.lua` | C / C++ / Rust — [CodeLLDB](https://github.com/vadimcn/codelldb) |
| `adapters/lldb.lua` | C / C++ / Rust — `lldb-dap` (LLVM's native DAP adapter) |
| `adapters/gdb.lua` | C / C++ — [GDB](https://sourceware.org/gdb/) DAP interface |
| `adapters/delve.lua` | Go — [Delve](https://github.com/go-delve/delve) |
| `adapters/netcoredbg.lua` | .NET — [netcoredbg](https://github.com/Samsung/netcoredbg) |
| `adapters/java-debug-server.lua` | Java — external java-debug server (e.g. nvim-jdtls) |
| `adapters/js-debug.lua` | JavaScript / TypeScript — [js-debug](https://github.com/microsoft/vscode-js-debug) |
| `adapters/bash-debug-adapter.lua` | Bash — [bash-debug](https://github.com/rogalmic/vscode-bash-debug) |
| `adapters/local-lua-debugger.lua` | Lua — [local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode) |

## Writing your own

Each file returns a single `ezdap.AdapterDef` — native process/connection config plus a
`profiles` table of self-describing launch/attach descriptions. Use these files as
templates; see the `ezdap.AdapterDef` / `ezdap.Profile` annotations in
`lua/ezdap/adapters/init.lua` in ezdap.nvim for the full contract.
