local io = require"io"
local eli_path = require"eli.path"
local util = require"eli.util"
local hash = require"eli.hash"
local dir = eli_path.dir
local combine = eli_path.combine
local table_extensions = require"eli.extensions.table"
local is_fs_extra_loaded, fs_extra = pcall(require, "eli.fs.extra")

local function check_efs_available(operation)
	if not is_fs_extra_loaded then
		if operation ~= nil and operation ~= "" then
			error("Extra fs api not available! Operation " .. operation .. " failed!")
		else
			error"Extra fs api not available!"
		end
	end
end

local fs = {
	---#DES 'fs.EFS'
	---@type boolean
	EFS = is_fs_extra_loaded,
}

---@class AccessFileOptions
---@field binary_mode boolean
---@field append boolean

---#DES 'fs.read_file'
---
---Reads file from path
---@param path string
---@param options AccessFileOptions?
---@return string
function fs.read_file(path, options)
	---@type AccessFileOptions
	options = util.merge_tables({ binary_mode = true }, options, true)
	local f <close> = assert(io.open(path, options.binary_mode and "rb" or "r"), "No such a file or directory - " .. path)
	local result = f:read"a*"
	return result
end

---#DES 'fs.write_file'
---
---Writes content into file in specified path
---@param path string
---@param content string
---@param options AccessFileOptions?
function fs.write_file(path, content, options)
	---@type AccessFileOptions
	options = util.merge_tables({ binary_mode = true, append = false }, options, true)
	local mode = options.binary_mode and "wb" or "w"
	if options.append then
		mode = options.binary_mode and "ab" or "a"
	end
	local f <close> = assert(io.open(path, mode), "No such a file or directory - " .. path)
	f:write(content)
end

---#DES 'fs.copy_file'
---
---Copies file from src to dst
---@param source string | file*
---@param destination string | file*
---@param options AccessFileOptions?
function fs.copy_file(source, destination, options)
	assert(source ~= destination, "Identical source and destiontion path!")
	assert(type(source) == "string" or (tostring(source):find"file" == 1),
		"Invalid type of source! (Has to be string or file*)")
	assert(type(destination) == "string" or (tostring(destination):find"file" == 1),
		"Invalid type of destination! (Has to be string or file*)")

	options = util.merge_tables({ binary_mode = true }, options, true)
	local file_info = fs.file_info(source)
	local permissions = (file_info or {}).permissions or "rw-r--r--"
	---@type file*, file*
	local source_file, destination_file
	if type(source) == "string" then
		source_file = assert(io.open(source, options.binary_mode and "rb" or "r"),
			"no such a file or directory - " .. source)
	else
		source_file = source
	end
	if type(destination) == "string" then
		destination_file = assert(io.open(destination, options.binary_mode and "wb" or "w"),
			"failed to open file for write - " .. destination)
	else
		destination_file = destination
	end

	local size = 2 ^ 12 -- 4K
	while true do
		local block = source_file:read(size)
		if not block then
			break
		end
		destination_file:write(block)
	end
	if type(source) == "string" then source_file:close() end
	if type(destination) == "string" then destination_file:close() end
	if type(destination) == "string" then
		fs.chmod(destination, permissions)
	end
end

---@class FsCopyoptions
---@field overwrite boolean?
---@field ignore string[]|fun(path: string, full_path: string): boolean?

---#DES fs.copy'
---
---@param src string
---@param dst string
---@param options any
function fs.copy(src, dst, options)
	if type(options) ~= "table" then
		options = {}
	end
	if fs.file_type(src) ~= "directory" then
		return fs.copy_file(src, dst, options)
	end
	check_efs_available"read_dir"
	local source_files = fs.read_dir(src, { recurse = true, return_full_paths = false }) --[=[@as string[]]=]
	for _, source_file in ipairs(source_files) do
		if type(options.ignore) == "function" and options.ignore(source_file, src) then
			goto continue
		end
		if type(options.ignore) == "table" and table_extensions.includes(options.ignore, source_file) then
			goto continue
		end

		local destination_file = eli_path.combine(dst, source_file)
		if fs.file_type(source_file --[[@as string]]) == "directory" then
			if fs.exists(destination_file) and fs.file_type(destination_file) ~= "directory" then
				error"Cannot copy directory to file!"
			end
			local file_info = fs.file_info(source_file) or {}
			fs.mkdirp(destination_file)
			fs.chmod(destination_file, file_info.permissions or "rw-r--r--")
		elseif not fs.exists(destination_file) or options.overwrite then
			fs.mkdirp(eli_path.dir(destination_file))
			fs.copy_file(eli_path.combine(src, source_file) --[[@as string]], destination_file, options)
		end
		::continue::
	end
end

---Creates directory
---@param path string
---@param mkdir (fun(path: string))?
---@param scope_name string
local function internal_mkdir(path, mkdir, scope_name)
	local mkdir = type(fs.mkdir) == "function" and mkdir
	if type(mkdir) ~= "function" and is_fs_extra_loaded then
		mkdir = fs_extra.mkdir
	end
	if type(mkdir) ~= "function" then
		-- we do not have any mkdir avaialble
		-- we can silently ignore this if dir already exists
		local f = io.open(path)
		if f == nil then
			check_efs_available(scope_name)
			return -- we error line above if efs not available
		end
		local _, _, error_code = f:read(0)
		if error_code == 21 or (f:read(0) and f:seek"end" ~= 0) then
			-- dir already exists
			return
		end
		check_efs_available(scope_name)
		return -- we error line above if efs not available
	end
	mkdir(path)
end

---#DES 'fs.mkdir'
---
---Creates directory
---@param path string
---@param mkdir (fun(path: string))?
function fs.mkdir(path, mkdir)
	internal_mkdir(path, mkdir, "mkdir")
end

---#DES 'fs.mkdirp'
---
---Creates directory recursively
---@param path string
---@param mkdir (fun(path: string))?
function fs.mkdirp(path, mkdir)
	local parent = dir(path)
	if parent ~= nil then
		fs.mkdirp(parent, mkdir)
	end
	internal_mkdir(path, mkdir, "mkdirp")
end

---#DES 'fs.create_dir'
---
---Creates directory (recursively if recurse set to true)
---@param path string
---@param recurse boolean
---@param mkdir fun(path: string)
function fs.create_dir(path, recurse, mkdir)
	if recurse then
		fs.mkdirp(path, mkdir)
	else
		internal_mkdir(path, mkdir, "create_dir")
	end
end

---@class FsRemoveOptions
---@field recurse boolean?
---@field content_only boolean?
---@field follow_links boolean?
---@field keep (fun(path: string, full_path: string): boolean?)? whitelist function for files to keep
---@field root string? path to strip from path before passing to keep function, this is usually done internally

local function remove_link_target(path)
	local link_info = fs_extra.link_info(path)
	local link_target = type(link_info) == "table" and link_info.target -- only links have target
	if type(link_target) == "string" then
		local ok, err = os.remove(link_target)
		assert(ok, err or "")
	end
end

---#DES 'fs.remove'
---
---Removes file or directory
---(if EFS is false dir has to be empty and options are ignored)
---@param path string
---@param options FsRemoveOptions?
---@return boolean
function fs.remove(path, options)
	assert(type(path) == "string", "Invalid path type!")
	options = util.merge_tables({ root = path }, options, true)
	local path_relative_to_root = path:sub(#options.root + 1) -- strip root
	if path_relative_to_root:sub(1, 1) == "/" then path_relative_to_root = path_relative_to_root:sub(2) end
	if path_relative_to_root == "" then path_relative_to_root = "." end

	if not is_fs_extra_loaded then -- fallback to os delete
		if type(options.keep) == "function" and options.keep(path_relative_to_root, path) then
			return false
		end
		local ok, err = os.remove(path)
		assert(ok, err or "")
		return true
	end

	local recurse = options.recurse
	local contentOnly = options.content_only
	options.content_only = false         -- for recursive calls

	if fs_extra.link_type(path) == nil then -- does not exist
		return true
	end

	if fs_extra.file_type(path) == "directory" and (fs_extra.link_type(path) ~= "link" or options.follow_links) then
		-- do not process directory if it is meant to be kept
		path_relative_to_root = eli_path.normalize(path_relative_to_root, nil, { endsep = true }) --[[@as string]]
		if type(options.keep) == "function" and options.keep(path_relative_to_root, path) then
			return false
		end
		local are_all_children_remove = true
		if recurse then
			for o in fs_extra.iter_dir(path) do
				if o ~= "." and o ~= ".." then
					are_all_children_remove = fs.remove(combine(path, o), options) and are_all_children_remove
				end
			end
		end
		if not contentOnly or not are_all_children_remove then
			fs_extra.rmdir(path)
			if options.follow_links then
				-- remove link target if it exists and we are following links
				remove_link_target(path)
			end
			return true
		end
		return false
	end

	if type(options.keep) == "function" and options.keep(path_relative_to_root, path) then
		return false
	end
	local ok, err = os.remove(path)
	assert(ok, err or "")

	if options.follow_links then
		-- remove link target if it exists and we are following links
		remove_link_target(path)
	end
	return true
end

---#DES 'fs.move'
---
---Renames file or directory
---@param src string
---@param dst string
function fs.move(src, dst)
	return require"os".rename(src, dst)
end

---#DES 'fs.exists'
---
---Returns true if specified path exists
---@param path string
---@return boolean
function fs.exists(path)
	local ok, _, code = os.rename(path, path)
	return ok or code == 13
end

---#DES 'fs.exists'
---
---Returns true if specified path exists
---@param path string
---@return boolean
function fs.dir_exists(path)
	path = path:sub(#path, #path) == "/" and path or path .. "/"
	return fs.exists(path)
end

---@class FsHashFileOptions: AccessFileOptions
---@field type '"sha256"'| '"sha512"'
---@field hex boolean?
---@field binary_mode boolean?

---#DES 'fs.hash_file'
---
---Hashes file in specified path
---@param path_or_file string | file*
---@param options? FsHashFileOptions
---@return string
function fs.hash_file(path_or_file, options)
	options = util.merge_tables({ type = "sha256", binary_mode = true }, options, true)
	util.print_table(options)
	local source_file
	if type(path_or_file) == "string" then
		source_file = assert(io.open(path_or_file, options.binary_mode and "rb" or "r"),
			"No such a file or directory - " .. path_or_file)
	else
		assert(tostring(path_or_file):find"file" == 1, "Not a file* - (" .. tostring(path_or_file) .. ")")
		source_file = path_or_file
	end
	local size = 2 ^ 12 -- 4K

	if options.type == "sha256" then
		local ctx = hash.sha256_init()
		while true do
			local block = source_file:read(size)
			if not block then
				break
			end
			ctx:update(block)
		end
		return ctx:finish(options.hex)
	else
		local ctx = hash.sha512_init()
		while true do
			local block = source_file:read(size)
			if not block then
				break
			end
			ctx:update(block)
		end
		return ctx:finish(options.hex)
	end
end

local function get_direntry_type(entry)
	if type(entry) == "string" then
		return fs_extra.file_type(entry)
	elseif type(entry) == "ELI_DIRENTRY" or (type(entry) == "userdata" and entry.__type == "ELI_DIRENTRY") then
		return entry:type()
	end
	return nil
end

local function read_dir_recurse(path, as_dir_entries, length_of_path_to_remove)
	if type(length_of_path_to_remove) ~= "number" then
		length_of_path_to_remove = 0
	end
	local entries = fs_extra.read_dir(path, as_dir_entries)
	local result = {}
	for _, entry in ipairs(entries) do
		local path = as_dir_entries and entry:fullpath() or combine(path, entry)
		if get_direntry_type(as_dir_entries and entry or path) == "directory" then
			local subentries = read_dir_recurse(path, as_dir_entries, length_of_path_to_remove)
			for _, subentry in ipairs(subentries) do
				table.insert(result, subentry)
			end
		end
		table.insert(result, as_dir_entries and entry or path:sub(length_of_path_to_remove + 1))
	end
	return result
end

---@class FsReadDirOptions
---@field recurse boolean?
---@field return_full_paths boolean?
---@field as_dir_entries boolean?

---@class DirEntry
---@field name fun(self: DirEntry): string
---@field type fun(self: DirEntry): string
---@field fullpath fun(self: DirEntry): string
---@field __type '"ELI_DIRENTRY"'

---#DES 'fs.read_dir'
---
---Reads directory and returns dir entire or paths based on options
---@param path string
---@param options FsReadDirOptions?
---@return string[]|DirEntry[]
function fs.read_dir(path, options)
	check_efs_available"read_dir"
	options = util.merge_tables({}, options, true)

	if fs.file_type(path) ~= "directory" then
		error("Not a directory: " .. path)
	end

	--- // TODO: remove recursive in next release
	if options.recursive ~= nil and options.recurse == nil then
		options.recurse = options.recursive
		print"Recursive option is deprecated, use recurse instead!"
	end

	--- // TODO: remove asDirEntries in next release
	if options.asDirEntries ~= nil and options.as_dir_entries == nil then
		options.as_dir_entries = options.asDirEntries
		print"AsDirEntries option is deprecated, use as_dir_entries instead!"
	end

	-- // TODO: remove returnFullPaths in the next release
	if options.returnFullPaths ~= nil and options.return_full_paths == nil then
		options.return_full_paths = options.returnFullPaths
		print"ReturnFullPaths option is deprecated, use return_full_paths instead!"
	end

	if options.recurse then
		local pattern = package.config:sub(1, 1) == "\\" and ".*\\$" or ".*/$"
		local length_of_path_to_remove = path:match(pattern) and #path or #path + 1
		if options.return_full_paths then
			length_of_path_to_remove = 0
		end
		return read_dir_recurse(path, options.as_dir_entries, length_of_path_to_remove)
	end
	local result = fs_extra.read_dir(path, options.as_dir_entries)
	if not options.as_dir_entries and options.return_full_paths then
		for i, v in ipairs(result) do
			result[i] = combine(path, v)
		end
	end
	return result
end

---@class FsChownOptions
---@field recurse boolean?
---@field recurse_ignore_errors boolean?

---#DES 'fs.chown'
---
---Sets ownership of file in the path
---@param path string
---@param uid integer
---@param gid integer
---@param options FsChownOptions?
---@return boolean, string?, number?
function fs.chown(path, uid, gid, options)
	check_efs_available"chown"
	options = util.merge_tables({ recurse_ignore_errors = true }, options, true)
	if not options.recurse or fs_extra.file_type(path) ~= "directory" then
		return fs_extra.chown(path, uid, gid)
	end

	local ok, err, errno = fs_extra.chown(path, uid, gid)
	if not ok and not options.recurse_ignore_errors then
		return ok, err, errno
	end

	local paths = fs.read_dir(path, { recurse = true, return_full_paths = true })
	for _, path in ipairs(paths) do
		ok, err, errno = fs_extra.chown(path, uid, gid)
		if not ok and not options.recurse_ignore_errors then
			return ok, err, errno
		end
	end
	return true
end

---@class FsChmodOptions
---@field recurse boolean?
---@field recurse_ignore_errors boolean?

---#DES 'fs.chmod'
---
---Sets file flags in the path
---@param path string
---@param mode integer|string
---@param options FsChmodOptions?
---@return boolean, string?, number?
function fs.chmod(path, mode, options)
	check_efs_available"chmod"
	options = util.merge_tables({}, options, true)

	if type(mode) == "string" then
		mode = mode .. string.rep("-", 9 - #mode)
	end
	if not options.recurse or fs_extra.file_type(path) ~= "directory" then
		return fs_extra.chmod(path, mode)
	end

	if type(options.recurse_ignore_errors) ~= "boolean" then
		options.recurse_ignore_errors = true
	end

	local ok, err, errno = fs_extra.chmod(path, mode)
	if not ok and not options.recurse_ignore_errors then
		return ok, err, errno
	end

	local paths = fs.read_dir(path, { recurse = true, return_full_paths = true })
	for _, path in ipairs(paths) do
		ok, err, errno = fs_extra.chmod(path, mode)
		if not ok and not options.recurse_ignore_errors then
			return ok, err, errno
		end
	end
	return true
end

---#DES 'fs.EliFileLock'
---
---@class EliFileLock
---@field free fun(eliFileLock: EliFileLock):nil
---@field unlock fun(eliFileLock: EliFileLock):nil
---@field is_active fun(eliFileLock: EliFileLock): boolean
---@field __type '"ELI_FILE_LOCK"'

local ELI_FILE_LOCK_ID = "ELI_FILE_LOCK"

---#DES 'fs.lock_file'
---
---Locks access to file
---@param path_or_file string|file*
---@param mode '"r"'|'"w"'
---@param start integer?
---@param len integer?
---@return EliFileLock?, string?, integer?
function fs.lock_file(path_or_file, mode, start, len)
	check_efs_available"lock_file"
	return fs_extra.lock_file(path_or_file, mode, start, len)
end

---#DES 'fs.unlock_file'
---
---Unlocks access to file
---@param fs_lock EliFileLock
---@return boolean?, string?
function fs.unlock_file(fs_lock)
	check_efs_available"unlock_file"

	if type(fs_lock) == ELI_FILE_LOCK_ID or (type(fs_lock) == "userdata" and fs_lock.__type --[[@as string]] == ELI_FILE_LOCK_ID) then
		return fs_lock --[[@as EliFileLock]]:unlock()
	else
		return false,
		   "Invalid " .. ELI_FILE_LOCK_ID .. " type! '" .. ELI_FILE_LOCK_ID ..
		   "' expected, got: " .. type(fs_lock) .. "!"
	end
end

---#DES fs.EliDirLock'
---
---@class EliDirLock
---@field free fun(eliDirLock: EliDirLock):nil
---@field unlock fun(eliDirLock: EliDirLock):nil
---@field is_active fun(eliDirLock: EliDirLock): boolean
---@field __type '"ELI_DIR_LOCK"'

local ELI_DIR_LOCK_ID = "ELI_DIR_LOCK"

---#DES 'fs.lock_directory'
---
---Locks access to directory
---@param path string
---@param lock_file_name string?
---@return EliDirLock|nil, string?
function fs.lock_directory(path, lock_file_name)
	check_efs_available"lock_dir"
	return fs_extra.lock_dir(path, lock_file_name)
end

---#DES 'fs.unlock_directory'
---
---Unlocks access to directory
---@param fs_lock EliDirLock
---@return boolean|nil, string?
function fs.unlock_directory(fs_lock)
	if type(fs_lock) == ELI_DIR_LOCK_ID or (type(fs_lock) == "userdata" and fs_lock.__type --[[@as string]] == ELI_DIR_LOCK_ID) then
		return fs_lock --[[@as EliDirLock]]:unlock()
	else
		return false,
		   "Invalid " .. ELI_DIR_LOCK_ID .. " type! '" .. ELI_DIR_LOCK_ID .. "' expected, got: " .. type(fs_lock) .. "!"
	end
end

---#DES 'fs.file_type'
---
---returns type of file
---@param path string
---@return boolean|nil, string
function fs.file_type(path)
	local last_character = path:sub(#path, #path)
	if table_extensions.includes({ "/", "\\" }, last_character) then
		path = path:sub(1, #path - 1)
	end
	return fs_extra.file_type(path)
end

---#DES 'fs.file_type'
---
---returns type of file
---@param path_or_file string|file*
---@return boolean|nil, string
function fs.file_info(path_or_file)
	if type(path_or_file) == "string" then
		local last_character = path_or_file:sub(#path_or_file, #path_or_file)
		if table_extensions.includes({ "/", "\\" }, last_character) then
			path_or_file = path_or_file:sub(1, #path_or_file - 1)
		end
	end
	return fs_extra.file_info(path_or_file)
end

if is_fs_extra_loaded then
	local result = util.generate_safe_functions(util.merge_tables(fs, fs_extra))
	result.safe_iter_dir = nil -- not supported
	return result
else
	return util.generate_safe_functions(fs)
end
