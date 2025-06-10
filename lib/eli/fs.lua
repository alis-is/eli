local io = require"io"
local eli_path = require"eli.path"
local util = require"eli.util"
local hash = require"eli.hash"
local table_extensions = require"eli.extensions.table"
local is_fs_extra_loaded, fs_extra = pcall(require, "eli.fs.extra")

---@alias T any
---@param first_arg T
local function error_efs_not_available(first_arg)
	return first_arg, "extra fs api not available"
end

local fs = {
	---#DES 'fs.EFS'
	---@type boolean
	EFS = is_fs_extra_loaded,
}

---@class AccessFileOptions
---@field binary_mode boolean?
---@field append boolean?

---#DES 'fs.read_file'
---
---Reads file from path
---@param path string
---@param options AccessFileOptions?
---@return string?, string?
function fs.read_file(path, options)
	---@type AccessFileOptions
	options = util.merge_tables({ binary_mode = true }, options, true)
	local f <close>, err = io.open(path, options.binary_mode and "rb" or "r")
	if not f then
		return nil, err
	end
	return f:read"a*"
end

---@class WriteFileOptions: AccessFileOptions
---@field atomic boolean?

---#DES 'fs.write_file'
---
---Writes content into file in specified path
---@param path string
---@param content string
---@param options WriteFileOptions?
---@return boolean, string?
function fs.write_file(path, content, options)
	---@type WriteFileOptions
	options = util.merge_tables({ binary_mode = true, append = false, atomic = false }, options, true)

	local mode = (options.append and "a" or "w") .. (options.binary_mode and "b" or "")
	local target_path = options.atomic and (path .. ".tmp") or path

	local f, err = io.open(target_path, mode)
	if not f then
		return false, err or ("failed to open file for write - " .. path)
	end
	local ok, write_err = f:write(content)
	f:close()
	if not ok then
		return false, write_err or ("failed to write content to file - " .. path)
	end
	if options.atomic then
		local ok, err = os.rename(target_path, path)
		if not ok then
			os.remove(target_path)
			return false, err or "failed to rename file to atomic write target"
		end
	end
	return true
end

---#DES 'fs.copy_file'
---
---Copies file from src to dst
---@param source string | file*
---@param destination string | file*
---@param options AccessFileOptions?
---@return boolean, string?
function fs.copy_file(source, destination, options)
	assert(source ~= destination, "identical source and destination path")
	assert(type(source) == "string" or io.type(source) == "file",
		"invalid type of source - has to be string or file*")
	assert(type(destination) == "string" or io.type(destination) == "file",
		"invalid type of destination - Has to be string or file*")

	options = util.merge_tables({ binary_mode = true }, options, true)
	local read_mode = options.binary_mode and "rb" or "r"
	local write_mode = options.binary_mode and "wb" or "w"

	local file_info = fs.file_info(source)
	local permissions = (file_info or {}).permissions or "rw-r--r--"

	local owns_source_file = type(source) == "string"
	local owns_destination_file = type(destination) == "string"

	local source_file, destination_file = source, destination
	local source_err, destination_err
	if owns_source_file then
		source_file, source_err = io.open(source --[[@as string]], read_mode)
		if not source_file then
			return false, source_err or ("no such a file or directory - " .. source)
		end
	end
	if owns_destination_file then
		destination_file, destination_err = io.open(destination --[[@as string]], write_mode)
		if not destination_file then
			if owns_source_file then source_file:close() end
			return false, destination_err or ("failed to open file for write - " .. destination)
		end
	end

	local size = 2 ^ 12 -- 4K
	while true do
		local block = source_file:read(size)
		if not block then
			break
		end
		local ok, err = destination_file:write(block)
		if not ok then
			if owns_source_file then source_file:close() end
			if owns_destination_file then destination_file:close() end
			return false, err or "failed to write block to destination"
		end
	end
	if owns_source_file then source_file:close() end
	if owns_destination_file then
		destination_file:close()
		fs.chmod(destination --[[@as string]], permissions)
	end
	return true
end

---@class FsCopyOptions:AccessFileOptions
---@field overwrite boolean?
---@field ignore (string[]|fun(path: string, full_path: string): boolean?)?

---#DES fs.copy'
---
---@param src string
---@param dst string
---@param options FsCopyOptions?
---@return boolean, string?
function fs.copy(src, dst, options)
	if type(options) ~= "table" then
		options = {}
	end

	if fs.file_type(src) ~= "directory" then
		return fs.copy_file(src, dst, options)
	end

	if not is_fs_extra_loaded then
		return error_efs_not_available(false)
	end

	local is_ignored = function () return false end
	if type(options.ignore) == "function" then
		is_ignored = options.ignore --[[@as function]]
	elseif type(options.ignore) == "table" then
		is_ignored = function (source_file)
			return table_extensions.includes(options.ignore --[[@as table]], source_file)
		end
	end

	local source_files = fs.read_dir(src, { recurse = true, return_full_paths = false }) --[=[@as string[]]=]

	for _, source_file in ipairs(source_files) do
		if is_ignored(source_file) then
			goto continue
		end

		local destination_file = eli_path.combine(dst, source_file)
		local source_file_full_path = eli_path.combine(src, source_file)
		if fs.file_type(source_file_full_path --[[@as string]]) == "directory" then
			if fs.exists(destination_file) and fs.file_type(destination_file) ~= "directory" then
				return false, "cannot copy a directory into a file"
			end
			local file_info = fs.file_info(source_file_full_path) or {}
			local ok, err = fs.mkdirp(destination_file)
			if not ok then return ok, err end

			local ok, err = fs.chmod(destination_file, file_info.permissions or "rw-r--r--")
			if not ok then return ok, err end
		elseif not fs.exists(destination_file) or options.overwrite then
			local ok, err = fs.mkdirp(eli_path.dir(destination_file))
			if not ok then return ok, err end

			local ok, err = fs.copy_file(source_file_full_path, destination_file, options)
			if not ok then return ok, err end
		end
		::continue::
	end
	return true
end

---Creates directory
---@param path string
---@param mkdir_override (fun(path: string): boolean, string?)?
---@return boolean, string?
local function internal_mkdir(path, mkdir_override)
	local mkdir_func = type(mkdir_override) == "function" and mkdir_override

	if not mkdir_func and is_fs_extra_loaded then
		mkdir_func = fs_extra.mkdir
	end

	if is_fs_extra_loaded then
		local file_type = fs_extra.file_type(path)
		if file_type == "directory" then
			return true
		elseif file_type then
			return false, "cannot create directory - file with the same name exists"
		end
	end

	local f <close> = io.open(path)
	if f then
		local ok = f:seek"end" ~= nil
		if ok then
			return true
		end
	end

	if mkdir_func then
		return mkdir_func(path)
	end

	return false, "mkdir unavailable and could not confirm directory existence"
end

---#DES 'fs.mkdir'
---
---Creates directory
---@param path string
---@param mkdir_override (fun(path: string): boolean, string?)?
---@return boolean, string?
function fs.mkdir(path, mkdir_override)
	return internal_mkdir(path, mkdir_override)
end

---#DES 'fs.mkdirp'
---
---Creates directory recursively
---@param path string
---@param mkdir_override (fun(path: string): boolean, string?)?
---@return boolean, string?
function fs.mkdirp(path, mkdir_override)
	local parent = eli_path.dir(path)
	if parent ~= nil then
		local ok, err = fs.mkdirp(parent, mkdir_override)
		if not ok then return false, err end
	end
	return internal_mkdir(path, mkdir_override)
end

---@class CreateDirOptions
---@field recurse boolean?
---@field mkdir_override (fun(path: string): boolean, string?)?

---#DES 'fs.create_dir'
---
---Creates directory (recursively if recurse set to true)
---@param path string
---@param optionsOrRecurse boolean|CreateDirOptions?
---@return boolean, string?
function fs.create_dir(path, optionsOrRecurse)
	if type(optionsOrRecurse) == "boolean" then
		optionsOrRecurse = { recurse = optionsOrRecurse }
	end
	if type(optionsOrRecurse) ~= "table" then
		optionsOrRecurse = {}
	end

	if optionsOrRecurse.recurse then
		return fs.mkdirp(path, optionsOrRecurse.mkdir_override)
	end
	return internal_mkdir(path, optionsOrRecurse.mkdir_override)
end

---@param path string
---@return boolean, string?
local function remove_link_target(path)
	local link_info = fs_extra.link_info(path)
	local link_target = type(link_info) == "table" and link_info.target -- only links have target
	if type(link_target) == "string" and fs.exists(link_target) then
		local ok, err = os.remove(link_target)
		if not ok then return ok, err end
	end
	return true
end

---@class FsRemoveOptions
---@field recurse boolean?
---@field content_only boolean?
---@field follow_links boolean?
---@field keep (fun(path: string, full_path: string): boolean)? whitelist function for files to keep
---@field root string? path to strip from path before passing to keep function, this is usually done internally

local ERROR_FS_REMOVE_PATH_FILTERED = "not removed: path filtered"

---@param path string
---@param options FsRemoveOptions?
---@return boolean, string?
local function internal_remove(path, options)
	assert(type(path) == "string", "invalid path type - expected string, got " .. type(path))
	options = util.merge_tables({ root = path }, options, true)
	local path_relative_to_root = path:sub(#options.root + 1) -- strip root
	if path_relative_to_root:sub(1, 1) == "/" then path_relative_to_root = path_relative_to_root:sub(2) end
	if path_relative_to_root == "" then path_relative_to_root = "." end

	local should_keep = type(options.keep) == "function" and options.keep or function (_, _) return false end

	if not is_fs_extra_loaded then -- fallback to os delete
		if should_keep(path_relative_to_root, path) then
			return false, ERROR_FS_REMOVE_PATH_FILTERED
		end
		return os.remove(path)
	end

	if fs_extra.link_type(path) == nil then -- does not exist
		return true
	end

	local recurse = options.recurse
	local content_only = options.content_only
	options.content_only = false -- for recursive calls

	if fs_extra.file_type(path) == "directory" and (fs_extra.link_type(path) ~= "link" or options.follow_links) then
		-- do not process directory if it is meant to be kept
		path_relative_to_root = eli_path.normalize(path_relative_to_root, nil, { endsep = true }) --[[@as string]]
		if should_keep(path_relative_to_root, path) then
			return false, ERROR_FS_REMOVE_PATH_FILTERED
		end
		local are_all_children_removed = true
		if recurse then
			for o in fs_extra.iter_dir(path) do
				if o ~= "." and o ~= ".." then
					local ok, err = internal_remove(eli_path.combine(path, o), options)
					if not ok and err ~= ERROR_FS_REMOVE_PATH_FILTERED then
						return ok, err
					end
					are_all_children_removed = are_all_children_removed and err ~= ERROR_FS_REMOVE_PATH_FILTERED
				end
			end
		end

		if not content_only and are_all_children_removed then
			local ok, err = fs_extra.rmdir(path)
			if not ok then return ok, err end

			if options.follow_links then
				-- remove link target if it exists and we are following links
				return remove_link_target(path)
			end
			return true
		end
		return false, ERROR_FS_REMOVE_PATH_FILTERED
	end

	if should_keep(path_relative_to_root, path) then
		return false, ERROR_FS_REMOVE_PATH_FILTERED
	end
	local ok, err = os.remove(path)
	if not ok then return ok, err end

	if options.follow_links then
		-- remove link target if it exists and we are following links
		return remove_link_target(path)
	end
	return true
end
---#DES 'fs.remove'
---
---Removes file or directory
---(if EFS is false dir has to be empty and options are ignored)
---@param path string
---@param options FsRemoveOptions?
---@return boolean, string?
function fs.remove(path, options)
	local ok, err = internal_remove(path, options)
	if not ok and err ~= ERROR_FS_REMOVE_PATH_FILTERED then
		return ok, err
	end
	return true
end

---#DES 'fs.move'
---
---Renames file or directory
---@param src string
---@param dst string
---@return boolean, string?
function fs.move(src, dst)
	return os.rename(src, dst)
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
	path = path:sub(-1) == "/" and path or path .. "/"
	return fs.exists(path)
end

---@class FsHashFileOptions: AccessFileOptions
---@field type '"sha256"'| '"sha512"' | nil defaults sha256
---@field hex boolean?
---@field binary_mode boolean?

---#DES 'fs.hash_file'
---
---Hashes file in specified path
---@param path_or_file string | file*
---@param options? FsHashFileOptions
---@return string?, string?
function fs.hash_file(path_or_file, options)
	options = util.merge_tables({ type = "sha256", binary_mode = true }, options, true)

	assert(type(path_or_file) == "string" or io.type(path_or_file) == "file",
		"invalid type of path_or_file - expected string or file*, got: " .. type(path_or_file))

	assert(options.type == "sha256" or options.type == "sha512",
		"invalid type of hash - expected 'sha256' or 'sha512', got: " .. tostring(options.type))

	local source_file, close_after = path_or_file, false
	if type(path_or_file) == "string" then
		local err
		source_file, err = io.open(path_or_file, options.binary_mode and "rb" or "r")
		if not source_file then
			return nil, err or ("no such a file or directory - " .. path_or_file)
		end
		close_after = true
	end


	local init_hasher = ({
		sha256 = hash.sha256_init,
		sha512 = hash.sha512_init,
	})[options.type]

	local ctx = init_hasher()
	local size = 2 ^ 12 -- 4K

	while true do
		local block = source_file:read(size)
		if not block then break end
		ctx:update(block)
	end

	if close_after then source_file:close() end
	return ctx:finish(options.hex)
end

local function get_direntry_type(entry)
	if type(entry) == "string" then
		return fs_extra.file_type(entry)
	elseif type(entry) == "ELI_DIRENTRY" then
		return entry:type()
	elseif type(entry) == "userdata" and entry.__type == "ELI_DIRENTRY" then
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
		local full_path = as_dir_entries and entry:fullpath() or eli_path.combine(path, entry)
		local entry_type = get_direntry_type(as_dir_entries and entry or full_path)

		if entry_type == "directory" then
			local subentries = read_dir_recurse(full_path, as_dir_entries, length_of_path_to_remove)
			for _, subentry in ipairs(subentries) do
				table.insert(result, subentry)
			end
		end

		local rel_path = as_dir_entries and entry or full_path:sub(length_of_path_to_remove + 1)
		table.insert(result, rel_path)
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
---@return (string[]|DirEntry[])?, string?
function fs.read_dir(path, options)
	if not is_fs_extra_loaded then
		return error_efs_not_available(false)
	end
	assert(type(path) == "string", "invalid path type - expected string, got: " .. type(path))

	options = util.merge_tables({}, options, true)

	if fs.file_type(path) ~= "directory" then
		return nil, "not a directory: " .. path
	end

	local recurse = options.recurse
	local return_full = options.return_full_paths
	local as_dir_entries = options.as_dir_entries

	if recurse then
		local sep = package.config:sub(1, 1) == "\\" and "\\" or "/"
		local ends_with_sep = path:sub(-1) == sep
		local strip_len = ends_with_sep and #path or #path + 1

		if return_full then
			strip_len = 0
		end

		return read_dir_recurse(path, as_dir_entries, strip_len)
	end

	local result, err = fs_extra.read_dir(path, as_dir_entries)
	if not result then
		return nil, err or ("failed to read directory - " .. path)
	end
	if not as_dir_entries and return_full then
		for i, name in ipairs(result) do
			result[i] = eli_path.combine(path, name)
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
	if not is_fs_extra_loaded then
		return error_efs_not_available(false)
	end
	options = util.merge_tables({ recurse_ignore_errors = true }, options, true)

	local is_dir = fs_extra.file_type(path) == "directory"
	local recursive = options.recurse
	local ignore_errors = options.recurse_ignore_errors ~= false

	if not recursive or not is_dir then
		return fs_extra.chown(path, uid, gid)
	end

	local ok, err, errno = fs_extra.chown(path, uid, gid)
	if not ok and not ignore_errors then
		return ok, err, errno
	end

	local entries, read_err = fs.read_dir(path, { recurse = true, return_full_paths = true })
	if not entries then
		return false, read_err or ("failed to read directory: " .. path)
	end

	for _, entry_path in ipairs(entries) do
		ok, err, errno = fs_extra.chown(entry_path, uid, gid)
		if not ok and not ignore_errors then
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
	if not is_fs_extra_loaded then
		return error_efs_not_available(false)
	end

	options = util.merge_tables({}, options, true)

	if type(mode) == "string" then
		mode = string.sub(mode .. "---------", 1, 9)
	end

	local is_dir = fs_extra.file_type(path) == "directory"
	local recursive = options.recurse
	local ignore_errors = options.recurse_ignore_errors ~= false

	if not recursive or not is_dir then
		return fs_extra.chmod(path, mode)
	end

	local ok, err, errno = fs_extra.chmod(path, mode)
	if not ok and not ignore_errors then
		return ok, err, errno
	end

	local entries, read_err = fs.read_dir(path, { recurse = true, return_full_paths = true })
	if not entries then
		return false, read_err or ("failed to read directory: " .. path)
	end

	for _, entry_path in ipairs(entries) do
		ok, err, errno = fs_extra.chmod(entry_path, mode)
		if not ok and not ignore_errors then
			return ok, err, errno
		end
	end

	return true
end

---#DES 'fs.EliFileLock'
---
---@class EliFileLock
---@field free fun(eliFileLock: EliFileLock):boolean, string?
---@field unlock fun(eliFileLock: EliFileLock):boolean, string?
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
	if not is_fs_extra_loaded then
		return error_efs_not_available(nil)
	end

	return fs_extra.lock_file(path_or_file, mode, start, len)
end

---#DES 'fs.unlock_file'
---
---Unlocks access to file
---@param fs_lock EliFileLock
---@return boolean?, string?
function fs.unlock_file(fs_lock)
	if not is_fs_extra_loaded then
		return error_efs_not_available(false)
	end

	if type(fs_lock) == ELI_FILE_LOCK_ID then
		---@cast fs_lock EliFileLock
		return fs_lock:unlock()
	elseif type(fs_lock) == "userdata" and fs_lock.__type == ELI_FILE_LOCK_ID then
		---@cast fs_lock EliFileLock
		return fs_lock:unlock()
	end

	local err_msg = string.interpolate(
		"invalid ${expected_type} type - '${expected_type}' expected, got: '${type}'",
		{
			expected_type = ELI_FILE_LOCK_ID,
			type = type(fs_lock),
		}
	)
	return false, err_msg
end

---#DES fs.EliDirLock'
---
---@class EliDirLock
---@field free fun(eliDirLock: EliDirLock): boolean, string?
---@field unlock fun(eliDirLock: EliDirLock): boolean, string?
---@field is_active fun(eliDirLock: EliDirLock): boolean
---@field __type '"ELI_DIR_LOCK"'

local ELI_DIR_LOCK_ID = "ELI_DIR_LOCK"

---#DES 'fs.lock_directory'
---
---Locks access to directory
---@param path string
---@param lock_file_name string?
---@return EliDirLock?, string?
function fs.lock_directory(path, lock_file_name)
	if not is_fs_extra_loaded then
		return error_efs_not_available(nil)
	end

	return fs_extra.lock_dir(path, lock_file_name)
end

---#DES 'fs.unlock_directory'
---
---Unlocks access to directory
---@param fs_lock EliDirLock
---@return boolean, string?
function fs.unlock_directory(fs_lock)
	if type(fs_lock) == ELI_DIR_LOCK_ID then
		---@cast fs_lock EliDirLock
		return fs_lock:unlock()
	elseif type(fs_lock) == "userdata" and fs_lock.__type == ELI_DIR_LOCK_ID then
		---@cast fs_lock EliDirLock
		return fs_lock:unlock()
	end

	local err_msg = string.interpolate(
		"invalid ${expected_type} type - '${expected_type}' expected, got: '${type}'",
		{
			expected_type = ELI_DIR_LOCK_ID,
			type = type(fs_lock),
		}
	)
	return false, err_msg
end

---#DES 'fs.file_type'
---
---returns type of file
---@param path string
---@return string?, string?
function fs.file_type(path)
	local last_char = path:sub(-1)
	if last_char == "/" or last_char == "\\" then
		path = path:sub(1, -2)
	end
	return fs_extra.file_type(path)
end

---#DES 'fs.file_type'
---
---returns type of file
---@param path_or_file string|file*
---@return table?, string?
function fs.file_info(path_or_file)
	if type(path_or_file) == "string" then
		local last_char = path_or_file:sub(-1)
		if table_extensions.includes({ "/", "\\" }, last_char) then
			path_or_file = path_or_file:sub(1, -2)
		end
	end
	return fs_extra.file_info(path_or_file)
end

return is_fs_extra_loaded and util.merge_tables(fs, fs_extra) or fs
