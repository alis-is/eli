local test = TEST or require"u-test"
local ok, eli_zip = pcall(require, "eli.zip")
local ok2, eli_fs = pcall(require, "eli.fs")
local ok2, eli_hash = pcall(require, "eli.hash")

if not ok then
    test["eli.zip available"] = function ()
        test.assert(false, "eli.zip not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.zip available"] = function ()
    test.assert(true)
end

test["extract"] = function ()
    eli_fs.remove"tmp/test.file"
    local ok, err = eli_zip.extract("assets/test.zip", "tmp")
    test.assert(ok, err)
    local file_hash, err = eli_fs.hash_file("tmp/test.file", { hex = true })
    test.assert(ok, file_hash)
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(ok, file_hash2)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["extract_file"] = function ()
    eli_fs.remove"tmp/test.file.unzipped"
    local ok, err = eli_zip.extract_file("assets/test.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(ok, err)
    local file_hash, _ = eli_fs.hash_file("tmp/test.file.unzipped", { hex = true })
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(file_hash2, err)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["extract_string"] = function ()
    local file, err = eli_zip.extract_string("assets/test.zip", "test.file")
    test.assert(file, err)
    local file_hash, err = eli_hash.sha256_sum(file, true)
    test.assert(file_hash, err)
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(file_hash2, err)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["compress"] = function ()
    eli_fs.remove"tmp/test.file.zip"
    local ok, file = eli_zip.compress("assets/test.file", "tmp/test.file.zip")
    test.assert(ok, file)
    local ok, err = eli_zip.extract_file("tmp/test.file.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(ok, err)
    local file_hash, _ = eli_fs.hash_file("tmp/test.file.unzipped", { hex = true })
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(file_hash2, err)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["compress (filter)"] = function ()
    eli_fs.remove"tmp/test.file.zip"
    local ok, file = eli_zip.compress("assets", "tmp/test.file.zip", {
        filter = function (path, info)
            return path == "test.file"
        end,
        content_only = true,
    })
    test.assert(ok, file)
    local ok, error = eli_zip.extract_file("tmp/test.file.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(ok, error)
    local hash, err = eli_fs.hash_file("tmp/test.file.unzipped", { hex = true })
    local hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(ok, hash2)
    test.assert(eli_hash.equals(hash, hash2, true),
        "hashes dont match (" .. tostring(hash) .. "<>" .. tostring(hash2) .. ")")
    local files = eli_zip.get_files"tmp/test.file.zip"
    test.assert(#files == 1, "files count mismatch")
end

if not TEST then
    test.summary()
end
