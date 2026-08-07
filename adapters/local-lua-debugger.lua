-- Lua — https://github.com/tomblind/local-lua-debugger-vscode
-- Fields follow the `lua-local` configurationAttributes in that extension's
-- package.json. `program` is a nested table the js-based adapter consumes, and is
-- a oneOf: a Lua interpreter plus an entry file, or a custom command.

-- Set to the extension directory to skip detection entirely; otherwise the first
-- candidate below that holds a debugAdapter.js wins.
local lua_debugger_dir = nil ---@type string?

-- Where to look for the unpacked extension, in order: the directory holding both
-- `extension/debugAdapter.js` (the adapter) and `debugger/` (the Lua side the
-- debuggee requires). A leading "$" names an environment variable, skipped when
-- unset; "~" expands to the home directory. A VS Code install lives in a
-- version-suffixed directory, so name that version, or set `lua_debugger_dir`.
local lua_debugger_dirs = {
    vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "local-lua-debugger-vscode", "extension"),
}

-- The Node.js that runs the adapter; `node_bin` pins one, `node_bins` is searched.
local node_bin = nil ---@type string?
local node_bins = { "node", "/usr/local/bin/node", "/usr/bin/node" }

---The js entry point inside an extension directory.
---@param dir string
---@return string
local function _adapter_js(dir) return vim.fs.joinpath(dir, "extension", "debugAdapter.js") end

---LUA_PATH for the debuggee, so its `require("lldebugger")` finds the Lua side.
---The trailing ";;" keeps the default path in place alongside it.
---@param dir string
---@return string
local function _lua_path(dir) return vim.fs.joinpath(dir, "debugger", "?.lua") .. ";;" end

---Fields both launch shapes accept, alongside their own `program` variant.
---@type table<string, ezdap.Input>
local _common_inputs = {
    cwd                 = { type = "string", format = "dir", description = "working directory" },
    env                 = { type = "table", format = "map", description = "environment variables" },
    communication       = { type = "string", choices = { "stdio", "pipe" }, description = "adapter transport" },
    script_roots        = { type = "table", format = "list", description = "alternate paths to find Lua scripts in" },
    script_files        = { type = "table", format = "list", description = "globs of scripts to debug (needed for source-mapped breakpoints)" },
    ignore_patterns     = { type = "table", format = "list", description = "Lua patterns matching scripts to skip when stepping" },
    step_unmapped_lines = { type = "boolean", description = "step into Lua when a source-mapped line has no mapping" },
    break_in_coroutines = { type = "boolean", description = "break on errors raised inside coroutines" },
    stop_on_entry       = { type = "boolean", description = "break on the first line after the debug hook is set" },
    verbose             = { type = "boolean", description = "enable verbose debugger output" },
}

---@param ... table<string, ezdap.Input>
---@return table<string, ezdap.Input>
local function _inputs(...)
    local out = vim.deepcopy(_common_inputs)
    for _, group in ipairs({ ... }) do
        out = vim.tbl_extend("error", out, vim.deepcopy(group))
    end
    return out
end

---Assigns everything outside `program`, which each profile fills in itself.
---@param params table
---@param inputs table<string, any>
local function _common_build(params, inputs)
    params.type              = "lua-local"
    params.name              = "Debug"
    params.cwd               = inputs.cwd
    params.env               = inputs.env
    params.scriptRoots       = inputs.script_roots
    params.scriptFiles       = inputs.script_files
    params.ignorePatterns    = inputs.ignore_patterns
    params.stepUnmappedLines = inputs.step_unmapped_lines
    params.breakInCoroutines = inputs.break_in_coroutines
    params.stopOnEntry       = inputs.stop_on_entry
    params.verbose           = inputs.verbose
end

---@type table<string, ezdap.Profile>
local _profiles = {
    -- One `command` input carries the whole command line; `build` splits it into
    -- the script (`program.file`) and `args` (the rest).
    launch_program = {
        description = "debug a Lua script",
        request = "launch",
        inputs = _inputs {
            command = { type = "string", format = "command", required = true, description = "script to debug, plus its arguments" },
            lua     = { type = "string", description = "Lua interpreter to run the script with (default lua)" },
        },
        build = function(params, _, inputs)
            _common_build(params, inputs)
            -- The script goes inside `program`, not beside it, so the pair is
            -- split off first rather than assigned straight to the body.
            local file, args = require("ezdap.shared").split_command(inputs.command)
            params.program = {
                lua           = inputs.lua or vim.fn.exepath("lua"),
                file          = file,
                communication = inputs.communication or "stdio",
            }
            params.args = args
        end,
    },
    -- The custom-command shape: an executable that embeds Lua drives the session
    -- itself, so there is no interpreter or entry file to name.
    launch_command = {
        description = "debug a custom executable that embeds Lua",
        request = "launch",
        inputs = _inputs {
            command = { type = "string", format = "command", required = true, description = "custom command to run, plus its arguments" },
        },
        build = function(params, _, inputs)
            _common_build(params, inputs)
            local cmd, args = require("ezdap.shared").split_command(inputs.command)
            params.program = {
                command       = cmd,
                communication = inputs.communication or "stdio",
            }
            params.args = args
        end,
    },
}

local _default_dir = lua_debugger_dir or lua_debugger_dirs[1]

---@type ezdap.AdapterDef
return {
    command  = { node_bin or node_bins[1], _adapter_js(_default_dir) },
    env      = { LUA_PATH = _lua_path(_default_dir) },
    -- The extension is a directory of js and Lua rather than a binary on $PATH, so
    -- both halves are located here — the adapter this node runs, and the LUA_PATH
    -- the debuggee needs — and a miss is reported as a plain error string.
    setup = function(config, _, callback)
        local shared = require("ezdap.shared")
        local dir, tried = shared.resolve_path(
            lua_debugger_dir and { lua_debugger_dir } or lua_debugger_dirs,
            function(cand) return vim.fn.filereadable(_adapter_js(cand)) == 1 end)
        if not dir then
            return callback("local-lua-debugger-vscode not found (install it, e.g. via mason); tried " ..
                table.concat(tried, ", "))
        end
        local node, node_tried = shared.resolve_path(
            node_bin and { node_bin } or node_bins, shared.is_executable)
        if not node then
            return callback("node not found; tried " .. table.concat(node_tried, ", "))
        end
        config.command = { node, _adapter_js(dir) }
        -- A fresh table: `config.env` is the def's own `env` above, shared by every run.
        config.env = vim.tbl_extend("force", config.env or {}, { LUA_PATH = _lua_path(dir) })
        callback()
    end,
    profiles = _profiles,
}
