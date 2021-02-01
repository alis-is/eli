local _os = require"os"
local _eenvLoaded, _eenv = pcall(require, "eli.env.extra")

local _util = require"eli.util"

local _env = {
    get_env = _os.getenv,
    EENV = _eenvLoaded
}

if not _eenvLoaded then
    return _util.generate_safe_functions(_env)
end

return _util.generate_safe_functions(_util.merge_tables(_env, _eenv))