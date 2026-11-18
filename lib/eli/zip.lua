local fs = require"eli.fs"
local lzip = require"lzip"
local path = require"eli.path"
local util = require"eli.util"
local internals_util = require"eli.internals.util"

local function get_root_dir(zipArch)
	-- check whether we have all files in same dir
	local paths = {}
	for i = 1, #zipArch do
		local stat = zipArch:stat(i)
		if type(stat.name) == "string" and not stat.name:match"/$" then
			table.insert(paths, stat.name)
		end
	end
	return internals_util.get_root_dir(paths)
end

local zip = {}

---@alias transform_path_fn fun(path: string, destination?: string): string

---@class ZipExtractOptions
---@field skip_destination_check boolean?
---@field flatten_root_dir boolean?
---@field chmod (fun(path: string, attributes: integer): boolean?, string?)? Receives raw ZIP external attributes.
---@field open_flags integer?
---@field mkdirp (fun(path: string))?
---@field transform_path transform_path_fn?
---@field open_file (fun(path: string, mode: string): file* | any)?
---@field write (fun(file: file* | any, data: string))?
---@field close_file (fun(file: file* | any))?
---@field filter (fun(name: string, fileInfo: table): boolean)?

---#DES 'zip.extract'
---
---Extracts data from source into destination folder
---@param source string
---@param destination string?
---@param options ZipExtractOptions?
---@return boolean, string?
function zip.extract(source, destination, options)
	if type(options) ~= "table" then
		options = {}
	end

	if fs.EFS and not options.skip_destination_check then
		if not destination or fs.file_type(destination) ~= "directory" then
			return false, "zip.extract: skip_destination_check is required when using EFS - " .. tostring(destination)
		end
	end

	if options.open_flags ~= nil and options.open_flags == nil then
		options.open_flags = options.open_flags
		print"Deprecation warning: openFLags is deprecated, use skip_destination_check instead"
	end

	local flatten_root_dir = options.flatten_root_dir or false
	local external_chmod = type(options.chmod) == "function"
	local open_flags = type(options.open_flags) == "number" and options.open_flags or lzip.CHECKCONS
	-- optional functions

	---@type fun(path: string)
	local mkdirp = fs.EFS and fs.mkdirp or function () end
	mkdirp = type(options.mkdirp) == "function" and options.mkdirp or mkdirp

	---@type fun(path: string, attributes: integer): boolean?, string?
	local chmod = fs.EFS and fs.chmod or function () end
	chmod = type(options.chmod) == "function" and options.chmod or chmod

	local function restore_mode(target, mode)
		local ok, result, err = pcall(chmod, target, mode)
		-- Custom chmod callbacks may return nothing on success.
		if not ok or result == false or (result == nil and err ~= nil) then
			return false, ("zip.extract: chmod failed for %s: %s"):format(target, tostring(err or result))
		end
		return true
	end

	---@type transform_path_fn?
	local transform_path = type(options.transform_path) == "function" and options.transform_path or nil

	---@type fun(name: string, fileInfo: table): boolean
	local filter = type(options.filter) == "function" and options.filter or function ()
		return true
	end

	---@type fun(path: string, mode: string): file*
	local open_file = type(options.open_file) == "function" and options.open_file or function (path, mode)
		return io.open(path, mode)
	end
	---@type fun(file: file* | any , data: string)
	local write = type(options.write) == "function" and options.write or function (file, data)
		return file:write(data)
	end
	---@type fun(f: file*)
	local close_file = type(options.close_file) == "function" and options.close_file or function (file)
		return file:close()
	end

	local zip_arch, err = lzip.open(source, open_flags)
	if not zip_arch then
		return false, err
	end

	local ignore_path = flatten_root_dir and get_root_dir(zip_arch) or ""
	local il = #ignore_path + 1 -- ignore length
	local directory_modes = {}

	for i = 1, #zip_arch do
		local stat = zip_arch:stat(i)

		if #stat.name:sub(il) == 0 then
			-- skip empty paths
			goto continue
		end

		if not filter(stat.name:sub(il), stat) then
			goto continue
		end

		-- by default we assume that mkdir is nor supported and we cannot create directories
		local target_path = path.file(stat.name)
		if type(transform_path) == "function" then                         -- if supplied transform with transform functions
			target_path = transform_path(stat.name:sub(il), destination)
		elseif type(mkdirp) == "function" and type(destination) == "string" then --mkdir supported we can use path as is :)
			target_path = path.combine(destination, stat.name:sub(il))
		end

		local is_directory = stat.name:sub(-1) == "/"
		if is_directory then
			mkdirp(target_path)
		else
			local comprimedFile = zip_arch:open(i)
			local dir = path.dir(target_path)
			mkdirp(dir)

			local b = 0
			local file, err = open_file(target_path, "wb")
			if not file then
				zip_arch:close()
				return false, "zip.extract: failed to open file: " .. target_path .. " because of: " .. (err or "")
			end
			local chunkSize = 2 ^ 13 -- 8K
			while b < stat.size do
				local bytes = comprimedFile:read(math.min(chunkSize, stat.size - b))
				write(file, bytes)
				b = b + math.min(chunkSize, stat.size - b)
			end
			close_file(file)
		end
		local mode, err
		if external_chmod then
			mode, err = zip_arch:get_external_attributes(i)
		else
			mode, err = zip_arch:get_unix_mode(i)
		end
		if err then
			zip_arch:close()
			return false, ("zip.extract: could not read attributes for %s: %s"):format(stat.name, err)
		end
		if mode ~= nil then
			if is_directory then
				table.insert(directory_modes, {
					path = target_path, mode = mode, depth = path.depth(path.normalize(target_path)), index = i,
				})
			else
				local ok, err = restore_mode(target_path, mode)
				if not ok then
					zip_arch:close()
					return false, err
				end
			end
		end
		::continue::
	end
	zip_arch:close()

	-- A restrictive parent must stay traversable until its children have their final modes.
	table.sort(directory_modes, function (a, b)
		if a.depth == b.depth then return a.index < b.index end
		return a.depth > b.depth
	end)
	for _, dir in ipairs(directory_modes) do
		local ok, err = restore_mode(dir.path, dir.mode)
		if not ok then return false, err end
	end
	return true
end

---#DES 'zip.extract_file'
---
---Extracts single file from source archive into destination
---@param source string
---@param file string
---@param destination string
---@param extract_options ZipExtractOptions?
---@return boolean, string?
function zip.extract_file(source, file, destination, extract_options)
	if type(destination) == "table" and extract_options == nil then
		extract_options = destination
		destination = file
	end

	local options =
	   util.merge_tables(
		   type(extract_options) == "table" and extract_options or {},
		   {
			   transform_path = function (path)
				   return path == file and destination or path
			   end,
			   filter = function (path)
				   return path == file
			   end,
		   },
		   true
	   )

	return zip.extract(source, path.dir(destination), options)
end

---#DES 'zip.extract_string'
---
---Extracts single file from source archive into string
---@param source string
---@param file string
---@param extract_options ZipExtractOptions?
---@return string?, string?
function zip.extract_string(source, file, extract_options)
	local result = ""
	local found = false
	local options =
	   util.merge_tables(
		   type(extract_options) == "table" and extract_options or {},
		   {
			   open_file = function ()
				   found = true
				   return result
			   end,
			   write = function (_, data)
				   result = result .. data
			   end,
			   close_file = function ()
			   end,
			   skip_destination_check = true, -- no destination dir
			   filter = function (path)
				   return path == file
			   end,
			   mkdirp = function ()
			   end, -- we do not want to create
			   chmod = function ()
			   end,
		   } --[[@as ZipExtractOptions]],
		   true
	   )

	local ok, err = zip.extract(source, nil, options)
	if not ok then
		return nil, err or "zip: failed to extract string from compressed archive"
	end
	if not found then
		return nil, "zip: file not found in archive: " .. file
	end
	return result
end

---@class GetFilesOptions
---@field flatten_root_dir nil|boolean
---@field chmod nil|fun(path: string, attributes: integer)
---@field transform_path nil|fun(path: string): string
---@field open_flags nil|integer

---#DES 'zip.get_files'
---
---Extracts single file from source archive into string
---@param source string
---@param options GetFilesOptions?
---@return string[]?, string?
function zip.get_files(source, options)
	if type(options) ~= "table" then
		options = {}
	end

	local flatten_root_dir = options.flatten_root_dir or false
	local transform_path = options.transform_path or nil
	local open_flags = type(options.open_flags) == "number" and options.open_flags or lzip.CHECKCONS

	local zip_arch, err = lzip.open(source, open_flags)
	if not zip_arch then
		return nil, "zip.get_files: failed to open archive " .. source .. " because of: " .. (err or "")
	end

	local ignore_path = flatten_root_dir and get_root_dir(zip_arch) or ""
	local il = #ignore_path + 1 -- ignore length

	local files = {}
	for i = 1, #zip_arch do
		local stat = zip_arch:stat(i)

		if #stat.name:sub(il) == 0 then
			-- skip empty paths
			goto files_loop
		end
		local targetPath = stat.name:sub(il)
		if type(transform_path) == "function" then -- if supplied transform with transform functions
			targetPath = transform_path(stat.name:sub(il))
		end
		table.insert(files, targetPath)
		::files_loop::
	end
	zip_arch:close()
	return files
end

-- content is either file path or string
---#DES 'zip.add_to_archive'
---
---Opens zip archive and returns it
---@param archive userdata
---@param path string
---@param type '"file"' | '"string"' | '"directory"'
---@param content string? Source path for a filesystem entry, or data for a string entry.
---@return boolean, string?
function zip.add_to_archive(archive, path, type, content)
	if type == "directory" then
		-- // TODO: typing for archive
		---@diagnostic disable-next-line: undefined-field
		archive:add_dir(path, content)
	elseif type == "file" then
		---@diagnostic disable-next-line: undefined-field
		archive:add(path, "file", content)
	elseif type == "string" then
		---@diagnostic disable-next-line: undefined-field
		archive:add(path, "string", content)
	else
		return false, "zip.add_to_archive: unsupported data type for compression - " .. type
	end
	return true
end

-- // TODO: add zip archive class

---#DES 'zip.open_archive'
---
---Opens zip archive and returns it
---@param path string
---@param checkcons boolean?
---@return userdata?, string?
function zip.open_archive(path, checkcons)
	if checkcons then
		return lzip.open(path, lzip.CHECKCONS)
	end
	return lzip.open(path)
end

---#DES 'zip.new_archive'
---
---Creates zip archive file and returns it
---@param path string
---@return userdata?, string?
function zip.new_archive(path)
	return lzip.open(path, lzip.OR(lzip.CREATE, lzip.EXCL))
end

---@class CompressOptions
---@field overwrite nil|boolean
---@field preserve_full_path nil|boolean
---@field recurse nil|boolean
---@field content_only boolean? aplicable only when source is directory
---@field filter (fun(name: string, fileInfo: table): boolean)?

---#DES 'zip.compress'
---
---Compresses directory into zip archive
---@param source string
---@param target string
---@param options CompressOptions?
---@return boolean, string?
function zip.compress(source, target, options)
	if type(options) ~= "table" then
		options = {}
	end

	if fs.file_type(source) == "nil" then
		return false, "zip.compress: source does not exist: " .. (source or "")
	end

	local filter = type(options.filter) == "function" and options.filter or function ()
		return true
	end

	if options.overwrite then
		local target_type = fs.file_type(target)
		if target_type == "file" then
			local ok, err = fs.remove(target)
			if not ok then
				return false, "zip.compress: failed to overwrite target file: " .. (err or "")
			end
		elseif target_type ~= nil then
			return false,
			   "zip.compress: can not overwrite target - target is not a file. (" ..
			   (target_type or "unknown type") .. ")"
		end
	end

	local skip_length = 1 -- dont skip anything

	if not options.preserve_full_path then
		local target_name = path.file(source)
		skip_length = #source - #target_name + 1
	end

	if options.content_only and fs.file_type(source) == "directory" and not options.preserve_full_path then
		skip_length = #source + (source:sub(-1) == "/" and 1 or 2)
	end

	local archive = zip.new_archive(target)
	if fs.file_type(source) == "file" then
		local ok, err = zip.add_to_archive(archive, source:sub(skip_length), "file", source)
		---@diagnostic disable-next-line: undefined-field
		archive:close()
		return ok, err
	end

	local dir_entries = fs.read_dir(source, { recurse = options.recurse, as_dir_entries = true }) --[=[@as DirEntry[]]=]
	for _, entry in ipairs(dir_entries) do
		local entry_path = entry:fullpath():sub(skip_length)
		if not filter(entry_path, entry) then
			goto files_loop
		end

		local ok, err = zip.add_to_archive(archive, entry_path, entry:type(), entry:fullpath())
		if not ok then return false, err end
		::files_loop::
	end
	-- Store the mode of the named source directory as well as its children.
	local root_name = path.endsep(source:sub(skip_length), nil, false)
	local base_name = path.file(root_name)
	if base_name ~= "" and base_name ~= "." and base_name ~= ".."
	   and (#archive > 0 or not options.filter) then
		zip.add_to_archive(archive, root_name, "directory", source)
	end
	---@diagnostic disable-next-line: undefined-field
	archive:close()
	return true
end

return zip
