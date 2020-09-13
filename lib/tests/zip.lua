  
local _test = TEST or require 'u-test'
local _ok, _eliZip = pcall(require, "eli.zip")
local _ok2, _eliFs = pcall(require, "eli.fs")
local _ok2, _eliHash = pcall(require, "eli.hash")

if not _ok then 
    _test["eli.zip available"] = function ()
        _test.assert(false, "eli.zip not available")
    end
    if not TEST then 
        _test.summary()
        os.exit()
    else 
        return 
    end
end

_test["eli.zip available"] = function ()
    _test.assert(true)
end

_test["extract"] = function ()
    _eliFs.remove("tmp/test.file")
    local _ok, _error = _eliZip.safe_extract("test.zip", "tmp")
    _test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.file", {hex = true})
     _test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("test.file", {hex = true})
    _test.assert(_ok, _hash2)
    _test.assert(_hash == _hash2, "hashes dont match")
end

_test["extract_file"] = function ()
    _eliFs.remove("tmp/test.file.unzipped")
    local _ok, _error = _eliZip.safe_extract_file("test.zip", "test.file", "tmp/test.file.unzipped")
    _test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("tmp/test.file.unzipped", {hex = true})
    local _ok, _hash2 = _eliFs.safe_hash_file("test.file", {hex = true})
    _test.assert(_ok, _hash2)
    _test.assert(_hash == _hash2, "hashes dont match")
end

_test["extract_string"] = function ()
    local _ok, _file = _eliZip.safe_extract_string("test.zip", "test.file", "tmp/test.file.unzipped")
    _test.assert(_ok, _file)
    local _ok, _hash = _eliHash.safe_sha256sum(_file, true)
    _test.assert(_ok, _hash)
    local _ok, _hash2 = _eliFs.safe_hash_file("test.file", {hex = true})
    _test.assert(_ok, _hash2)
    _test.assert(_hash == _hash2, "hashes dont match")
end

if not TEST then 
    _test.summary()
end