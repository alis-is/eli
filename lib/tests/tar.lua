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
    local ok, err = eli_tar.extract("assets/test.tar", "tmp")
    test.assert(ok, err)
    local file_hash, err = eli_fs.hash_file("tmp/f1.txt", { hex = true })
    test.assert(file_hash, err)
    test.assert(file_hash == "3cabbf41959954a7fd8a90918849b0906d90aa05444ba2d37c7e6dd548c45060", "hashes dont match")
    local file_hash, err = eli_fs.hash_file("tmp/f2.txt", { hex = true })
    test.assert(file_hash, err)
    test.assert(file_hash == "76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba", "hashes dont match")
    local file_hash, err = eli_fs.hash_file("tmp/f3.txt", { hex = true })
    test.assert(file_hash, err)
    test.assert(file_hash == "7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a", "hashes dont match")
end

test["extract_file"] = function ()
    eli_fs.remove"tmp/f2.txt.untared"
    local ok, err = eli_tar.extract_file("assets/test.tar", "f2.txt", "tmp/f2.txt.untared")
    test.assert(ok, err)
    local file_hash, err = eli_fs.hash_file("tmp/f2.txt.untared", { hex = true })
    test.assert(file_hash, err)
    test.assert(file_hash == "76f60fe07ed3fac881ff3022b141f1cd56242152a43fa90b1a3ac423a2efc7ba", "hashes dont match")
end

test["extract_string"] = function ()
    local file, err = eli_tar.extract_string("assets/test.tar", "f3.txt")
    test.assert(file, err)
    local file_hash, err = eli_hash.sha256_sum(file, true)
    test.assert(file_hash, err)
    test.assert(file_hash == "7e5449fc89e75e0b8c6cbb3568720d074fa435f88dd9bf5e8b82c012a6c86c2a", "hashes dont match")
end

if not TEST then
    test.summary()
end
