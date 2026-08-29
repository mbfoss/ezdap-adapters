-- Java — expects an external java-debug server (e.g. started by nvim-jdtls).
-- Two distinct endpoints are in play: the DAP connection to that server, and the
-- debuggee JVM's JDWP address, which com.microsoft.java.debug reads from the
-- attach body as `hostName`/`port` (not `host`).

---@type ezdap.AdapterDef
return {
    host     = "127.0.0.1",
    port     = 0,
    modes = {
        attach = {
            description = "attach to an external java-debug server (e.g. via nvim-jdtls)",
            request = "attach",
            inputs = {
                jdwp_host    = { type = "string", description = "JDWP host of the debuggee JVM" },
                jdwp_port    = { type = "integer", format = "port", required = true, description = "JDWP port of the debuggee JVM" },
                server_host  = { type = "string", description = "host of the java-debug server (default 127.0.0.1)" },
                server_port  = { type = "integer", format = "port", required = true, description = "port the java-debug server listens on" },
                project_name = { type = "string", description = "project name used to resolve sources" },
                source_paths = { type = "list", item_format = "dir", description = "extra source lookup paths" },
                timeout      = { type = "integer", description = "attach timeout in milliseconds" },
            },
            -- Two host/port pairs, and they are not the same connection: the body's
            -- names the JDWP port the debuggee exposes, the second return the
            -- java-debug-server ezdap itself dials.
            build = function(inputs)
                return {
                    hostName    = inputs.jdwp_host or "127.0.0.1",
                    port        = inputs.jdwp_port,
                    projectName = inputs.project_name,
                    sourcePaths = inputs.source_paths,
                    timeout     = inputs.timeout or 30000,
                }, {
                    host = inputs.server_host or "127.0.0.1",
                    port = inputs.server_port,
                }
            end,
        },
    },
}
