local _test = TEST or require "u-test"
local _ok, _eliLz = pcall(require, "eli.lz")
local _ok2, _eliFs = pcall(require, "eli.fs")
local _ok2, _eliHash = pcall(require, "eli.hash")

if not _ok then
    _test["eli.lz available"] = function()
        _test.assert(false, "eli.lz not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.lz available"] = function()
    _test.assert(true)
end

--[[
    76542f8ea5c585ef47a2cc1dd067be90ee398c41e069d772d27ea4596290dfd8  test.tar
]]
_test["extract"] = function()
    _eliFs.remove("tmp/test.tar")
    local _ok, _error = _eliLz.safe_extract("assets/test.tar.gz", "tmp/test.tar")
    _test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.tar", {hex = true})
    _test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.tar", {hex = true})
    _test.assert(_ok, _hash2)
    _test.assert(_hash == _hash2, "hashes dont match")
end

_test["extract_string"] = function()
    local _ok, _file = _eliLz.safe_extract_string("assets/test.tar.gz")
    _test.assert(_ok, _file)
    local _ok, _hash = _eliHash.safe_sha256sum(_file, true)
    _test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.tar", {hex = true})
    _test.assert(_ok, _hash2)
    _test.assert(_hash == _hash2, "hashes dont match")
end

_test["extract_from_string"] = function()
    local _gz = _eliFs.read_file("assets/test.tar.gz")
    local _ok, _file = _eliLz.safe_extract_from_string(_gz)
    _test.assert(_ok, _file)
    local _ok, _hash = _eliHash.safe_sha256sum(_file, true)
    _test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.tar", {hex = true})
    _test.assert(_ok, _hash2)
    _test.assert(_hash == _hash2, "hashes dont match")
end

if not TEST then
    _test.summary()
end
