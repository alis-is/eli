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
    local ok, err = eli_lz.safe_extract("assets/test.tar.gz", "tmp/test.tar")
    test.assert(ok, err)
    local ok, hash = eli_fs.safe_hash_file("tmp/test.tar", { hex = true })
    test.assert(ok, hash)
    local ok, hash2 = eli_fs.safe_hash_file("assets/test.tar", { hex = true })
    test.assert(ok, hash2)
    test.assert(hash == hash2, "hashes dont match")
end

test["extract_string"] = function ()
    local ok, file = eli_lz.safe_extract_string"assets/test.tar.gz"
    test.assert(ok, file)
    local ok, hash = eli_hash.safe_sha256sum(file, true)
    test.assert(ok, hash)
    local ok, hash2 = eli_fs.safe_hash_file("assets/test.tar", { hex = true })
    test.assert(ok, hash2)
    test.assert(hash == hash2, "hashes dont match")
end

test["extract_from_string"] = function ()
    local gz_bytes = eli_fs.read_file"assets/test.tar.gz"
    local ok, file = eli_lz.safe_extract_from_string(gz_bytes)
    test.assert(ok, file)
    local ok, hash = eli_hash.safe_sha256sum(file, true)
    test.assert(ok, hash)
    local ok, hash2 = eli_fs.safe_hash_file("assets/test.tar", { hex = true })
    test.assert(ok, hash2)
    test.assert(hash == hash2, "hashes dont match")
end

test["compress_string"] = function ()
    local ok, data = eli_lz.safe_compress_string"test string"
    test.assert(ok, data)
    local ok, data2 = eli_lz.safe_extract_from_string(data)
    test.assert(ok, data2 == "test string")
end

if not TEST then
    test.summary()
end
