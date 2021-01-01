local _eosLoaded, _eos = pcall(require, "eli.os.extra")
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables

local eos = {
    EOS = _eosLoaded
}

if not _eosLoaded then
    return eos
end

return generate_safe_functions(merge_tables(eos, _eos))