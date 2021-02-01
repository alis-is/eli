local _eosLoaded, _eos = pcall(require, "eli.os.extra")
local _util = require "eli.util"

local eos = {
    EOS = _eosLoaded
}

if not _eosLoaded then
    return eos
end

return _util.generate_safe_functions(_util.merge_tables(eos, _eos))