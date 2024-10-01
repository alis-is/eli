local test = require"u-test"
local ok, eliFs = pcall(require, "eli.fs")
local eliPath = require"eli.path"

if not ok then
	test["eli.fs not available"] = function ()
		test.assert(false, "eli.fs not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.fs available"] = function () test.assert(true) end

test["copy file (path)"] = function ()
	local _ok, _error = eliFs.safe_copy_file("assets/test.file",
		"tmp/test.file")
	test.assert(_ok, _error)
	local _ok, _hash = eliFs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	local _ok, _hash2 =
	   eliFs.safe_hash_file("tmp/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["copy file (file*)"] = function ()
	do
		local _src <close> = io.open("assets/test.file", "rb")
		local _dst <close> = io.open("tmp/test.file2", "wb")
		local _ok, _error = eliFs.safe_copy_file(_src, _dst)
		test.assert(_ok, _error)
	end
	local _ok, _hash = eliFs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	local _ok, _hash2 = eliFs.safe_hash_file("tmp/test.file2", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["copy file (mixed)"] = function ()
	do
		local _src <close> = io.open("assets/test.file", "rb")
		local _ok, _error = eliFs.safe_copy_file(_src, "tmp/test.file3")
		test.assert(_ok, _error)
	end
	local _ok, _hash = eliFs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	local _ok, _hash2 = eliFs.safe_hash_file("tmp/test.file3", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")

	do
		local _dst <close> = io.open("tmp/test.file4", "wb")
		local _ok, _error = eliFs.safe_copy_file("assets/test.file", _dst)
		test.assert(_ok, _error)
	end

	local _ok, _hash2 = eliFs.safe_hash_file("tmp/test.file4", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["copy file (permissions)"] = function ()
	local _ok, _error = eliFs.safe_copy_file("assets/test.bin",
		"tmp/test.bin")
	test.assert(_ok, _error)
	local info = eliFs.file_info"assets/test.bin"
	local info2 = eliFs.file_info"tmp/test.bin"
	test.assert(info.permissions == info2.permissions, "permissions do not match")
end

test["copy (file)"] = function ()
	local _ok, _error = eliFs.safe_copy("assets/test.file",
		"tmp/test.file")
	test.assert(_ok, _error)
	local _ok, _hash = eliFs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	local _ok, _hash2 =
	   eliFs.safe_hash_file("tmp/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["copy (directory)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local DEST_DIR = "tmp/copy-dir"
	eliFs.remove(DEST_DIR, { recurse = true })
	eliFs.mkdirp(DEST_DIR)
	local _ok, _error = eliFs.safe_copy(SOURCE_DIR, DEST_DIR)
	test.assert(_ok, _error)
	local paths = eliFs.read_dir(SOURCE_DIR, { recurse = true })
	for _, filePath in ipairs(paths) do
		local sourceFilePath = eliPath.combine(SOURCE_DIR, filePath)
		if eliFs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local _ok, _hash = eliFs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		local destFilePath = eliPath.combine(DEST_DIR, filePath)
		local _ok, _hash2 =
		   eliFs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
		::continue::
	end
end

test["copy (directory - overwrite)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local SOURCE_DIR2 = "assets/copy-dir2"
	local DEST_DIR = "tmp/copy-dir2"
	eliFs.remove(DEST_DIR, { recurse = true })
	eliFs.mkdirp(DEST_DIR)
	local _ok, _error = eliFs.safe_copy(SOURCE_DIR, DEST_DIR)
	test.assert(_ok, _error)
	local paths = eliFs.read_dir(SOURCE_DIR, { recurse = true })
	for _, filePath in ipairs(paths) do
		local sourceFilePath = eliPath.combine(SOURCE_DIR, filePath)
		if eliFs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local _ok, _hash = eliFs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		local destFilePath = eliPath.combine(DEST_DIR, filePath)
		local _ok, _hash2 =
		   eliFs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
		::continue::
	end

	local _ok, _error = eliFs.safe_copy(SOURCE_DIR2, DEST_DIR)
	test.assert(_ok, _error)
	for _, filePath in ipairs(paths) do
		local sourceFilePath = eliPath.combine(SOURCE_DIR, filePath)
		if eliFs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local _ok, _hash = eliFs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		local destFilePath = eliPath.combine(DEST_DIR, filePath)
		local _ok, _hash2 =
		   eliFs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
		::continue::
	end

	local _ok, _error = eliFs.safe_copy(SOURCE_DIR2, DEST_DIR, { overwrite = true })
	test.assert(_ok, _error)
	local paths = eliFs.read_dir(SOURCE_DIR2, { recurse = true })
	for _, filePath in ipairs(paths) do
		local sourceFilePath = eliPath.combine(SOURCE_DIR2, filePath)
		if eliFs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local _ok, _hash = eliFs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		local destFilePath = eliPath.combine(DEST_DIR, filePath)
		local _ok, _hash2 =
		   eliFs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(_ok, _hash)
		test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
		::continue::
	end
end

test["copy (directory + filtering)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local DEST_DIR = "tmp/copy-dir3"
	eliFs.remove(DEST_DIR, { recurse = true })
	eliFs.mkdirp(DEST_DIR)
	local _ok, _error = eliFs.safe_copy(SOURCE_DIR, DEST_DIR, { ignore = { "file.txt" } })
	test.assert(_ok, _error)
	test.assert(not eliFs.exists(eliPath.combine(DEST_DIR, "file.txt")), "file.txt should not exist")

	eliFs.remove(DEST_DIR, { recurse = true })
	eliFs.mkdirp(DEST_DIR)
	local _ok, _error = eliFs.safe_copy(SOURCE_DIR, DEST_DIR, {
		ignore = function (path)
			return path:match"file.txt"
		end,
	})
	test.assert(_ok, _error)
	test.assert(not eliFs.exists(eliPath.combine(DEST_DIR, "file.txt")), "file.txt should not exist")
end

test["hash file (file*)"] = function ()
	local _src = io.open("assets/test.file", "rb")
	local _ok, _hash = eliFs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	local _ok, _hash2 = eliFs.safe_hash_file(_src, { type = "sha256", hex = true })
	test.assert(_ok, _hash)
	test.assert(_hash == _hash2, "hashes do not match (" .. tostring(_hash) .. "<>" .. tostring(_hash2) .. ")")
end

test["read file"] = function ()
	local _ok, _file1 = eliFs.safe_read_file"assets/test.file"
	test.assert(_ok, _file1)
	local _ok, _file2 = eliFs.safe_read_file"tmp/test.file"
	test.assert(_ok, _file2)
	test.assert(_file1 == _file2, "written data does not match")
end

test["write file"] = function ()
	local _ok, _file1 = eliFs.safe_read_file"assets/test.file"
	test.assert(_ok, _file1)
	local _ok, _error = eliFs.safe_write_file("tmp/test.file2", _file1)
	test.assert(_ok, _error)
	local _ok, _file2 = eliFs.safe_read_file"tmp/test.file2"
	test.assert(_ok, _file2)
	test.assert(_file1 == _file2, "written data does not match")
end

test["move (file)"] = function ()
	local _ok, _error = eliFs.safe_move("tmp/test.file", "tmp/test.file2")
	test.assert(_ok, _error)
	local _ok, _file1 = eliFs.safe_read_file"assets/test.file"
	test.assert(_ok, _file1)
	local _ok, _file2 = eliFs.safe_read_file"tmp/test.file2"
	test.assert(_ok, _file2)
	test.assert(_file1 == _file2, "written data does not match")
end

-- extra
test["mkdir"] = function ()
	local _ok, _error = eliFs.safe_mkdir"tmp/test-dir"
	test.assert(_ok, _error)
	local _ok, _exists = eliFs.safe_dir_exists"tmp/test-dir"
	test.assert(_exists, (_exists or "not exists"))
end

test["mkdirp"] = function ()
	local _ok = eliFs.safe_mkdirp"tmp/test-dir/test/test"
	test.assert(_ok)
	local _ok, _exists = eliFs.safe_dir_exists"tmp/test-dir/test/test"
	test.assert(_ok and _exists, (_exists or "not exists"))
end

test["create_dir"] = function ()
	eliFs.safe_remove("tmp/test-dir", { recurse = true })
	local _ok, _error = eliFs.safe_create_dir"tmp/test-dir"
	test.assert(_ok, _error)
	local _ok, _exists = eliFs.safe_dir_exists"tmp/test-dir"
	test.assert(_exists, (_exists or "not exists"))

	local _ok = eliFs.safe_create_dir"tmp/test-dir/test/test"
	test.assert(_ok)
	local _ok, _exists = eliFs.safe_dir_exists"tmp/test-dir/test/test"
	test.assert(_ok and not _exists, (_exists or "exists"))

	local _ok = eliFs.safe_create_dir("tmp/test-dir/test/test", true)
	test.assert(_ok)
	local _ok, _exists = eliFs.safe_dir_exists"tmp/test-dir/test/test"
	test.assert(_ok and _exists, (_exists or "not exists"))
end

test["remove (file)"] = function ()
	local _ok, _file1 = eliFs.safe_remove"tmp/test.file2"
	test.assert(_ok, _file1)
	local _ok, _file2 = eliFs.safe_read_file"tmp/test.file2"
	test.assert(not _ok, _file2)
	local _ok, _error = eliFs.safe_move("tmp/test.file", "tmp/test.file2")
	test.assert(_ok, _error)
	local _ok, _file1 = eliFs.safe_remove("tmp/test.file2", { recurse = true })
	test.assert(_ok, _file1)
	local _ok, _file2 = eliFs.safe_read_file"tmp/test.file2"
	test.assert(not _ok, _file2)
end

test["remove (dir)"] = function ()
	local _ok, _file1 = eliFs.safe_remove"tmp/test-dir/test/test"
	test.assert(_ok, _file1)
	local _ok, _exists = eliFs.safe_exists"tmp/test-dir/test/test"
	test.assert(_ok and not _exists)
end

test["remove (keep)"] = function ()
	eliFs.safe_create_dir"tmp/test-dir"

	eliFs.safe_create_dir("tmp/test-dir/test/test", true)
	eliFs.safe_create_dir("tmp/test-dir/test/test-another", true)

	eliFs.safe_create_dir("tmp/test-dir/test2/test2", true)
	eliFs.safe_create_dir("tmp/test-dir/test2/test2-another", true)

	fs.write_file("tmp/test-dir/test/test/test.file", "test")
	fs.write_file("tmp/test-dir/test2/test2/test2.file", "test")

	eliFs.safe_remove("tmp/test-dir", {
		recurse = true,
		keep = function (path, fullpath)
			path = eliPath.normalize(path, "unix", { endsep = "leave" })
			return path == "test/test/" or path == "test2/test2/test2.file"
		end,
	})
	test.assert(eliFs.exists"tmp/test-dir/test2/test2/test2.file")
	test.assert(eliFs.exists"tmp/test-dir/test/test/")
	test.assert(eliFs.exists"tmp/test-dir/test/test/test.file")

	test.assert(not eliFs.exists"tmp/test-dir/test/test-another/")
	test.assert(not eliFs.exists"tmp/test-dir/test2/test2-another/")
end

test["move (dir)"] = function ()
	local _ok, _error = eliFs.safe_move("tmp/test-dir/test",
		"tmp/test-dir/test2")
	test.assert(_ok, _error)
	local _ok, _exists = eliFs.safe_exists"tmp/test-dir/test2"
	test.assert(_ok and _exists, _exists)
end

test["remove (recurse)"] = function ()
	local _ok, _error = eliFs.safe_remove("tmp/test-dir", { recurse = true })
	test.assert(_ok, _error)
	local _ok, _exists = eliFs.safe_exists"tmp/test-dir"
	test.assert(_ok and not _exists, _exists)
end

test["remove (contentOnly)"] = function ()
	local _ok, _error = eliFs.safe_mkdir"tmp/test-dir"
	test.assert(_ok, _error)
	local _ok, _error = eliFs.safe_copy_file("assets/test.file",
		"tmp/test-dir/test.file")
	test.assert(_ok, _error)
	local _ok, _error = eliFs.safe_remove("tmp/test-dir",
		{ contentOnly = true, recurse = true })
	test.assert(_ok, _error)
	local _ok, _exists = eliFs.safe_exists"tmp/test-dir"
	test.assert(_ok and _exists, _exists)
	local _ok, _exists = eliFs.safe_exists"tmp/test-dir/test.file"
	test.assert(_ok and not _exists, _exists)
end

if not eliFs.EFS then
	if not TEST then
		test.summary()
		print"EFS not detected, only basic tests executed..."
		os.exit()
	else
		print"EFS not detected, only basic tests executed..."
		return
	end
end

test["file_type (file)"] = function ()
	eliFs.safe_remove"tmp/test.file"
	local _ok, _type = eliFs.safe_file_type"tmp/test.file"
	test.assert(_ok and _type == nil)
	local _ok, _error = eliFs.safe_copy_file("assets/test.file",
		"tmp/test.file")
	test.assert(_ok, _error)
	local _ok, _type = eliFs.safe_file_type"tmp/test.file"
	test.assert(_ok and _type == "file")
end

test["file_type (dir)"] = function ()
	local _ok, _type = eliFs.safe_file_type"tmp/"
	test.assert(_ok and _type == "directory")
end

test["file_info (file)"] = function ()
	eliFs.safe_remove"tmp/test.file"
	local ok, info = eliFs.safe_file_info"assets/test.file"
	test.assert(ok and info ~= nil)
	test.assert(info.mode == "file")
	test.assert(type(info.size) == "number" and info.size > 0)

	local size_from_path = info.size
	local f <close> = io.open("assets/test.file", "rb")
	local ok, info = eliFs.safe_file_info(f)
	test.assert(ok and info ~= nil)
	test.assert(info.mode == "file")
	test.assert(type(info.size) == "number" and info.size > 0)
	test.assert(info.size == size_from_path)

	local ok, info = eliFs.safe_file_info"assets/test.file.not-existing"
	test.assert(ok and info == nil)
end

test["file_info (dir)"] = function ()
	local ok, info = eliFs.safe_file_info"assets"
	test.assert(ok and info ~= nil)
	test.assert(info.mode == "directory")
	test.assert(type(info.size) == "number" and info.size > 0)

	local ok, info = eliFs.safe_file_info"assets.not-existing"
	test.assert(ok and info == nil)
end


test["open_dir"] = function ()
	local _ok, _dir = eliFs.safe_open_dir"tmp/"
	test.assert(_ok and _dir.__type == "ELI_DIR")
end

test["read_dir & iter_dir"] = function ()
	local _ok, _dirEntries = eliFs.safe_read_dir"tmp/"
	test.assert(_ok and #_dirEntries > 0)

	local count = 0
	for _dirEntry in eliFs.iter_dir"tmp/" do count = count + 1 end
	test.assert(#_dirEntries == count)
end

local function _external_lock(file)
	local _cmd = (os.getenv"QEMU" or "") ..
	   " " .. arg[-1] .. " -e \"x, err = fs.lock_file('" .. file .. "','w'); " ..
	   "if etype(x) == 'ELI_FILE_LOCK' then os.exit(0); end; notAvailable = tostring(err):match('Resource temporarily unavailable') or tostring(err):match('locked a portion of the file'); " ..
	   "exitCode = notAvailable and 11 or 12; os.exit(exitCode)\""
	local _ok, _, _code = os.execute(_cmd)
	return _ok, _code
end

local _lock
local _lockedFile = io.open("assets/test.file", "ab")
test["lock_file (passed file)"] = function ()
	local _error
	_lock, _error = eliFs.lock_file(_lockedFile, "w")
	test.assert(_lock ~= nil, _error)
	local _ok, _code, _ = _external_lock"assets/test.file"
	test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
end
test["lock (active - passed file)"] = function ()
	test.assert(_lock:is_active(), "Lock should be active")
end

test["unlock_file (passed file)"] = function ()
	local _ok, _code, _ = _external_lock"assets/test.file"
	test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
	local _ok, _error = eliFs.unlock_file(_lock)
	test.assert(_ok, _error)
	local _ok, _code, _ = _external_lock"assets/test.file"
	test.assert(_ok and _code == 0, "Should be able to lock now!")
end

test["lock (not active - passed file)"] = function ()
	test.assert(not _lock:is_active(), "Lock should not be active")
end
if _lockedFile ~= nil then _lockedFile:close() end

local _lock
test["lock_file (owned file)"] = function ()
	local _error
	_lock, _error = eliFs.lock_file("assets/test.file", "w")
	test.assert(_lock ~= nil, _error)
	local _ok, _code, _ = _external_lock"assets/test.file"
	test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
end
test["lock (active - owned file)"] = function ()
	test.assert(_lock:is_active(), "Lock should be active")
end
test["unlock_file (owned file)"] = function ()
	local _ok, _code, _ = _external_lock"assets/test.file"
	test.assert(not _ok and _code == 11, "Should not be able to lock twice!")
	local _ok, _error = eliFs.unlock_file(_lock)
	test.assert(_ok, _error)
	local _ok, _code, _ = _external_lock"assets/test.file"
	test.assert(_ok and _code == 0, "Should be able to lock now!")
end

test["lock (not active - owned file)"] = function ()
	test.assert(not _lock:is_active(), "Lock should not be active")
end

test["lock (cleanup)"] = function ()
	function t()
		local _lock, _error = eliFs.lock_file("assets/test.file", "w")
		test.assert(_lock ~= nil, _error)
		_lock:unlock()
	end

	t()
	-- we would segfault/sigbus here if cleanup does not work properly
	test.assert(true)
end

test["lock_file (owned file - <close>)"] = function ()
	do
		local _lock <close>, _error = eliFs.lock_file("assets/test.file", "w")
		test.assert(_lock ~= nil, _error)
		test.assert(_lock:is_active(), "Lock should be active")
	end
	local _lock <close>, _error = eliFs.lock_file("assets/test.file", "w")
	test.assert(_lock ~= nil, _error)
	test.assert(_lock:is_active(), "Lock should be active")
end

test["lock_dir & unlock_dir"] = function ()
	local _lock, _error = eliFs.lock_dir"tmp"
	test.assert(_lock, _error)
	test.assert(_lock:is_active(), "Lock should be active")
	local _ok, _locked = eliFs.safe_link_info"tmp/lockfile"
	test.assert(_ok and _locked)
	local _ok, _error = eliFs.safe_unlock_dir(_lock)
	test.assert(_ok, _error)
	test.assert(not _lock:is_active(), "Lock should not be active")
	local _ok, _locked = eliFs.safe_link_info"tmp/lockfile"
	test.assert(_ok and not _locked)
end

if not TEST then test.summary() end
