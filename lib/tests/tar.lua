local _test = TEST or require "u-test"
local _ok, _eliTar = pcall(require, "eli.tar")
local _ok2, _eliFs = pcall(require, "eli.fs")
local _ok2, _eliHash = pcall(require, "eli.hash")

if not _ok then
    _test["eli.tar available"] = function()
        _test.assert(false, "eli.tar not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.tar available"] = function()
    _test.assert(true)
end
--[[
    3cabbf41959954a7fd8a90918849b0906d90aa05444ba2d37c7e6dd548c45060  f1.txt
    76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba  f2.txt
    7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a  f3.txt
]]
_test["extract"] = function()
    _eliFs.remove("tmp/f1.txt")
    _eliFs.remove("tmp/f2.txt")
    _eliFs.remove("tmp/f3.txt")
    local _ok, _error = _eliTar.safe_extract("assets/test.tar", "tmp")
    _test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/f1.txt", {hex = true})
    _test.assert(_ok, _hash)
    _test.assert(_hash == "3cabbf41959954a7fd8a90918849b0906d90aa05444ba2d37c7e6dd548c45060", "hashes dont match")
    local _ok, _hash = _eliFs.safe_hash_file("tmp/f2.txt", {hex = true})
    _test.assert(_ok, _hash)
    _test.assert(_hash == "76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba", "hashes dont match")
    local _ok, _hash = _eliFs.safe_hash_file("tmp/f3.txt", {hex = true})
    _test.assert(_ok, _hash)
    _test.assert(_hash == "7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a", "hashes dont match")
end

_test["extract_file"] = function()
    _eliFs.remove("tmp/f2.txt.untared")
    local _ok, _error = _eliTar.safe_extract_file("assets/test.tar", "f2.txt", "tmp/f2.txt.untared")
    _test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/f2.txt.untared", {hex = true})
    _test.assert(_ok, _hash)
    _test.assert(_hash == "76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba", "hashes dont match")
end

_test["extract_string"] = function()
    local _ok, _file = _eliTar.safe_extract_string("assets/test.tar", "f3.txt")
    _test.assert(_ok, _file)
    local _ok, _hash = _eliHash.safe_sha256sum(_file, true)
    _test.assert(_ok, _hash)
    _test.assert(_hash == "7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a", "hashes dont match")
end

if not TEST then
    _test.summary()
end
