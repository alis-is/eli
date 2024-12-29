local test = TEST or require"u-test"
local ok, eli_tar = pcall(require, "eli.tar")
local _, eli_fs = pcall(require, "eli.fs")
local _, eli_hash = pcall(require, "eli.hash")

if not ok then
    test["eli.tar available"] = function ()
        test.assert(false, "eli.tar not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.tar available"] = function ()
    test.assert(true)
end
--[[
    3cabbf41959954a7fd8a90918849b0906d90aa05444ba2d37c7e6dd548c45060  f1.txt
    76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba  f2.txt
    7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a  f3.txt
]]
test["extract"] = function ()
    eli_fs.remove"tmp/f1.txt"
    eli_fs.remove"tmp/f2.txt"
    eli_fs.remove"tmp/f3.txt"
    local _ok, _error = eli_tar.safe_extract("assets/test.tar", "tmp")
    test.assert(_ok, _error)
    local _ok, _hash = eli_fs.safe_hash_file("tmp/f1.txt", { hex = true })
    test.assert(_ok, _hash)
    test.assert(_hash == "3cabbf41959954a7fd8a90918849b0906d90aa05444ba2d37c7e6dd548c45060", "hashes dont match")
    local _ok, _hash = eli_fs.safe_hash_file("tmp/f2.txt", { hex = true })
    test.assert(_ok, _hash)
    test.assert(_hash == "76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba", "hashes dont match")
    local _ok, _hash = eli_fs.safe_hash_file("tmp/f3.txt", { hex = true })
    test.assert(_ok, _hash)
    test.assert(_hash == "7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a", "hashes dont match")
end

test["extract_file"] = function ()
    eli_fs.remove"tmp/f2.txt.untared"
    local _ok, _error = eli_tar.safe_extract_file("assets/test.tar", "f2.txt", "tmp/f2.txt.untared")
    test.assert(_ok, _error)
    local _ok, _hash = eli_fs.safe_hash_file("tmp/f2.txt.untared", { hex = true })
    test.assert(_ok, _hash)
    test.assert(_hash == "76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba", "hashes dont match")
end

test["extract_string"] = function ()
    local _ok, _file = eli_tar.safe_extract_string("assets/test.tar", "f3.txt")
    test.assert(_ok, _file)
    local _ok, _hash = eli_hash.safe_sha256sum(_file, true)
    test.assert(_ok, _hash)
    test.assert(_hash == "7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a", "hashes dont match")
end

if not TEST then
    test.summary()
end
