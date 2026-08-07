-- Set to a directory to skip detection entirely; otherwise the first candidate
-- below that exists wins.
local bashdb_lib_dir = nil ---@type string?

-- Directories that may hold the bashdb library, in order. A leading "$" names an
-- environment variable, skipped when unset.
local bashdb_lib_dirs = {
    "$BASHDB_HOME",
    vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "bash-debug-adapter"),
    "/usr/local/share/bashdb",
    "/usr/share/bashdb",
}

-- External programs the adapter shells out to; each is looked up on $PATH unless
-- given as an absolute path.
local bash_tools = {
    bash   = "bash",
    bashdb = "bash-debug-adapter",
    cat    = "cat",
    mkfifo = "mkfifo",
    pkill  = "pkill",
}

---The configured bashdb library directory, or the first candidate that exists.
---@return string?
local function _resolve_lib_dir()
    if bashdb_lib_dir then return bashdb_lib_dir end
    local shared = require("ezdap.shared")
    return (shared.resolve_path(bashdb_lib_dirs, shared.is_directory))
end

---@type ezdap.AdapterDef
return {
    command  = bash_tools.bashdb,
    profiles = {
        -- `quick_run bash-debug-adapter bash_script script=./run.sh`.
        bash_script = {
            description = "debug a bash script",
            request = "launch",
            inputs = {
                script        = { type = "string", format = "file", description = "bash script to debug" },
                cwd           = { type = "string", format = "dir", description = "working directory" },
                env           = { type = "table", format = "map", description = "environment variables" },
                terminal_kind = { type = "string", choices = { "integrated", "external", "debugConsole" }, description = "where the debuggee's stdio goes (default integrated)" },
            },
            build = function(params, _, inputs)
                params.type          = "bashdb"
                params.name          = "Launch Bash Script"
                params.program       = inputs.script
                params.cwd           = inputs.cwd
                params.env           = inputs.env
                params.pathBash      = bash_tools.bash
                params.pathBashdb    = bash_tools.bashdb
                params.pathBashdbLib = _resolve_lib_dir()
                params.pathCat       = bash_tools.cat
                params.pathMkfifo    = bash_tools.mkfifo
                params.pathPkill     = bash_tools.pkill
                params.terminalKind  = inputs.terminal_kind or "integrated"
            end,
        },
    },
}
