local fs = require"eli.fs"
local ltar = require"ltar"
local path = require"eli.path"
local internal_util = require"eli.internals.util"
local util = require"eli.util"

local function get_root_dir(entries)
	local paths = {}
	for _, entry in ipairs(entries) do
		table.insert(paths, entry:path())
	end
	return internal_util.get_root_dir(paths)
end

---@class TarExtractOptions
---@field skip_destination_check boolean?
---@field flatten_root_dir boolean?
---@field chmod (fun(path: string, attributes: integer))?
---@field mkdirp (fun(path: string))?
---@field transform_path (fun(path: string, destination: string?): string)?
---@field filter (fun(name: string, type: string): boolean)?
---@field open_file (fun(path: string, mode: string): file* | any)?
---@field write (fun(file: file* | any, data: string))?
---@field link (fun(linkTarget: string, path: string, isSymbolicLink: boolean))?
---@field log (fun(err: string))?
---@field close_file (fun(file: file* | any))?
---@field chunk_size number?

local function parse_extended_header(entry, globalExtendedHeader)
	if entry:type() == ltar.GNU_LONGNAME then
		local header = {
			path = entry:read(entry:size()):match"[^%z]+",
		}
		return true, util.merge_tables(header, globalExtendedHeader), globalExtendedHeader
	end
	-- // TODO: GNU_LONGLINK
	if entry:type() == "K" then
		local header = {
			linkpath = entry:read(entry:size()):match"[^%z]+",
		}
		return true, util.merge_tables(header, globalExtendedHeader), globalExtendedHeader
	end
	if entry:type() == ltar.XHDTYPE or entry:type() == ltar.XGLTYPE then
		local data = entry:read(entry:size())
		local fields = {}
		for _, keyword, value in data:gmatch"(%d+)%s(%S+)=(%S*)\n" do
			fields[keyword] = value
		end
		if entry:type() == ltar.XHDTYPE then
			return true, util.merge_tables(fields, globalExtendedHeader), globalExtendedHeader
		end
		return true, fields, fields
	end
	return false, globalExtendedHeader, globalExtendedHeader
end

local tar = util.clone(ltar)

---#DES 'tar.extract'
---
---Extracts data from source into destination folder
---@param source string
---@param destination string?
---@param options TarExtractOptions?
function tar.extract(source, destination, options)
	if type(options) ~= "table" then
		options = {}
	end

	--// TODO: remove in next version
	if options.skipDestinationCheck ~= nil and options.skip_destination_check == nil then
		options.skip_destination_check = options.skipDestinationCheck
		print"Deprecation warning: skipDestinationCheck is deprecated, use skip_destination_check instead"
	end

	if fs.EFS and not options.skip_destination_check then
		assert(type(destination) == "string", "Destination must be a string!")
		assert(fs.file_type(destination) == "directory", "Destination not found or is not a directory: " .. destination)
	end

	--// TODO: remove in next version
	if options.flattenRootDir ~= nil and options.flatten_root_dir == nil then
		options.flatten_root_dir = options.flattenRootDir
		print"Deprecation warning: flattenRootDir is deprecated, use flatten_root_dir instead"
	end

	local flatten_root_dir = options.flatten_root_dir or false
	local external_chmod = type(options.chmod) == "function"
	-- optional functions
	local mkdirp = fs.EFS and fs.mkdirp or function () end
	mkdirp = type(options.mkdirp) == "function" and options.mkdirp or mkdirp
	local chmod = fs.EFS and fs.chmod or function () end
	chmod = type(options.chmod) == "function" and options.chmod or chmod

	local transform_path = type(options.transform_path) == "function" and options.transform_path
	local filter = type(options.filter) == "function" and options.filter or function ()
		return true
	end
	local open_file = type(options.open_file) == "function" and options.open_file or function (path, mode)
		return io.open(path, mode)
	end
	local write = type(options.write) == "function" and options.write or function (file, data)
		return file:write(data)
	end
	local log = type(options.log) == "function" and options.log or function (msg)
		return print(msg)
	end
	local link = type(options.link) == "function" and options.link or function (linkTarget, path, isSymbolicLink)
		return fs.EFS and fs.link(linkTarget, path, isSymbolicLink) or function ()
			log"tar.extract: link not supported on this platform! (EFS not available)"
		end
	end
	local close_file = type(options.close_file) == "function" and options.close_file or function (file)
		return file:close()
	end

	--// TODO: remove in next version
	if options.chunkSize ~= nil and options.chunk_size == nil then
		options.chunk_size = options.chunkSize
		print"Deprecation warning: chunkSize is deprecated, use chunk_size instead"
	end
	local chunk_size = type(options.chunk_size) ~= "number" and options.chunk_size or 2 ^ 13 -- 8K

	local tar_archive <close> = ltar.open(source)
	assert(tar_archive, "tar: Failed to open source file " .. tostring(source) .. "!")

	local ignore_path = flatten_root_dir and get_root_dir(tar_archive) or ""
	local ignore_length = #ignore_path + 1 -- ignore length

	local extended_header = {}
	local global_extended_header = {}

	for _, entry in ipairs(tar_archive:entries()) do
		local is_extended_header
		-- extended_header gets automatically injected global data, global header is just to update it properly if encountered
		is_extended_header, extended_header, global_extended_header = parse_extended_header(entry, global_extended_header)
		if is_extended_header then
			goto CONTINUE
		end

		local entry_path = type(extended_header.path) == "string" and extended_header.path or entry:path()
		if #entry_path:sub(ignore_length) == 0 then
			-- skip empty paths
			goto CONTINUE
		end

		if not filter(entry_path:sub(ignore_length), entry:type()) then
			goto CONTINUE
		end

		local target_path = path.file(entry_path)
		if type(transform_path) == "function" then                         -- if supplied transform with transform functions
			target_path = transform_path(entry_path:sub(ignore_length), destination)
		elseif type(mkdirp) == "function" and type(destination) == "string" then --mkdir supported we can use path as is :)
			target_path = path.combine(destination, entry_path:sub(ignore_length))
		end

		if entry:type() == ltar.DIR then
			-- directory
			mkdirp(target_path)
		elseif entry:type() == ltar.FILE or entry:type() == ltar.AFILE then
			mkdirp(path.dir(target_path))

			--if entry:type() == ltar.FILE
			local f, err = open_file(target_path, "wb")
			assert(f, "Failed to open file: " .. target_path .. " because of: " .. (err or ""))

			while true do
				local chunk = entry:read(chunk_size)
				if chunk == nil then
					break
				end
				write(f, chunk)
			end
			close_file(f)

			local mode = type(extended_header.mode) == "string" and tonumber(extended_header.mode, 8) or entry:mode()
			if external_chmod then               -- we got supplied chmod
				chmod(target_path, mode)
			else                                 -- we use built in chmod
				local valid, permissions = pcall(string.format, "%o", mode)
				if valid and tonumber(permissions) ~= 0 then -- asign only valid permissions
					pcall(chmod, target_path, tonumber(mode))
				end
			end
		elseif entry:type() == ltar.SYMLINK or entry:type() == ltar.HARDLINK then
			local link_target = type(extended_header.linkpath) == "string" and extended_header.linkpath or
			   entry:linkpath()
			if type(mkdirp) == "function" and type(destination) == "string" then --mkdir supported we can use path as is :)
				if not path.isabs(link_target) then
					link_target = path.combine(destination, link_target)
				end
			end
			link(link_target, target_path, entry:type() == ltar.SYMLINK)
			local mode = type(extended_header.mode) == "string" and tonumber(extended_header.mode, 8) or entry:mode()
			if external_chmod then               -- we got supplied chmod
				chmod(target_path, mode)
			else                                 -- we use built in chmod
				local valid, permissions = pcall(string.format, "%o", mode)
				if valid and tonumber(permissions) ~= 0 then -- asign only valid permissions
					pcall(chmod, target_path, tonumber(mode))
				end
			end
		else
			log("TAR: unsupported entry type: " .. entry:type() .. " for path: " .. entry_path)
		end
		extended_header = {}
		::CONTINUE::
	end
end

---#DES 'tar.extract_file'
---
---Extracts single file from source archive into destination
---@param source string
---@param file string
---@param destination string
---@param extract_options TarExtractOptions?
function tar.extract_file(source, file, destination, extract_options)
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
		   } --[[@as TarExtractOptions]],
		   true
	   )
	return tar.extract(source, path.dir(destination), options)
end

---#DES 'tar.extract_string'
---
---Extracts single file from source archive into string
---@param source string
---@param file string
---@param extract_options TarExtractOptions?
---@return string
function tar.extract_string(source, file, extract_options)
	local result = ""
	local options =
	   util.merge_tables(
		   type(extract_options) == "table" and extract_options or {},
		   {
			   open_file = function ()
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
		   } --[[@as TarExtractOptions]],
		   true
	   )

	tar.extract(source, nil, options)
	return result
end

return util.generate_safe_functions(tar)
