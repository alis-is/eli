local _eosLoaded, _eos = pcall(require, "eli.os.extra")

local eos = {
    EOS = _eosLoaded
}

if not _eosLoaded then
    return eos
end

return generate_safe_functions(merge_tables(eos, _eos))