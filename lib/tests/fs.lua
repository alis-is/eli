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
	local ok, err = eli_fs.copy_file("assets/test.file",
		"tmp/test.file")
	test.assert(ok, err)
	local file_hash, err = eli_fs.hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(file_hash, err)
	local file_hash2, err = eli_fs.hash_file("tmp/test.file", { type = "sha256", hex = true })
	test.assert(file_hash2, err)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy file (file*)"] = function ()
	do
		local src <close> = assert(io.open("assets/test.file", "rb"))
		local dst <close> = assert(io.open("tmp/test.file2", "wb"))
		local ok, err = eli_fs.copy_file(src, dst)
		test.assert(ok, err)
	end
	local file_hash, err = eli_fs.hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(file_hash, err)
	local file_hash2, err = eli_fs.hash_file("tmp/test.file2", { type = "sha256", hex = true })
	test.assert(file_hash2, err)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy file (mixed)"] = function ()
	do
		local src <close> = assert(io.open("assets/test.file", "rb"))
		local ok, err = eli_fs.copy_file(src, "tmp/test.file3")
		test.assert(ok, err)
	end
	local file_hash, err = eli_fs.hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(file_hash, err)
	local file_hash2, err = eli_fs.hash_file("tmp/test.file3", { type = "sha256", hex = true })
	test.assert(file_hash2, err)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
	do
		local dst <close> = assert(io.open("tmp/test.file4", "wb"))
		local ok, err = eli_fs.copy_file("assets/test.file", dst)
		test.assert(ok, err)
	end

	local file_hash2, err = eli_fs.hash_file("tmp/test.file4", { type = "sha256", hex = true })
	test.assert(file_hash2, err)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy file (permissions)"] = function ()
	local ok, err = eli_fs.copy_file("assets/test.bin",
		"tmp/test.bin")
	test.assert(ok, err)
	local info = eli_fs.file_info"assets/test.bin"
	local info2 = eli_fs.file_info"tmp/test.bin"
	test.assert(info.permissions == info2.permissions, "permissions do not match")
end

test["copy (file)"] = function ()
	local ok, err = eli_fs.copy("assets/test.file",
		"tmp/test.file")
	test.assert(ok, err)
	local file_hash, err = eli_fs.hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(file_hash, err)
	local file_hash2, err = eli_fs.hash_file("tmp/test.file", { type = "sha256", hex = true })
	test.assert(file_hash2, err)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["copy (directory)"] = function ()
	local SOURCE_DIR = "assets/copy-dir"
	local DEST_DIR = "tmp/copy-dir"
	eli_fs.remove(DEST_DIR, { recurse = true })
	eli_fs.mkdirp(DEST_DIR)
	local ok, err = eli_fs.copy(SOURCE_DIR, DEST_DIR)
	test.assert(ok, err)
	local paths = eli_fs.read_dir(SOURCE_DIR, { recurse = true }) --[=[@as string[]]=]
	for _, file_path in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR, file_path)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local file_hash, err = eli_fs.hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(file_hash, err)
		local destFilePath = eli_path.combine(DEST_DIR, file_path)
		local file_hash2, err = eli_fs.hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(file_hash2, err)
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
	local ok, err = eli_fs.copy(SOURCE_DIR, DEST_DIR)
	test.assert(ok, err)
	local paths = eli_fs.read_dir(SOURCE_DIR, { recurse = true }) --[=[@as string[]]=]
	for _, file_path in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR, file_path)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local file_hash, err = eli_fs.hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(file_hash, err)
		local destFilePath = eli_path.combine(DEST_DIR, file_path)
		local file_hash2, err = eli_fs.hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(file_hash2, err)
		test.assert(file_hash == file_hash2,
			"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
		::continue::
	end

	local ok, err = eli_fs.copy(SOURCE_DIR2, DEST_DIR)
	test.assert(ok, err)
	for _, filePath in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR, filePath)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local file_hash, err = eli_fs.hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(file_hash, err)
		local destFilePath = eli_path.combine(DEST_DIR, filePath)
		local file_hash2, err = eli_fs.hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(file_hash2, err)
		test.assert(file_hash == file_hash2,
			"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
		::continue::
	end

	local ok, err = eli_fs.copy(SOURCE_DIR2, DEST_DIR, { overwrite = true })
	test.assert(ok, err)
	local paths = eli_fs.read_dir(SOURCE_DIR2, { recurse = true }) --[=[@as string[]]=]
	for _, file_path in ipairs(paths) do
		local sourceFilePath = eli_path.combine(SOURCE_DIR2, file_path)
		if eli_fs.file_type(sourceFilePath) == "directory" then
			goto continue
		end
		local file_hash, err = eli_fs.hash_file(sourceFilePath, { type = "sha256", hex = true })
		test.assert(file_hash, err)
		local destFilePath = eli_path.combine(DEST_DIR, file_path)
		local file_hash2, err = eli_fs.hash_file(destFilePath, { type = "sha256", hex = true })
		test.assert(file_hash2, err)
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
	local ok, err = eli_fs.copy(SOURCE_DIR, DEST_DIR, { ignore = { "file.txt" } })
	test.assert(ok, err)
	test.assert(not eli_fs.exists(eli_path.combine(DEST_DIR, "file.txt")), "file.txt should not exist")

	eli_fs.remove(DEST_DIR, { recurse = true })
	eli_fs.mkdirp(DEST_DIR)
	local ok, err = eli_fs.copy(SOURCE_DIR, DEST_DIR, {
		ignore = function (path)
			return path:match"file.txt"
		end,
	})
	test.assert(ok, err)
	test.assert(not eli_fs.exists(eli_path.combine(DEST_DIR, "file.txt")), "file.txt should not exist")
end

test["hash file (file*)"] = function ()
	local src = assert(io.open("assets/test.file", "rb"))
	local file_hash, err = eli_fs.hash_file("assets/test.file", { type = "sha256", hex = true })
	test.assert(file_hash, err)
	local file_hash2, err = eli_fs.hash_file(src, { type = "sha256", hex = true })
	test.assert(file_hash2, err)
	test.assert(file_hash == file_hash2,
		"hashes do not match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["read file"] = function ()
	local ok, err = eli_fs.copy("assets/test.file", "tmp/test.file", { overwrite = true })
	test.assert(ok, err)
	local file1, err = eli_fs.read_file"assets/test.file"
	test.assert(file1, err)
	local file2, err = eli_fs.read_file"tmp/test.file"
	test.assert(file2, err)
	test.assert(file1 == file2, "written data does not match")
end

test["write file"] = function ()
	local file1, err = eli_fs.read_file"assets/test.file"
	test.assert(file1, err)
	local ok, err = eli_fs.write_file("tmp/test.file2", file1)
	test.assert(ok, err)
	local file2, err = eli_fs.read_file"tmp/test.file2"
	test.assert(file2, err)
	test.assert(file1 == file2, "written data does not match")
end

test["move (file)"] = function ()
	local ok, err = fs.remove"tmp/test.file2"
	test.assert(ok, err)
	local ok, err = eli_fs.move("tmp/test.file", "tmp/test.file2")
	test.assert(ok, err)
	local file1, err = eli_fs.read_file"assets/test.file"
	test.assert(file1, err)
	local file2, err = eli_fs.read_file"tmp/test.file2"
	test.assert(file2, err)
	test.assert(file1 == file2, "written data does not match")
end

-- extra
test["mkdir"] = function ()
	local ok, err = eli_fs.mkdir"tmp/test-dir"
	test.assert(ok, err)
	local exists = eli_fs.dir_exists"tmp/test-dir"
	test.assert(exists, (exists or "not exists"))
end

test["mkdirp"] = function ()
	local ok = eli_fs.mkdirp"tmp/test-dir/test/test"
	test.assert(ok)
	local exists = eli_fs.dir_exists"tmp/test-dir/test/test"
	test.assert(exists, "not exists")
end

test["create_dir"] = function ()
	eli_fs.remove("tmp/test-dir", { recurse = true })
	local ok, err = eli_fs.create_dir"tmp/test-dir"
	test.assert(ok, err)
	local exists = eli_fs.dir_exists"tmp/test-dir"
	test.assert(exists, "not exists")

	local ok, err = eli_fs.create_dir"tmp/test-dir/test/test"
	test.assert(not ok, "shouldn't be created")
	local exists = eli_fs.dir_exists"tmp/test-dir/test/test"
	test.assert(not exists, "exists")

	local ok, err = eli_fs.create_dir("tmp/test-dir/test/test", { recurse = true })
	test.assert(ok, err)
	local exists = eli_fs.dir_exists"tmp/test-dir/test/test"
	test.assert(exists, "not exists")
end

test["remove (file)"] = function ()
	local ok, file1 = eli_fs.remove"tmp/test.file2"
	test.assert(ok, file1)
	local ok = eli_fs.copy_file("assets/test.file", "tmp/test.file")
	test.assert(ok, "copy failed")
	local file2, _ = eli_fs.read_file"tmp/test.file2"
	test.assert(not file2, "exists")
	local ok, err = eli_fs.move("tmp/test.file", "tmp/test.file2")
	test.assert(ok, err)
	local ok, file1 = eli_fs.remove("tmp/test.file2", { recurse = true })
	test.assert(ok, file1)
	local file2, _ = eli_fs.read_file"tmp/test.file2"
	test.assert(not file2, "exists")
end

test["remove (dir)"] = function ()
	local ok, file1 = eli_fs.remove"tmp/test-dir/test/test"
	test.assert(ok, file1)
	local exists = eli_fs.exists"tmp/test-dir/test/test"
	test.assert(not exists)
end

test["remove (keep)"] = function ()
	eli_fs.create_dir"tmp/test-dir"

	eli_fs.create_dir("tmp/test-dir/test/test", true)
	eli_fs.create_dir("tmp/test-dir/test/test-another", true)

	eli_fs.create_dir("tmp/test-dir/test2/test2", true)
	eli_fs.create_dir("tmp/test-dir/test2/test2-another", true)

	eli_fs.write_file("tmp/test-dir/test/test/test.file", "test")
	eli_fs.write_file("tmp/test-dir/test2/test2/test2.file", "test")

	eli_fs.remove("tmp/test-dir", {
		recurse = true,
		keep = function (path, _)
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
	local ok, err = eli_fs.move("tmp/test-dir/test", "tmp/test-dir/test3")
	test.assert(ok, err)
	local exists = eli_fs.exists"tmp/test-dir/test3"
	test.assert(exists, "not exists")
end

test["remove (recurse)"] = function ()
	local ok, err = eli_fs.remove("tmp/test-dir", { recurse = true })
	test.assert(ok, err)
	local exists = eli_fs.exists"tmp/test-dir"
	test.assert(not exists, "exists")
end

test["remove (content_only)"] = function ()
	local ok, err = eli_fs.mkdir"tmp/test-dir"
	test.assert(ok, err)
	local ok, err = eli_fs.copy_file("assets/test.file", "tmp/test-dir/test.file")
	test.assert(ok, err)
	local ok, err = eli_fs.remove("tmp/test-dir", { content_only = true, recurse = true })
	test.assert(ok, err)
	local exists = eli_fs.exists"tmp/test-dir"
	test.assert(exists, "not exists")
	local exists = eli_fs.exists"tmp/test-dir/test.file"
	test.assert(not exists, "exists")
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
	eli_fs.remove"tmp/test.file"
	local file_type, _ = eli_fs.file_type"tmp/test.file"
	test.assert(not file_type, "exists")
	local ok, err = eli_fs.copy_file("assets/test.file", "tmp/test.file")
	test.assert(ok, err)
	local file_type, err = eli_fs.file_type"tmp/test.file"
	test.assert(file_type, err)
end

test["file_type (dir)"] = function ()
	local file_type, err = eli_fs.file_type"tmp/"
	test.assert(file_type and file_type == "directory", "not a directory: " .. tostring(err))
end

test["file_info (file)"] = function ()
	eli_fs.remove"tmp/test.file"
	local info, err = eli_fs.file_info"assets/test.file"
	test.assert(info, err)
	test.assert(info.mode == "file")
	test.assert(type(info.size) == "number" and info.size > 0)

	local size_from_path = info.size
	local f <close> = io.open("assets/test.file", "rb")
	local info, err = eli_fs.file_info(f)
	test.assert(info, err)
	test.assert(info.mode == "file")
	test.assert(type(info.size) == "number" and info.size > 0)
	test.assert(info.size == size_from_path)

	local info, _ = eli_fs.file_info"assets/test.file.not-existing"
	test.assert(info == nil, "exists")
end

test["file_info (dir)"] = function ()
	local info, err = eli_fs.file_info"assets"
	test.assert(info, err)
	test.assert(info.mode == "directory")
	test.assert(type(info.size) == "number" and info.size > 0)

	local info, _ = eli_fs.file_info"assets.not-existing"
	test.assert(info == nil, "exists")
end


test["open_dir"] = function ()
	local dir, err = eli_fs.open_dir"tmp/"
	test.assert(dir and dir.__type == "ELI_DIR", err or "not a directory")
end

test["read_dir & iter_dir"] = function ()
	local dir_entries = eli_fs.read_dir"tmp/"
	test.assert(ok and #dir_entries > 0)

	local count = 0
	for _ in eli_fs.iter_dir"tmp/" do count = count + 1 end
	test.assert(#dir_entries == count)
end

local function external_lock(file)
	local cmd = (os.getenv"QEMU" or "") ..
	   " " .. arg[-1] .. " -e \"x, err = fs.lock_file('" .. file .. "','w'); " ..
	   "if etype(x) == 'ELI_FILE_LOCK' then os.exit(0); end; notAvailable = tostring(err):match('Resource temporarily unavailable') or tostring(err):match('lock'); " ..
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
	local lock, err = eli_fs.lock_directory"tmp"
	test.assert(lock, err)
	test.assert(lock:is_active(), "Lock should be active")
	local locked, err = eli_fs.link_info"tmp/lockfile"
	test.assert(locked, err)
	local ok, err = eli_fs.unlock_directory(lock)
	test.assert(ok, err)
	test.assert(not lock:is_active(), "Lock should not be active")
	local locked, err = eli_fs.link_info"tmp/lockfile"
	test.assert(not locked)
end

if not TEST then test.summary() end
