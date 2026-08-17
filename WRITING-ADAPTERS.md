# Writing an adapter

An adapter is a single Lua file under `lua/ezdap-adapters/` on the runtimepath, registered
under its filename — `debugpy.lua` becomes the `debugpy` adapter, the name `:Debug run`
takes. It is configuration only: it says how to reach the debugger — the program that
actually speaks DAP, such as `codelldb` or `gdb --interpreter=dap` — and what that debugger
can be asked to do. Each file returns one `ezdap.AdapterDef`:

```lua
return {
    command  = { "gdb", "--interpreter=dap" }, -- how to spawn the debugger; or host/port to connect
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

## `ezdap.AdapterDef`

The table an adapter file returns. Every field is optional; what is set decides how the
debugger is reached and what it can run.

| Field | Type | Meaning |
| --- | --- | --- |
| `command` | `string` \| `string[]` | The debugger process to spawn, spoken to over stdio. A string is split on shell whitespace, so `"python3 -m debugpy"` works; a list is used verbatim. A missing executable is reported before the session starts. |
| `host` | `string` | Host of an already-running debugger to connect to instead of spawning one. Defaults to `127.0.0.1`. |
| `port` | `integer` | Port to connect to. **Setting a port selects TCP**: with a port, `command` is not spawned and ezdap dials `host:port`, retrying for ~3s. Adapters whose `setup` starts a server (debugpy, delve, js-debug) set this from `setup`. |
| `cwd` | `string` | Working directory for the spawned debugger. Defaults to Neovim's cwd. |
| `env` | `table<string,string>` | Environment for the spawned debugger — the debugger's own environment, not the debuggee's (`local-lua-debugger.lua` sets `LUA_PATH` this way). |
| `type` | `string` | DAP `adapterID` override. Defaults to the adapter's name, i.e. the filename stem. |
| `defer_launch_attach` | `boolean` | Send `launch`/`attach` after `configurationDone` rather than straight after `initialize`, for debuggers that require that order. |
| `profiles` | `table<string, ezdap.Profile>` | The named profiles this adapter offers, keyed by the name `:Debug run <adapter> <profile>` takes. |
| `setup` | `fun(config, ctx, callback)` | Runs before the session; see below. |
| `teardown` | `fun(config, state)` | Runs after the session, with whatever `setup` passed as its `state`. |

An `ezdap.Profile` is one runnable configuration:

| Field | Type | Meaning |
| --- | --- | --- |
| `description` | `string` | A line shown in pickers and `:Debug new_run_file` output. |
| `request` | `"launch"` \| `"attach"` | Which DAP request the profile issues. |
| `inputs` | `table<string, ezdap.Input>` | What the user is asked for, keyed by the name used as `key=value` on the command line. |
| `build` | `fun(params, connect, inputs): string?` | Turns answered inputs into the DAP request body. Mutates `params` (the body) and `connect` (`host`/`port`, overriding the adapter's own) in place. Return a string to abort with that error. It runs in a coroutine, so it may yield — a `vim.ui.select` picker inside `build` is fine. |

An `ezdap.Input` describes one value:

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | `"string"` \| `"boolean"` \| `"integer"` \| `"number"` \| `"list"` \| `"map"` | What the value is. Defaults to `string`. `list` is a table of entries, `map` a table of `key=value` entries. |
| `format` | `"file"` \| `"dir"` \| `"command"` \| `"port"` | Narrows `type` — normalizes paths, range-checks a port, completes a command line's tokens as paths. Each format extends one type; naming a format under a type it doesn't extend is an error. |
| `item_type` / `item_format` | as above | The same two fields for the *entries* of a `list` or `map`. |
| `required` | `boolean` | Leaving it unset is an error. Defaults to `false`. |
| `choices` | `string[]` | Suggested values, offered in completion. |
| `description` | `string` | A few words on what the input means — this is what `:Debug new_run_file` and `quick_run` completion show. |

## Setup and teardown

`setup` runs before the session. Use it to start the debugger as a server and report its
port (debugpy, delve, js-debug), or to locate its binary and fail with a readable
message. Return errors through `callback("...")`. Pass state as the second argument —
`callback(nil, { handle = h })` — and it arrives as `teardown`'s second argument, which is
how `teardown` stops what `setup` started. `setup` may edit `config` in place (setting
`config.port` after picking a free one is the usual case), and its `ctx` carries
`report(msg)` for progress lines, `add_bufnr(bufnr, opts?)` to attach a buffer it created
to the run, and `profile` — the profile name this run resolved from, or `nil` for a raw run
file, so a `setup` can gate one profile rather than the whole adapter.

## Helpers

Locating the debugger is most of what an adapter does before it can run, so
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

## Templates

[`bash-debug-adapter.lua`](adapters/bash-debug-adapter.lua) is the smallest,
[`netcoredbg.lua`](adapters/netcoredbg.lua) adds a binary lookup,
[`debugpy.lua`](adapters/debugpy.lua) shows shared input groups and a spawned server. The
full contract is in the `ezdap.AdapterDef` and `ezdap.Profile` annotations in
`lua/ezdap/adapters.lua`.

Contributions of new adapters are welcome. Please follow the structure and comment style
of the existing files, and cite the debugger's own documentation that the field set is
based on at the top of the file.
