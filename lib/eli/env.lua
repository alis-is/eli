local os = require"os"
local is_loaded, eenv = pcall(require, "eli.env.extra")

local util = require"eli.util"

local env = {
    get_env = is_loaded and eenv.get_env or os.getenv,
    ---#DES env.EENV
    ---
    ---@type boolean
    EENV = is_loaded,
}

if not is_loaded then
    return env
end

return util.merge_tables(env, eenv)
