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
    modes = {
        -- `quick_run bash-debug-adapter script script=./run.sh`.
        script = {
            description = "debug a bash script",
            request = "launch",
            inputs = {
                script        = { type = "string", format = "file", description = "bash script to debug" },
                cwd           = { type = "string", format = "dir", description = "working directory" },
                env           = { type = "map", description = "environment variables" },
                terminal_kind = { type = "string", choices = { "integrated", "external", "debugConsole" }, description = "where the debuggee's stdio goes (default integrated)" },
            },
            build = function(inputs)
                return {
                    type          = "bashdb",
                    name          = "Launch Bash Script",
                    program       = inputs.script,
                    cwd           = inputs.cwd,
                    env           = inputs.env,
                    pathBash      = bash_tools.bash,
                    pathBashdb    = bash_tools.bashdb,
                    pathBashdbLib = _resolve_lib_dir(),
                    pathCat       = bash_tools.cat,
                    pathMkfifo    = bash_tools.mkfifo,
                    pathPkill     = bash_tools.pkill,
                    terminalKind  = inputs.terminal_kind or "integrated",
                }
            end,
        },
    },
}
