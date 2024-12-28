local test = TEST or require"u-test"
local _ok, _eliZip = pcall(require, "eli.zip")
local _ok2, _eliFs = pcall(require, "eli.fs")
local _ok2, _eliHash = pcall(require, "eli.hash")

if not _ok then
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
    _eliFs.remove"tmp/test.file"
    local _ok, _error = _eliZip.safe_extract("assets/test.zip", "tmp")
    test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.file", { hex = true })
    test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.file", { hex = true })
    test.assert(_ok, _hash2)
    test.assert(_eliHash.equals(_hash, _hash2, true),
        "hashes dont match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["extract_file"] = function ()
    _eliFs.remove"tmp/test.file.unzipped"
    local _ok, _error = _eliZip.safe_extract_file("assets/test.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.file.unzipped", { hex = true })
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.file", { hex = true })
    test.assert(_ok, _hash2)
    test.assert(_eliHash.equals(_hash, _hash2, true),
        "hashes dont match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["extract_string"] = function ()
    local _ok, _file = _eliZip.safe_extract_string("assets/test.zip", "test.file")
    test.assert(_ok, _file)
    local _ok, _hash = _eliHash.safe_sha256sum(_file, true)
    test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.file", { hex = true })
    test.assert(_ok, _hash2)
    test.assert(_eliHash.equals(_hash, _hash2, true),
        "hashes dont match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["compress"] = function ()
    _eliFs.remove"tmp/test.file.zip"
    local _ok, _file = _eliZip.safe_compress("assets/test.file", "tmp/test.file.zip")
    test.assert(_ok, _file)
    local _ok, _error = _eliZip.safe_extract_file("tmp/test.file.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.file.unzipped", { hex = true })
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.file", { hex = true })
    test.assert(_ok, _hash2)
    test.assert(_eliHash.equals(_hash, _hash2, true),
        "hashes dont match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["compress (filter)"] = function ()
    _eliFs.remove"tmp/test.file.zip"
    local _ok, _file = _eliZip.safe_compress("assets", "tmp/test.file.zip", {
        filter = function (path, info)
            return path == "test.file"
        end,
        contentOnly = true,
    })
    test.assert(_ok, _file)
    local _ok, _error = _eliZip.safe_extract_file("tmp/test.file.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.file.unzipped", { hex = true })
    local _ok, _hash2 = _eliFs.safe_hash_file("assets/test.file", { hex = true })
    test.assert(_ok, _hash2)
    test.assert(_eliHash.equals(_hash, _hash2, true),
        "hashes dont match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

if not TEST then
    test.summary()
end
