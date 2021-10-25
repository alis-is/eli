local _test = require 'u-test'
local _ok, _eliFs = pcall(require, "eli.fs")

if not _ok then
    _test["eli.fs not available"] = function()
        _test.assert(false, "eli.fs not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.fs available"] = function() _test.assert(true) end

_test["copy file"] = function()
    local _ok, _error = _eliFs.safe_copy_file("assets/test.file",
                                              "tmp/test.file")
    _test.assert(_ok, _error)
    local _ok, _hash = _eliFs.safe_hash_file("assets/test.file",
                                             {type = "sha256"})
    _test.assert(_ok, _hash)
    local _ok, _hash2 =
        _eliFs.safe_hash_file("tmp/test.file", {type = "sha256"})
    _test.assert(_hash == _hash2, "hashes do not match")
end

_test["read file"] = function()
    local _ok, _file1 = _eliFs.safe_read_file("assets/test.file")
    _test.assert(_ok, _file1)
    local _ok, _file2 = _eliFs.safe_read_file("tmp/test.file")
    _test.assert(_ok, _file2)
    _test.assert(_file1 == _file2, "written data does not match")
end

_test["write file"] = function()
    local _ok, _file1 = _eliFs.safe_read_file("assets/test.file")
    _test.assert(_ok, _file1)
    local _ok, _error = _eliFs.safe_write_file("tmp/test.file2", _file1)
    _test.assert(_ok, _error)
    local _ok, _file2 = _eliFs.safe_read_file("tmp/test.file2")
    _test.assert(_ok, _file2)
    _test.assert(_file1 == _file2, "written data does not match")
end

_test["move (file)"] = function()
    local _ok, _error = _eliFs.safe_move("tmp/test.file", "tmp/test.file2")
    _test.assert(_ok, _error)
    local _ok, _file1 = _eliFs.safe_read_file("assets/test.file")
    _test.assert(_ok, _file1)
    local _ok, _file2 = _eliFs.safe_read_file("tmp/test.file2")
    _test.assert(_ok, _file2)
    _test.assert(_file1 == _file2, "written data does not match")
end

-- extra
_test["mkdir"] = function()
    local _ok, _error = _eliFs.safe_mkdir("tmp/test-dir")
    _test.assert(_ok, _error)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir")
    _test.assert(_exists, (_exists or "not exists"))
end

_test["mkdirp"] = function()
    local _ok = _eliFs.safe_mkdirp("tmp/test-dir/test/test")
    _test.assert(_ok)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir/test/test")
    _test.assert(_ok and _exists, (_exists or "not exists"))
end

_test["create_dir"] = function()
    _eliFs.safe_remove("tmp/test-dir", {recurse = true})
    local _ok, _error = _eliFs.safe_create_dir("tmp/test-dir")
    _test.assert(_ok, _error)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir")
    _test.assert(_exists, (_exists or "not exists"))

    local _ok = _eliFs.safe_create_dir("tmp/test-dir/test/test")
    _test.assert(_ok)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir/test/test")
    _test.assert(_ok and not _exists, (_exists or "exists"))

    local _ok = _eliFs.safe_create_dir("tmp/test-dir/test/test", true)
    _test.assert(_ok)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir/test/test")
    _test.assert(_ok and _exists, (_exists or "not exists"))
end

_test["remove (file)"] = function()
    local _ok, _file1 = _eliFs.safe_remove("tmp/test.file2")
    _test.assert(_ok, _file1)
    local _ok, _file2 = _eliFs.safe_read_file("tmp/test.file2")
    _test.assert(not _ok, _file2)
end

_test["remove (dir)"] = function()
    local _ok, _file1 = _eliFs.safe_remove("tmp/test-dir/test/test")
    _test.assert(_ok, _file1)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir/test/test")
    _test.assert(_ok and not _exists)
end

_test["move (dir)"] = function()
    local _ok, _error = _eliFs.safe_move("tmp/test-dir/test",
                                         "tmp/test-dir/test2")
    _test.assert(_ok, _error)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir/test2")
    _test.assert(_ok and _exists, _exists)
end

_test["remove (recurse)"] = function()
    local _ok, _error = _eliFs.safe_remove("tmp/test-dir", {recurse = true})
    _test.assert(_ok, _error)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir")
    _test.assert(_ok and not _exists, _exists)
end

_test["remove (contentOnly)"] = function()
    local _ok, _error = _eliFs.safe_mkdir("tmp/test-dir")
    _test.assert(_ok, _error)
    local _ok, _error = _eliFs.safe_copy_file("assets/test.file",
                                              "tmp/test-dir/test.file")
    _test.assert(_ok, _error)
    local _ok, _error = _eliFs.safe_remove("tmp/test-dir",
                                           {contentOnly = true, recurse = true})
    _test.assert(_ok, _error)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir")
    _test.assert(_ok and _exists, _exists)
    local _ok, _exists = _eliFs.safe_exists("tmp/test-dir/test.file")
    _test.assert(_ok and not _exists, _exists)
end

if not _eliFs.EFS then
    if not TEST then
        _test.summary()
        print "EFS not detected, only basic tests executed..."
        os.exit()
    else
        print "EFS not detected, only basic tests executed..."
        return
    end
end

_test["file_type (file)"] = function()
    local _ok, _type = _eliFs.safe_file_type("tmp/test.file")
    _test.assert(_ok and _type == nil)
    local _ok, _error = _eliFs.safe_copy_file("assets/test.file",
                                              "tmp/test.file")
    _test.assert(_ok, _error)
    local _ok, _type = _eliFs.safe_file_type("tmp/test.file")
    _test.assert(_ok and _type == "file")
end

_test["file_type (dir)"] = function()
    local _ok, _type = _eliFs.safe_file_type("tmp/")
    _test.assert(_ok and _type == "directory")
end

_test["open_dir"] = function()
    local _ok, _dir = _eliFs.safe_open_dir("tmp/")
    _test.assert(_ok and _dir.__type == "ELI_DIR")
end

_test["read_dir & iter_dir"] = function()
    local _ok, _dirEntries = _eliFs.safe_read_dir("tmp/")
    _test.assert(_ok and #_dirEntries > 0)

    local count = 0
    for _dirEntry in _eliFs.iter_dir("tmp/") do count = count + 1 end
    _test.assert(#_dirEntries == count)
end

local function _external_lock(file)
    local _ok, _, _code = os.execute(arg[-1] .. " -e 'x, err = fs.lock_file(\"" .. file.. "\",\"w\"); if x == true then os.exit(0); end; os.exit(err == \"Resource temporarily unavailable\" and 11 or 12)'")
    return _ok, _code
end

local _lockedFile
_test["lock_file"] = function()
    _lockedFile = io.open("tmp/test.file", "w")
    local _ok, _error = _eliFs.lock_file(_lockedFile, "w")
    _test.assert(_ok, _error)
    local _ok, _code, _ = _external_lock("tmp/test.file")
    _test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
end

_test["unlock_file"] = function()
    _lockedFile = io.open("tmp/test.file")
    local _ok, _code, _ = _external_lock("tmp/test.file")
    _test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
    local _ok, _error = _eliFs.unlock_file(_lockedFile)
    _test.assert(_ok, _error)
    local _ok, _code, _ = _external_lock("tmp/test.file")
    _test.assert(_ok and _code == 0, "Should not be able to lock twice!")
end

local _lockedFile2
_test["lock_file (path)"] = function()
    local _lockedFile2, _error = _eliFs.lock_file("tmp/test.file", "w")
    _test.assert(_lockedFile2 ~= nil, _error)
    local _ok, _code, _ = _external_lock("tmp/test.file")
    _test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
end

_test["unlock_file (path)"] = function()
    local _ok, _code, _ = _external_lock("tmp/test.file")
    _test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
    local _ok, _error = _eliFs.unlock_file("tmp/test.file")
    _test.assert(_ok, _error)
    local _ok, _code, _ = _external_lock("tmp/test.file")
    _test.assert(_ok and _code == 0, "Should not be able to lock twice!")
    local _ok, _error = _eliFs.unlock_file("tmp/test.file")
    _test.assert(_ok, _error)
end

_test["lock_dir & unlock_dir"] = function()
    local _ok, _lock, _error = _eliFs.safe_lock_dir("tmp")
    _test.assert(_ok, _lock)
    local _ok, _locked = _eliFs.safe_link_info("tmp/lockfile")
    _test.assert(_ok and _locked)
    local _ok, _error = _eliFs.safe_unlock_dir(_lock)
    _test.assert(_ok, _error)
    local _ok, _locked = _eliFs.safe_link_info("tmp/lockfile")
    _test.assert(_ok and not _locked)
end

if not TEST then _test.summary() end
