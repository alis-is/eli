local _os = require "os"
local _eenvLoaded, _eenv = pcall(require, "eli.env.extra")

local _util = require "eli.util"

local _env = {
    get_env = _eenvLoaded and _eenv.get_env or _os.getenv,
    ---#DES env.EENV
    ---
    ---@type boolean
    EENV = _eenvLoaded
}

if not _eenvLoaded then
    return _env
end

return _util.merge_tables(_env, _eenv)
