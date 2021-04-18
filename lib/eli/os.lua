local _eosLoaded, _eos = pcall(require, "eli.os.extra")
local _util = require "eli.util"

local eos = {
    ---#DES os.EOS
    ---
    ---@type boolean
    EOS = _eosLoaded
}

if not _eosLoaded then
    return eos
end

return _util.merge_tables(eos, _eos)