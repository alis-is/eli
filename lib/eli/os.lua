local _eosLoaded, _eos = pcall(require, "eli.os.extra")
local _util = require "eli.util"

local _os = {
    ---#DES os.EOS
    ---
    ---@type boolean
    EOS = _eosLoaded
}

return _eosLoaded and _util.merge_tables(_os, _eos) or _os