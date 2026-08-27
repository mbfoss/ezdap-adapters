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
:Debug adapter_info debugpy

" one-off session: adapter, mode, and the mode's inputs as key=value
:Debug run debugpy script command=./main.py

" or write a reusable run file for it
:Debug new_run_file debugpy
```

### A single definition instead <!-- tag: single-definition -->

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

## Available adapters <!-- tag: adapters -->

ezdap.nvim itself ships only a generic `remote` definition; every language-specific one is
published here. Each section below covers one definition on its own: the software required
to run it — the debug adapter, plus the separate debugger beneath it where there is one —
and the modes it offers.

**What each mode takes is not repeated here.** The definitions describe their own inputs, so
Neovim answers that from the file itself:

```vim
:Debug adapter_info debugpy         " every mode, with its inputs and their types
:Debug adapter_info debugpy script  " just that mode
```

See [`:Debug adapter_info`](https://github.com/mbfoss/ezdap.nvim#debug-adapter_info), help
tag |ezdap-adapter-info|. The same descriptions reach you while typing: completion after
`:Debug run <adapter> <mode> ` lists the mode's inputs, and `:Debug new_run_file <adapter>
<mode>` writes them all out, commented. A definition you copy and edit documents itself the
same way, which no listing here could.

Mode names are short and say what they run: `binary`, `script`, `package` and the other
launch modes start a new process, `attach` / `process_name` / `remote` / `gdb_remote` /
`listen` connect to a running one, and `core` / `replay` load a post-mortem artifact.

### `debugpy` (Python) <!-- tag: debugpy -->

[`lua/ezdap-adapters/debugpy.lua`](lua/ezdap-adapters/debugpy.lua). Needs any Python that can
import [debugpy](https://github.com/microsoft/debugpy). The definition looks for one in the
active virtualenv, `$CONDA_PREFIX`, a project `.venv` or `venv`, the mason `debugpy` venv, then
a system `python3` / `python`.

- **`attach`** *(attach)* — attach to a running process by pid
- **`code`** *(launch)* — debug a snippet of Python source, as `python -c`
- **`listen`** *(attach)* — wait for a debugpy process to connect back on host/port
- **`module`** *(launch)* — debug a module, as `python -m`
- **`remote`** *(attach)* — attach to a remote debugpy process over host/port
- **`script`** *(launch)* — debug a Python file

### `codelldb` (C / C++ / Rust) <!-- tag: codelldb -->

[`lua/ezdap-adapters/codelldb.lua`](lua/ezdap-adapters/codelldb.lua). Needs
[`codelldb`](https://github.com/vadimcn/codelldb) on `PATH`. It is an adapter over LLDB, which
it bundles, so there is no separate debugger to install.

- **`attach`** *(attach)* — attach to a running process by pid
- **`binary`** *(launch)* — debug an executable
- **`core`** *(launch)* — post-mortem debug from a core file (custom launch)
- **`gdb_remote`** *(launch)* — attach over a gdb-remote (gdbserver) connection (custom launch)
- **`process_name`** *(attach)* — attach to a process by executable, optionally waiting for it to launch

### `lldb` (C / C++ / Rust) <!-- tag: lldb -->

[`lua/ezdap-adapters/lldb.lua`](lua/ezdap-adapters/lldb.lua). Needs `lldb-dap`, LLVM's own DAP
adapter for LLDB, on `PATH` or from Xcode's toolchains on macOS.

- **`attach`** *(attach)* — attach to a running process by pid
- **`binary`** *(launch)* — debug an executable
- **`core`** *(attach)* — post-mortem debug from a core file
- **`gdb_remote`** *(attach)* — attach over a gdb-remote (gdbserver) connection
- **`process_name`** *(attach)* — attach to a process by executable, optionally waiting for it to launch

### `gdb` (C / C++) <!-- tag: gdb -->

[`lua/ezdap-adapters/gdb.lua`](lua/ezdap-adapters/gdb.lua). Needs
[GDB](https://sourceware.org/gdb/) 14.1 or newer; it is its own adapter, driven as `gdb
--interpreter=dap`.

- **`attach`** *(attach)* — attach to a running process by pid
- **`binary`** *(launch)* — debug a native executable
- **`core`** *(attach)* — post-mortem debug from a core file (needs gdb newer than 17.2)
- **`remote`** *(attach)* — connect to a gdbserver / remote target

### `delve` (Go) <!-- tag: delve -->

[`lua/ezdap-adapters/delve.lua`](lua/ezdap-adapters/delve.lua). Needs
[`dlv`](https://github.com/go-delve/delve) on `PATH`, under `$GOBIN` / `$GOPATH/bin` /
`~/go/bin`, or from mason. It is its own adapter, driven as `dlv dap`.

- **`attach`** *(attach)* — attach to a running process by pid
- **`binary`** *(launch)* — debug a pre-built Go binary
- **`core`** *(launch)* — post-mortem debug from a core dump
- **`package`** *(launch)* — build and debug a Go package/binary
- **`replay`** *(launch)* — replay an rr trace recording
- **`test`** *(launch)* — build and debug a Go test package

### `netcoredbg` (.NET) <!-- tag: netcoredbg -->

[`lua/ezdap-adapters/netcoredbg.lua`](lua/ezdap-adapters/netcoredbg.lua). Needs
[`netcoredbg`](https://github.com/Samsung/netcoredbg) on `PATH` or from mason.

- **`attach`** *(attach)* — attach to a running process by pid
- **`binary`** *(launch)* — debug a .NET assembly

### `java-debug-server` (Java) <!-- tag: java-debug-server -->

[`lua/ezdap-adapters/java-debug-server.lua`](lua/ezdap-adapters/java-debug-server.lua). Needs
an already-running java-debug server, e.g. one started by
[nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls). This definition only connects to it,
so there is nothing for it to start.

- **`attach`** *(attach)* — attach to an external java-debug server (e.g. via nvim-jdtls)

### `js-debug` (JavaScript / TypeScript) <!-- tag: js-debug -->

[`lua/ezdap-adapters/js-debug.lua`](lua/ezdap-adapters/js-debug.lua). Needs `node`, plus the
mason `js-debug-adapter` package ([js-debug](https://github.com/microsoft/vscode-js-debug)).

- **`attach`** *(attach)* — attach to a running process by pid
- **`browser`** *(launch)* — launch a Chromium browser and debug a page
- **`remote`** *(attach)* — attach to a remote Node.js process over host/port
- **`script`** *(launch)* — debug a Node.js/JS/TS file

### `php-debug` (PHP) <!-- tag: php-debug -->

[`lua/ezdap-adapters/php-debug.lua`](lua/ezdap-adapters/php-debug.lua). Needs `node`, plus the
mason `php-debug-adapter` package
([vscode-php-debug](https://github.com/xdebug/vscode-php-debug)). The debugger it fronts is
[Xdebug](https://xdebug.org/), loaded into the PHP being debugged.

- **`listen`** *(launch)* — wait for Xdebug to connect back on a port
- **`script`** *(launch)* — run a PHP script under Xdebug

### `rdbg` (Ruby) <!-- tag: rdbg -->

[`lua/ezdap-adapters/rdbg.lua`](lua/ezdap-adapters/rdbg.lua). Needs
[`rdbg`](https://github.com/ruby/debug), from the `debug` gem, on `PATH`, under
`$GEM_HOME/bin`, or from mason.

- **`command`** *(attach)* — debug a Ruby command — rspec, rake, ruby itself
- **`remote`** *(attach)* — attach to an rdbg server already listening on host/port
- **`script`** *(attach)* — debug a Ruby script

### `dart` (Dart / Flutter) <!-- tag: dart -->

[`lua/ezdap-adapters/dart.lua`](lua/ezdap-adapters/dart.lua). Needs the
[Dart](https://dart.dev) or [Flutter](https://flutter.dev) SDK on `PATH`, or under `$DART_SDK`
/ `$FLUTTER_ROOT`. The adapters ship inside the SDK and front the VM Service, so there is
nothing else to install.

- **`attach`** *(attach)* — attach to a running Dart VM Service
- **`flutter`** *(launch)* — debug a Flutter app on a device
- **`flutter_attach`** *(attach)* — attach to a running Flutter app
- **`flutter_test`** *(launch)* — debug a Flutter test suite
- **`script`** *(launch)* — debug a Dart program
- **`test`** *(launch)* — debug a Dart test suite

### `bash-debug-adapter` (Bash) <!-- tag: bash-debug-adapter -->

[`lua/ezdap-adapters/bash-debug-adapter.lua`](lua/ezdap-adapters/bash-debug-adapter.lua). Needs
`bash-debug-adapter` on `PATH` ([bash-debug](https://github.com/rogalmic/vscode-bash-debug)).
The debugger it fronts is bashdb, taken from mason, `$BASHDB_HOME`, `/usr/local/share/bashdb`,
or `/usr/share/bashdb`.

- **`script`** *(launch)* — debug a bash script

### `local-lua-debugger` (Lua) <!-- tag: local-lua-debugger -->

[`lua/ezdap-adapters/local-lua-debugger.lua`](lua/ezdap-adapters/local-lua-debugger.lua). Needs
`node`, plus the mason `local-lua-debugger-vscode` package
([local-lua-debugger](https://github.com/tomblind/local-lua-debugger-vscode)).

- **`executable`** *(launch)* — debug a custom executable that embeds Lua
- **`script`** *(launch)* — debug a Lua script

## Locating the adapter <!-- tag: locating -->

Where a definition has paths to resolve (the adapter executable, and anything that ships
beside it), they are usually variables at the top of its file. These can be customised if
needed. With the plugin installed, change a definition by copying it into
`~/.config/nvim/lua/ezdap-adapters/` and editing it there.

## Writing your own <!-- tag: writing -->

An adapter definition is a single Lua file returning one `ezdap.AdapterDef`.
See [Writing an adapter
definition](https://github.com/mbfoss/ezdap.nvim/blob/main/WRITING-DEFINITIONS.md).

Contributions of new definitions are welcome.
