local os = require"os"
local is_loaded = type(os.set_env) == "function"

local function deprecated(name, replacement, fn)
    return function(...)
        print("eli.env." .. name .. " is deprecated; use " .. replacement .. " instead")
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
