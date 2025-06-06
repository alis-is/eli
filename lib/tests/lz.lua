local test = TEST or require"u-test"
local ok, eli_lz = pcall(require, "eli.lz")
local _, eli_fs = pcall(require, "eli.fs")
local _, eli_hash = pcall(require, "eli.hash")

if not ok then
    test["eli.lz available"] = function ()
        test.assert(false, "eli.lz not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.lz available"] = function ()
    test.assert(true)
end

--[[
    76542f8ea5c585ef47a2cc1dd067be90ee398c41e069d772d27ea4596290dfd8  test.tar
]]
test["extract"] = function ()
    eli_fs.remove"tmp/test.tar"
    local ok, err = eli_lz.extract("assets/test.tar.gz", "tmp/test.tar")
    test.assert(ok, err)
    local hash, err = eli_fs.hash_file("tmp/test.tar", { hex = true })
    test.assert(hash, err)
    local hash2, err = eli_fs.hash_file("assets/test.tar", { hex = true })
    test.assert(hash2, err)
    test.assert(hash == hash2, "hashes dont match")
end

test["extract_string"] = function ()
    local file, eer = eli_lz.extract_string"assets/test.tar.gz"
    test.assert(file, err)
    local hash, err = eli_hash.sha256_sum(file, true)
    test.assert(hash, err)
    local hash2, err = eli_fs.hash_file("assets/test.tar", { hex = true })
    test.assert(hash2, err)
    test.assert(hash == hash2, "hashes dont match")
end

test["extract_from_string"] = function ()
    local gz_bytes = eli_fs.read_file"assets/test.tar.gz"
    local file, err = eli_lz.extract_from_string(gz_bytes)
    test.assert(file, err)
    local hash, err = eli_hash.sha256_sum(file, true)
    test.assert(hash, err)
    local hash2, err = eli_fs.hash_file("assets/test.tar", { hex = true })
    test.assert(hash2, err)
    test.assert(hash == hash2, "hashes dont match")
end

test["compress_string"] = function ()
    local data, err = eli_lz.compress_string"test string"
    test.assert(data, err)
    local data2, err = eli_lz.extract_from_string(data)
    test.assert(data2 and data2 == "test string", err)
end

if not TEST then
    test.summary()
end
