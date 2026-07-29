-- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html

local shared = require("ezdap.shared")

local GDB = "gdb"

-- `coreFile` is a post-17.2 addition to gdb's DAP attach: an older gdb drops it
-- and fails the attach with the unhelpful "attach requires either 'pid' or
-- 'target'", so the `core` profile checks the version up front instead.
local CORE_MIN = { 17, 2 } -- exclusive: 17.2 itself is too old

---gdb's version as `{major, minor}`, parsed from the tail of `gdb --version`'s
---first line ("GNU gdb (GDB) 17.2", "GNU gdb (Ubuntu 12.1-0ubuntu1~22.04) 12.1").
---Cached: a `gdb` on $PATH does not change version mid-session.
---@type integer[]?
local _version
---@return integer[]? version, string? err
local function _gdb_version()
    if _version then return _version end
    if vim.fn.executable(GDB) == 0 then return nil, GDB .. " not found" end
    local out = vim.fn.system({ GDB, "--version" })
    if vim.v.shell_error ~= 0 then return nil, "`gdb --version` failed: " .. vim.trim(out) end
    -- The trailing "\n" anchors the match to the *end* of the first line, past any
    -- version-shaped noise in a distro's parenthesised build string; it is appended
    -- in case the output has none of its own.
    local major, minor = (out .. "\n"):match("^[^\n]-(%d+)%.(%d+)[^%s]*%s*\n")
    if not major then return nil, "could not parse gdb version from: " .. vim.trim(vim.split(out, "\n")[1] or "") end
    _version = { tonumber(major), tonumber(minor) }
    return _version
end

---@param v integer[]
---@param min integer[]
---@return boolean
local function _newer_than(v, min)
    if v[1] ~= min[1] then return v[1] > min[1] end
    return v[2] > min[2]
end

---@type ezdap.AdapterDef
return {
    command = { GDB, "--interpreter=dap" },
    setup = function (config, ctx, callback)
        callback()
    end,
    profiles       = {
        -- One `command` input carries the whole command line; `build` splits it into
        -- GDB's `program` (the first word) and `args` (the rest).
        launch_program = {
            description = "debug a native executable",
            request = "launch",
            inputs = {
                command       = { type = "string", format = "command", required = true, description = "command line to debug" },
                cwd           = { type = "string", format = "cwd", description = "working directory" },
                env           = { type = "table", format = "map", description = "environment variables" },
                stop_on_entry = { type = "boolean", description = "break at program entry" },
                stop_at_main  = { type = "boolean", description = "break at the start of main" },
                ada_charset   = { type = "string", description = "Ada source character set" },
            },
            build = function(params, _, inputs)
                params.program, params.args = shared.split_command(inputs.command)
                params.cwd     = inputs.cwd
                params.env     = vim.tbl_extend("force", vim.fn.environ(), inputs.env or {}) -- gdb does not merge env variables on it's own (unlike lldb)
                params.stopOnEntry = inputs.stop_on_entry
                params.stopAtBeginningOfMainSubprogram = inputs.stop_at_main
                params.adaSourceCharset = inputs.ada_charset
            end,
        },
        attach_process = {
            description = "attach to a running process by pid",
            request    = "attach",
            inputs = {
                pid    = { type = "integer", description = "process id to attach to" },
                program = { type = "string", format = "file", description = "local binary for symbols" },
            },
            build = function(params, _, inputs)
                local pid, err = shared.resolve_pid(inputs.pid)
                if not pid then return err end
                params.pid     = pid
                params.program = inputs.program
            end,
        },
        -- GDB's body `target` key is the remote connection string, not a binary.
        remote = {
            description = "connect to a gdbserver / remote target",
            request    = "attach",
            inputs = {
                connection = { type = "string", required = true, description = "remote target, e.g. host:port" },
                program    = { type = "string", format = "file", description = "local binary for symbols" },
            },
            build = function(params, _, inputs)
                params.target  = inputs.connection
                params.program = inputs.program
            end,
        },
        -- Use the `lldb` or `codelldb` adapter's `core` profile on a gdb too old
        -- for `coreFile` (see CORE_MIN).
        core = {
            description = "post-mortem debug from a core file (needs gdb newer than 17.2)",
            request    = "attach",
            inputs = {
                corefile = { type = "string", format = "file", required = true, description = "core file to load" },
                program  = { type = "string", format = "file", description = "executable that produced the core" },
            },
            build = function(params, _, inputs)
                local version, err = _gdb_version()
                if not version then return err end
                if not _newer_than(version, CORE_MIN) then
                    return ("core files need a gdb newer than %d.%d (found %d.%d); use the lldb or codelldb adapter's core profile")
                        :format(CORE_MIN[1], CORE_MIN[2], version[1], version[2])
                end
                params.coreFile = inputs.corefile
                params.program  = inputs.program
            end,
        },
    },
}
