local test = require"u-test"
local ok, eli_fs = pcall(require, "eli.fs")
local eli_path = require"eli.path"

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
	local ok, err = eli_fs.safe_copy_file("assets/test.file",
		"tmp/test.file")
	test.assert(ok, err)
	local ok, file_hash = eli_fs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	local ok, file_hash2 =
	   eli_fs.safe_hash_file("tmp/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy file (file*)"] = function ()
	do
		local src <close> = io.open("assets/test.file", "rb")
		local dst <close> = io.open("tmp/test.file2", "wb")
		local ok, err = eli_fs.safe_copy_file(src, dst)
		test.assert(ok, err)
	end
	local ok, file_hash = eli_fs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	local ok, file_hash2 = eli_fs.safe_hash_file("tmp/test.file2", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy file (mixed)"] = function ()
	do
		local src <close> = io.open("assets/test.file", "rb")
		local ok, err = eli_fs.safe_copy_file(src, "tmp/test.file3")
		test.assert(ok, err)
	end
	local ok, file_hash = eli_fs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	local ok, file_hash2 = eli_fs.safe_hash_file("tmp/test.file3", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")

	do
		local dst <close> = io.open("tmp/test.file4", "wb")
		local ok, err = eli_fs.safe_copy_file("assets/test.file", dst)
		test.assert(ok, err)
	end

	local ok, file_hash2 = eli_fs.safe_hash_file("tmp/test.file4", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy file (permissions)"] = function ()
	local ok, err = eli_fs.safe_copy_file("assets/test.bin",
		"tmp/test.bin")
	test.assert(ok, err)
	local info = eli_fs.file_info"assets/test.bin"
	local info2 = eli_fs.file_info"tmp/test.bin"
	test.assert(info.permissions == info2.permissions, "permissions do not match")
end

test["copy (file)"] = function ()
	local ok, err = eli_fs.safe_copy("assets/test.file",
		"tmp/test.file")
	test.assert(ok, err)
	local ok, file_hash = eli_fs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	local ok, file_hash2 =
	   eli_fs.safe_hash_file("tmp/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy (directory)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local DEST_DIR = "tmp/copy-dir"
	eli_fs.remove(DEST_DIR, { recurse = true })
	eli_fs.mkdirp(DEST_DIR)
	local ok, err = eli_fs.safe_copy(SOURCE_DIR, DEST_DIR)
	test.assert(ok, err)
	local paths = eli_fs.read_dir(SOURCE_DIR, { recurse = true }) --[=[@as string[]]=]
	for _, file_path in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR, file_path)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local ok, file_hash = eli_fs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		local destFilePath = eli_path.combine(DEST_DIR, file_path)
		local ok, file_hash2 =
		   eli_fs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		test.assert(file_hash == file_hash2,
			"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
		::continue::
	end
end

test["copy (directory - overwrite)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local SOURCE_DIR2 = "assets/copy-dir2"
	local DEST_DIR = "tmp/copy-dir2"
	eli_fs.remove(DEST_DIR, { recurse = true })
	eli_fs.mkdirp(DEST_DIR)
	local ok, err = eli_fs.safe_copy(SOURCE_DIR, DEST_DIR)
	test.assert(ok, err)
	local paths = eli_fs.read_dir(SOURCE_DIR, { recurse = true }) --[=[@as string[]]=]
	for _, file_path in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR, file_path)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local ok, file_hash = eli_fs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		local destFilePath = eli_path.combine(DEST_DIR, file_path)
		local ok, file_hash2 =
		   eli_fs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		test.assert(file_hash == file_hash2,
			"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
		::continue::
	end

	local ok, err = eli_fs.safe_copy(SOURCE_DIR2, DEST_DIR)
	test.assert(ok, err)
	for _, filePath in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR, filePath)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local ok, file_hash = eli_fs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		local destFilePath = eli_path.combine(DEST_DIR, filePath)
		local ok, file_hash2 =
		   eli_fs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		test.assert(file_hash == file_hash2,
			"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
		::continue::
	end

	local ok, err = eli_fs.safe_copy(SOURCE_DIR2, DEST_DIR, { overwrite = true })
	test.assert(ok, err)
	local paths = eli_fs.read_dir(SOURCE_DIR2, { recurse = true }) --[=[@as string[]]=]
	for _, file_path in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR2, file_path)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local ok, file_hash = eli_fs.safe_hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		local destFilePath = eli_path.combine(DEST_DIR, file_path)
		local ok, file_hash2 =
		   eli_fs.safe_hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(ok, file_hash)
		test.assert(file_hash == file_hash2,
			"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
		::continue::
	end
end

test["copy (directory + filtering)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local DEST_DIR = "tmp/copy-dir3"
	eli_fs.remove(DEST_DIR, { recurse = true })
	eli_fs.mkdirp(DEST_DIR)
	local ok, err = eli_fs.safe_copy(SOURCE_DIR, DEST_DIR, { ignore = { "file.txt" } })
	test.assert(ok, err)
	test.assert(not eli_fs.exists(eli_path.combine(DEST_DIR, "file.txt")), "file.txt should not exist")

	eli_fs.remove(DEST_DIR, { recurse = true })
	eli_fs.mkdirp(DEST_DIR)
	local ok, err = eli_fs.safe_copy(SOURCE_DIR, DEST_DIR, {
		ignore = function (path)
			return path:match"file.txt"
		end,
	})
	test.assert(ok, err)
	test.assert(not eli_fs.exists(eli_path.combine(DEST_DIR, "file.txt")), "file.txt should not exist")
end

test["hash file (file*)"] = function ()
	local src = io.open("assets/test.file", "rb")
	local ok, file_hash = eli_fs.safe_hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	local ok, file_hash2 = eli_fs.safe_hash_file(src, { type = "sha256", hex = true })
	test.assert(ok, file_hash)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["read file"] = function ()
	local ok, file1 = eli_fs.safe_read_file"assets/test.file"
	test.assert(ok, file1)
	local ok, file2 = eli_fs.safe_read_file"tmp/test.file"
	test.assert(ok, file2)
	test.assert(file1 == file2, "written data does not match")
end

test["write file"] = function ()
	local ok, file1 = eli_fs.safe_read_file"assets/test.file"
	test.assert(ok, file1)
	local ok, err = eli_fs.safe_write_file("tmp/test.file2", file1)
	test.assert(ok, err)
	local ok, file2 = eli_fs.safe_read_file"tmp/test.file2"
	test.assert(ok, file2)
	test.assert(file1 == file2, "written data does not match")
end

test["move (file)"] = function ()
	local ok, err = eli_fs.safe_move("tmp/test.file", "tmp/test.file2")
	test.assert(ok, err)
	local ok, file1 = eli_fs.safe_read_file"assets/test.file"
	test.assert(ok, file1)
	local ok, file2 = eli_fs.safe_read_file"tmp/test.file2"
	test.assert(ok, file2)
	test.assert(file1 == file2, "written data does not match")
end

-- extra
test["mkdir"] = function ()
	local ok, err = eli_fs.safe_mkdir"tmp/test-dir"
	test.assert(ok, err)
	local _, exists = eli_fs.safe_dir_exists"tmp/test-dir"
	test.assert(exists, (exists or "not exists"))
end

test["mkdirp"] = function ()
	local ok = eli_fs.safe_mkdirp"tmp/test-dir/test/test"
	test.assert(ok)
	local ok, exists = eli_fs.safe_dir_exists"tmp/test-dir/test/test"
	test.assert(ok and exists, (exists or "not exists"))
end

test["create_dir"] = function ()
	eli_fs.safe_remove("tmp/test-dir", { recurse = true })
	local ok, err = eli_fs.safe_create_dir"tmp/test-dir"
	test.assert(ok, err)
	local _, exists = eli_fs.safe_dir_exists"tmp/test-dir"
	test.assert(exists, (exists or "not exists"))

	local ok = eli_fs.safe_create_dir"tmp/test-dir/test/test"
	test.assert(ok)
	local ok, exists = eli_fs.safe_dir_exists"tmp/test-dir/test/test"
	test.assert(ok and not exists, (exists or "exists"))

	local ok = eli_fs.safe_create_dir("tmp/test-dir/test/test", true)
	test.assert(ok)
	local ok, exists = eli_fs.safe_dir_exists"tmp/test-dir/test/test"
	test.assert(ok and exists, (exists or "not exists"))
end

test["remove (file)"] = function ()
	local ok, file1 = eli_fs.safe_remove"tmp/test.file2"
	test.assert(ok, file1)
	local ok, file2 = eli_fs.safe_read_file"tmp/test.file2"
	test.assert(not ok, file2)
	local ok, err = eli_fs.safe_move("tmp/test.file", "tmp/test.file2")
	test.assert(ok, err)
	local ok, file1 = eli_fs.safe_remove("tmp/test.file2", { recurse = true })
	test.assert(ok, file1)
	local ok, file2 = eli_fs.safe_read_file"tmp/test.file2"
	test.assert(not ok, file2)
end

test["remove (dir)"] = function ()
	local ok, file1 = eli_fs.safe_remove"tmp/test-dir/test/test"
	test.assert(ok, file1)
	local ok, exists = eli_fs.safe_exists"tmp/test-dir/test/test"
	test.assert(ok and not exists)
end

test["remove (keep)"] = function ()
	eli_fs.safe_create_dir"tmp/test-dir"

	eli_fs.safe_create_dir("tmp/test-dir/test/test", true)
	eli_fs.safe_create_dir("tmp/test-dir/test/test-another", true)

	eli_fs.safe_create_dir("tmp/test-dir/test2/test2", true)
	eli_fs.safe_create_dir("tmp/test-dir/test2/test2-another", true)

	fs.write_file("tmp/test-dir/test/test/test.file", "test")
	fs.write_file("tmp/test-dir/test2/test2/test2.file", "test")

	eli_fs.safe_remove("tmp/test-dir", {
		recurse = true,
		keep = function (path, fullpath)
			path = eli_path.normalize(path, "unix", { endsep = "leave" })
			return path == "test/test/" or path == "test2/test2/test2.file"
		end,
	})
	test.assert(eli_fs.exists"tmp/test-dir/test2/test2/test2.file")
	test.assert(eli_fs.exists"tmp/test-dir/test/test/")
	test.assert(eli_fs.exists"tmp/test-dir/test/test/test.file")

	test.assert(not eli_fs.exists"tmp/test-dir/test/test-another/")
	test.assert(not eli_fs.exists"tmp/test-dir/test2/test2-another/")
end

test["move (dir)"] = function ()
	local ok, err = eli_fs.safe_move("tmp/test-dir/test",
		"tmp/test-dir/test2")
	test.assert(ok, err)
	local ok, exists = eli_fs.safe_exists"tmp/test-dir/test2"
	test.assert(ok and exists, exists)
end

test["remove (recurse)"] = function ()
	local ok, err = eli_fs.safe_remove("tmp/test-dir", { recurse = true })
	test.assert(ok, err)
	local ok, exists = eli_fs.safe_exists"tmp/test-dir"
	test.assert(ok and not exists, exists)
end

test["remove (content_only)"] = function ()
	local ok, err = eli_fs.safe_mkdir"tmp/test-dir"
	test.assert(ok, err)
	local ok, err = eli_fs.safe_copy_file("assets/test.file",
		"tmp/test-dir/test.file")
	test.assert(ok, err)
	local ok, err = eli_fs.safe_remove("tmp/test-dir",
		{ content_only = true, recurse = true })
	test.assert(ok, err)
	local ok, exists = eli_fs.safe_exists"tmp/test-dir"
	test.assert(ok and exists, exists)
	local ok, exists = eli_fs.safe_exists"tmp/test-dir/test.file"
	test.assert(ok and not exists, exists)
end

if not eli_fs.EFS then
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
	eli_fs.safe_remove"tmp/test.file"
	local ok, file_type = eli_fs.safe_file_type"tmp/test.file"
	test.assert(ok and file_type == nil)
	local ok, err = eli_fs.safe_copy_file("assets/test.file",
		"tmp/test.file")
	test.assert(ok, err)
	local ok, file_type = eli_fs.safe_file_type"tmp/test.file"
	test.assert(ok and file_type == "file")
end

test["file_type (dir)"] = function ()
	local ok, file_type = eli_fs.safe_file_type"tmp/"
	test.assert(ok and file_type == "directory")
end

test["file_info (file)"] = function ()
	eli_fs.safe_remove"tmp/test.file"
	local ok, info = eli_fs.safe_file_info"assets/test.file"
	test.assert(ok and info ~= nil)
	test.assert(info.mode == "file")
	test.assert(type(info.size) == "number" and info.size > 0)

	local size_from_path = info.size
	local f <close> = io.open("assets/test.file", "rb")
	local ok, info = eli_fs.safe_file_info(f)
	test.assert(ok and info ~= nil)
	test.assert(info.mode == "file")
	test.assert(type(info.size) == "number" and info.size > 0)
	test.assert(info.size == size_from_path)

	local ok, info = eli_fs.safe_file_info"assets/test.file.not-existing"
	test.assert(ok and info == nil)
end

test["file_info (dir)"] = function ()
	local ok, info = eli_fs.safe_file_info"assets"
	test.assert(ok and info ~= nil)
	test.assert(info.mode == "directory")
	test.assert(type(info.size) == "number" and info.size > 0)

	local ok, info = eli_fs.safe_file_info"assets.not-existing"
	test.assert(ok and info == nil)
end


test["open_dir"] = function ()
	local ok, dir = eli_fs.safe_open_dir"tmp/"
	test.assert(ok and dir.__type == "ELI_DIR")
end

test["read_dir & iter_dir"] = function ()
	local ok, dir_entries = eli_fs.safe_read_dir"tmp/"
	test.assert(ok and #dir_entries > 0)

	local count = 0
	for _ in eli_fs.iter_dir"tmp/" do count = count + 1 end
	test.assert(#dir_entries == count)
end

local function external_lock(file)
	local cmd = (os.getenv"QEMU" or "") ..
	   " " .. arg[-1] .. " -e \"x, err = fs.lock_file('" .. file .. "','w'); " ..
	   "if etype(x) == 'ELI_FILE_LOCK' then os.exit(0); end; notAvailable = tostring(err):match('Resource temporarily unavailable') or tostring(err):match('locked a portion of the file'); " ..
	   "exitCode = notAvailable and 11 or 12; os.exit(exitCode)\""
	local ok, _, code = os.execute(cmd)
	return ok, code
end

local lock
local locked_file = io.open("assets/test.file", "ab")
test["lock_file (passed file)"] = function ()
	local err
	lock, err = eli_fs.lock_file(locked_file, "w")
	test.assert(lock ~= nil, err)
	local ok, code, _ = external_lock"assets/test.file"
	test.assert(not ok and code == 11, "Should not be able to lock twice!")
end
test["lock (active - passed file)"] = function ()
	test.assert(lock:is_active(), "Lock should be active")
end

test["unlock_file (passed file)"] = function ()
	local ok, code, _ = external_lock"assets/test.file"
	test.assert(not ok and code == 11, "Should not be able to lock twice!")
	local ok, err = eli_fs.unlock_file(lock)
	test.assert(ok, err)
	local ok, code, _ = external_lock"assets/test.file"
	test.assert(ok and code == 0, "Should be able to lock now!")
end

test["lock (not active - passed file)"] = function ()
	test.assert(not lock:is_active(), "Lock should not be active")
end
if locked_file ~= nil then locked_file:close() end

local lock
test["lock_file (owned file)"] = function ()
	local err
	lock, err = eli_fs.lock_file("assets/test.file", "w")
	test.assert(lock ~= nil, err)
	local ok, code, _ = external_lock"assets/test.file"
	test.assert(not ok and code == 11, "Should not be able to lock twice!")
end
test["lock (active - owned file)"] = function ()
	test.assert(lock:is_active(), "Lock should be active")
end
test["unlock_file (owned file)"] = function ()
	local ok, code, _ = external_lock"assets/test.file"
	test.assert(not ok and code == 11, "Should not be able to lock twice!")
	local ok, err = eli_fs.unlock_file(lock)
	test.assert(ok, err)
	local ok, code, _ = external_lock"assets/test.file"
	test.assert(ok and code == 0, "Should be able to lock now!")
end

test["lock (not active - owned file)"] = function ()
	test.assert(not lock:is_active(), "Lock should not be active")
end

test["lock (cleanup)"] = function ()
	function t()
		local lock, err = eli_fs.lock_file("assets/test.file", "w")
		test.assert(lock ~= nil, err)
		lock:unlock()
	end

	t()
	-- we would segfault/sigbus here if cleanup does not work properly
	test.assert(true)
end

test["lock_file (owned file - <close>)"] = function ()
	do
		local lock <close>, err = eli_fs.lock_file("assets/test.file", "w")
		test.assert(lock ~= nil, err)
		test.assert(lock:is_active(), "Lock should be active")
	end
	local lock <close>, err = eli_fs.lock_file("assets/test.file", "w")
	test.assert(lock ~= nil, err)
	test.assert(lock:is_active(), "Lock should be active")
end

test["lock_dir & unlock_dir"] = function ()
	local lock, err = eli_fs.lock_dir"tmp"
	test.assert(lock, err)
	test.assert(lock:is_active(), "Lock should be active")
	local ok, locked = eli_fs.safe_link_info"tmp/lockfile"
	test.assert(ok and locked)
	local ok, err = eli_fs.safe_unlock_dir(lock)
	test.assert(ok, err)
	test.assert(not lock:is_active(), "Lock should not be active")
	local ok, locked = eli_fs.safe_link_info"tmp/lockfile"
	test.assert(ok and not locked)
end

if not TEST then test.summary() end
