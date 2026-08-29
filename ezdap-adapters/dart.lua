-- Dart / Flutter — the debug adapters built into the SDKs themselves, so there
-- is nothing to install beyond the SDK: `dart debug_adapter` and
-- `flutter debug_adapter`, each with a `--test` variant that runs the project's
-- tests and reports their progress. Which of the four a run uses is decided by
-- its mode, in `setup`.
--
-- Fields follow DartCommonLaunchAttachRequestArguments, DartLaunchRequestArguments
-- and DartAttachRequestArguments in the Dart SDK
-- (pkg/dap_adapters/lib/src/adapters/dart.dart), and FlutterLaunchRequestArguments
-- and FlutterAttachRequestArguments in flutter_tools
-- (lib/src/debug_adapters/flutter_adapter_args.dart). The Flutter adapter shares
-- the common half and defines its own launch/attach fields — no console, no VM
-- arguments; the flutter tool is configured through `tool_args` instead.

-- Set to a path to skip detection entirely; otherwise the first candidate below
-- that is executable wins. A leading "$" names an environment variable, skipped
-- when unset; "~" expands to the home directory. A bare name (no separator) is
-- looked up on $PATH.
local dart_bin = nil ---@type string?
local dart_bins = {
    "dart",
    "$DART_SDK/bin/dart",
    "$FLUTTER_ROOT/bin/dart",
    "~/flutter/bin/dart",
    "~/fvm/default/bin/dart",
    "/opt/homebrew/bin/dart",
    "/usr/local/bin/dart",
    "/usr/lib/dart/bin/dart",
}

local flutter_bin = nil ---@type string?
local flutter_bins = {
    "flutter",
    "$FLUTTER_ROOT/bin/flutter",
    "~/flutter/bin/flutter",
    "~/development/flutter/bin/flutter",
    "~/fvm/default/bin/flutter",
    "/opt/homebrew/bin/flutter",
    "/usr/local/bin/flutter",
}

-- The subcommand that starts the adapter. Both SDKs renamed it to
-- `debug-adapter` and kept `debug_adapter` as an alias, which is the spelling
-- every SDK old enough to have the command at all understands.
local dap_subcommand = "debug_adapter"

---Which tool each mode's adapter comes from, and whether it is the test
---variant. A mode is the only thing that decides this: the four adapters are
---separate programs, not options on one body.
---@type table<string, { flutter?: boolean, test?: boolean }>
local _tool_of = {
    script         = {},
    test           = { test = true },
    attach         = {},
    flutter        = { flutter = true },
    flutter_test   = { flutter = true, test = true },
    flutter_attach = { flutter = true },
}

---Fields every mode accepts, launch and attach, Dart and Flutter alike.
---Declared once and merged into every mode, so a field is described in one
---place. The `debug_*` pair is what "just my code" is built out of here: SDK and
---package libraries are debuggable unless turned off.
---@type table<string, ezdap.Input>
local _common_inputs = {
    cwd                               = { type = "string", format = "dir", description = "working directory" },
    env                               = { type = "map", description = "environment variables for the launched process" },
    additional_project_paths          = { type = "list", item_format = "dir", description = "extra paths to treat as the user's own code" },
    debug_sdk_libraries               = { type = "boolean", description = "step into SDK libraries (default true)" },
    debug_external_package_libraries  = { type = "boolean", description = "step into pub package libraries (default true)" },
    show_getters_in_debug_views       = { type = "boolean", description = "list getters alongside fields, evaluated when expanded" },
    evaluate_getters_in_debug_views   = { type = "boolean", description = "evaluate getters eagerly and show them inline" },
    evaluate_to_string_in_debug_views = { type = "boolean", description = "call toString() on objects shown in variables and hovers" },
    allow_ansi_color_output           = { type = "boolean", description = "allow ansi colour codes in the debuggee's output" },
}

---Fields for running the tool itself, rather than the program it runs. Every
---mode whose adapter shells out to `dart`/`flutter` accepts them — including
---the Flutter attach, which runs the flutter tool to reach the device.
---@type table<string, ezdap.Input>
local _tool_inputs = {
    tool_args                 = { type = "list", description = "arguments for the dart/flutter tool, e.g. -d,chrome or --flavor,dev" },
    custom_tool               = { type = "string", format = "file", description = "a compatible tool to run instead of dart/flutter" },
    custom_tool_replaces_args = { type = "integer", description = "arguments to drop from the front of the tool command line when using custom_tool" },
}

---Fields both attach modes need: which running VM Service to connect to,
---named directly or through the file the tool writes it to.
---@type table<string, ezdap.Input>
local _attach_inputs = {
    vm_service_uri       = { type = "string", description = "VM Service uri of the running app" },
    vm_service_info_file = { type = "string", format = "file", description = "file to read the VM Service uri from" },
}

---A mode's inputs: the always-accepted set plus whichever groups apply.
---@param ... table<string, ezdap.Input>
---@return table<string, ezdap.Input>
local function _inputs(...)
    local out = vim.deepcopy(_common_inputs)
    for _, group in ipairs({ ... }) do
        out = vim.tbl_extend("error", out, vim.deepcopy(group))
    end
    return out
end

---@param params table
---@param inputs table<string, any>
local function _common_build(params, inputs)
    params.cwd                           = inputs.cwd
    params.env                           = inputs.env
    params.additionalProjectPaths        = inputs.additional_project_paths
    params.debugSdkLibraries             = inputs.debug_sdk_libraries
    params.debugExternalPackageLibraries = inputs.debug_external_package_libraries
    params.showGettersInDebugViews       = inputs.show_getters_in_debug_views
    params.evaluateGettersInDebugViews   = inputs.evaluate_getters_in_debug_views
    params.evaluateToStringInDebugViews  = inputs.evaluate_to_string_in_debug_views
    params.allowAnsiColorOutput          = inputs.allow_ansi_color_output
end

---@param params table
---@param inputs table<string, any>
local function _tool_build(params, inputs)
    _common_build(params, inputs)
    params.toolArgs               = inputs.tool_args
    params.customTool             = inputs.custom_tool
    params.customToolReplacesArgs = inputs.custom_tool_replaces_args
end

---The launch half shared by Dart and Flutter: one `command` input carries the
---whole command line, split into `program` (the entry point) and `args` (what it
---is run with). Flutter leaves `program` optional — without one the tool runs the
---project's own entry point — so an unset command assigns nothing rather than an
---empty program.
---@param params table
---@param inputs table<string, any>
local function _launch_build(params, inputs)
    _tool_build(params, inputs)
    if inputs.command then
        params.program, params.args = require("ezdap.shared").split_command(inputs.command)
    end
    params.noDebug = inputs.no_debug
end

---@type table<string, ezdap.Mode>
local _modes = {
    -- `console` is the one field that changes who runs the debuggee: left alone,
    -- the adapter runs it and routes its output to the debug console, which is
    -- also the only mode where it cannot read stdin.
    script = {
        description = "debug a Dart program",
        request = "launch",
        inputs = _inputs(_tool_inputs, {
            command            = { type = "string", format = "command", required = true, description = "Dart entry point to debug, plus its arguments" },
            no_debug           = { type = "boolean", description = "run the program without debugging it" },
            vm_additional_args = { type = "list", description = "arguments passed straight to the Dart VM, before the tool's own" },
            vm_service_port    = { type = "integer", format = "port", description = "fixed port for the debuggee's VM Service" },
            console            = { type = "string", choices = { "internalConsole", "terminal", "externalTerminal" }, description = "where the debuggee runs; a terminal is what gives it stdin" },
        }),
        build = function(params, _, inputs)
            _launch_build(params, inputs)
            params.vmAdditionalArgs = inputs.vm_additional_args
            params.vmServicePort    = inputs.vm_service_port
            params.console          = inputs.console
        end,
    },
    -- The same adapter in test mode (`dart debug_adapter --test`): it runs the
    -- program as a test suite and reports progress and results as it goes.
    test = {
        description = "debug a Dart test suite",
        request = "launch",
        inputs = _inputs(_tool_inputs, {
            command            = { type = "string", format = "command", required = true, description = "test file to debug, plus its arguments" },
            no_debug           = { type = "boolean", description = "run the tests without debugging them" },
            vm_additional_args = { type = "list", description = "arguments passed straight to the Dart VM, before the tool's own" },
            console            = { type = "string", choices = { "internalConsole", "terminal", "externalTerminal" }, description = "where the tests run; a terminal is what gives them stdin" },
        }),
        build = function(params, _, inputs)
            _launch_build(params, inputs)
            params.vmAdditionalArgs = inputs.vm_additional_args
            params.console          = inputs.console
        end,
    },
    -- Dart names a running debuggee by its VM Service, not by a pid: the uri a
    -- program prints when started with `--observe`/`--enable-vm-service`, or the
    -- file it was told to write that uri to.
    attach = {
        description = "attach to a running Dart VM Service",
        request = "attach",
        inputs = _inputs(_attach_inputs),
        build = function(params, _, inputs)
            _common_build(params, inputs)
            params.vmServiceUri      = inputs.vm_service_uri
            params.vmServiceInfoFile = inputs.vm_service_info_file
        end,
    },
    -- Flutter's own adapter, which drives the flutter tool rather than the VM
    -- directly, so hot reload and hot restart work. The device, build mode and
    -- flavour are flutter's arguments, not the adapter's: they go in `tool_args`.
    flutter = {
        description = "debug a Flutter app on a device",
        request = "launch",
        inputs = _inputs(_tool_inputs, {
            command  = { type = "string", format = "command", required = false, description = "entry point to debug, plus its arguments (default: the project's own)" },
            no_debug = { type = "boolean", description = "run the app without debugging it" },
        }),
        build = function(params, _, inputs)
            _launch_build(params, inputs)
        end,
    },
    flutter_test = {
        description = "debug a Flutter test suite",
        request = "launch",
        inputs = _inputs(_tool_inputs, {
            command  = { type = "string", format = "command", required = false, description = "test file to debug, plus its arguments (default: every test)" },
            no_debug = { type = "boolean", description = "run the tests without debugging them" },
        }),
        build = function(params, _, inputs)
            _launch_build(params, inputs)
        end,
    },
    -- Attaching to a Flutter app already running on a device: the flutter tool
    -- finds it when given neither uri nor file, which is why both are optional.
    flutter_attach = {
        description = "attach to a running Flutter app",
        request = "attach",
        inputs = _inputs(_tool_inputs, _attach_inputs, {
            program = { type = "string", format = "file", description = "entry point of the running app, for resolving its sources" },
        }),
        build = function(params, _, inputs)
            _tool_build(params, inputs)
            params.vmServiceUri      = inputs.vm_service_uri
            params.vmServiceInfoFile = inputs.vm_service_info_file
            params.program           = inputs.program
        end,
    },
}

---@type ezdap.AdapterDef
return {
    command = { dart_bin or dart_bins[1], dap_subcommand },
    -- Nothing to spawn — every one of these adapters speaks DAP over stdio — but
    -- which tool to run is the mode's answer, not the def's, and a missing SDK
    -- fails the session with no legible reason. Both are settled here, where a
    -- plain error string reaches the user.
    setup = function(config, ctx, callback)
        local shared = require("ezdap.shared")
        -- A raw task names no mode, so it is on its own here: whatever command
        -- it carries stands.
        local spec = ctx.mode and _tool_of[ctx.mode]
        if not spec then return callback() end
        local pinned = spec.flutter and flutter_bin or dart_bin
        local exe, tried = shared.resolve_path(
            pinned and { pinned } or (spec.flutter and flutter_bins or dart_bins),
            shared.is_executable)
        if not exe then
            return callback(("%s not found (install the %s SDK); tried %s"):format(
                spec.flutter and "flutter" or "dart",
                spec.flutter and "Flutter" or "Dart",
                table.concat(tried, ", ")))
        end
        local cmd = { exe, dap_subcommand }
        if spec.test then cmd[#cmd + 1] = "--test" end
        config.command = cmd
        callback()
    end,
    modes = _modes,
}
