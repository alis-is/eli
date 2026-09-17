local os = require"os"
local is_loaded = type(os.set_env) == "function"
local is_tty = require"is_tty".is_stdout_tty()

-- Keep the notice on stderr, but only for interactive runs: callers that
-- capture output (proc.spawn output="pipe" merges stderr into stdout) must
-- not have their machine-readable streams polluted.
local function deprecated(name, replacement, fn)
    local message = "eli.env." .. name .. " is deprecated; use " .. replacement .. " instead\n"
    return function(...)
        if is_tty then
            io.stderr:write(message)
        end
        return fn(...)
    end
end

local env = {
    get_env = deprecated("get_env", "os.getenv", os.getenv),
    ---#DES env.EENV
    ---
    ---@type boolean
    EENV = is_loaded,
}

if is_loaded then
    env.set_env = deprecated("set_env", "os.setenv", os.setenv)
    env.environment = deprecated("environment", "os.environment", os.environment)
end

return env
