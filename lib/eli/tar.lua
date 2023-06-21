local _fs = require "eli.fs"
local _tar = require "ltar"
local _path = require "eli.path"
local _internalUtil = require "eli.internals.util"
local _util = require "eli.util"

local function _get_root_dir(entries)
   local _paths = {}
   for _, _entry in ipairs(entries) do
      table.insert(_paths, _entry:path())
   end
   return _internalUtil.get_root_dir(_paths)
end

local tar = _tar

---@class TarExtractOptions
---#DES 'TarExtractOptions.skipDestinationCheck'
---@field skipDestinationCheck nil|boolean
---#DES 'TarExtractOptions.flattenRootDir'
---@field flattenRootDir nil|boolean
---#DES 'TarExtractOptions.chmod'
---@field chmod nil|fun(path: string, attributes: integer)
---#DES 'TarExtractOptions.mkdirp'
---@field mkdirp nil|fun(path: string)
---#DES 'TarExtractOptions.transform_path'
---@field transform_path (fun(path: string, destination: string?): string)?
---#DES 'TarExtractOptions.filter'
---@field filter nil|fun(name: string, type: string): boolean
---#DES 'TarExtractOptions.open_file'
---@field open_file nil|fun(path: string, mode: string): file*
---#DES 'TarExtractOptions.write'
---@field write nil|fun(path: string, data: string)
---#DES 'TarExtractOptions.link'
---@field link nil|fun(linkTarget: string, path: string, isSymbolicLink: boolean)
---#DES 'TarExtractOptions.log'
---@field log nil|fun(err: string)
---#DES 'TarExtractOptions.close_file'
---@field close_file nil|fun(f: file*)
---#DES 'TarExtractOptions.close_file'
---@field chunkSize nil|number



local function _parse_extended_header(entry, globalExtendedHeader)
	if entry:type() == tar.GNU_LONGNAME then
		local _header = {
			path = entry:read(entry:size()):match("[^%z]+") 
		}
		return true, util.merge_tables(_header, globalExtendedHeader), globalExtendedHeader
	end
	-- // TODO: GNU_LONGLINK
	if entry:type() == "K" then
		local _header = {
			linkpath = entry:read(entry:size()):match("[^%z]+") 
		}
		return true, util.merge_tables(_header, globalExtendedHeader), globalExtendedHeader
	end
	if entry:type() == tar.XHDTYPE or entry:type() == tar.XGLTYPE then
		local data = entry:read(entry:size())
		local fields = {}
		for _, keyword, value in data:gmatch("(%d+)%s(%S+)=(%S*)\n") do
			fields[keyword] = value
		end
		if entry:type() == tar.XHDTYPE then
			return true, util.merge_tables(fields, globalExtendedHeader), globalExtendedHeader
		end
		return true, fields, fields
	end
	return false, globalExtendedHeader, globalExtendedHeader
end

---#DES 'tar.extract'
---
---Extracts data from source into destination folder
---@param source string
---@param destination string
---@param options TarExtractOptions?
function tar.extract(source, destination, options)
   if type(options) ~= "table" then
      options = {}
   end

   if _fs.EFS and not options.skipDestinationCheck then
      assert(_fs.file_type(destination) == "directory", "Destination not found or is not a directory: " .. destination)
   end

   local _flattenRootDir = options.flattenRootDir or false
   local _externalChmod = type(options.chmod) == "function"
   -- optional functions
   local _mkdirp = _fs.EFS and _fs.mkdirp or function()
      end
   _mkdirp = type(options.mkdirp) == "function" and options.mkdirp or _mkdirp
   local _chmod = _fs.EFS and _fs.chmod or function()
      end
   _chmod = type(options.chmod) == "function" and options.chmod or _chmod

   local _transform_path = type(options.transform_path) == "function" and options.transform_path
   local _filter = type(options.filter) == "function" and options.filter or function()
         return true
      end
   local _open_file = type(options.open_file) == "function" and options.open_file or function(path, mode)
         return io.open(path, mode)
      end
   local _write = type(options.write) == "function" and options.write or function(file, data)
         return file:write(data)
      end
	local _log = type(options.log) == "function" and options.log or function(msg)
         return print(msg)
      end
	local _link = type(options.link) == "function" and options.link or function(linkTarget, path, isSymbolicLink)
			return _fs.EFS and _fs.link(linkTarget, path, isSymbolicLink) or function ()
				_log("tar.extract: link not supported on this platform! (EFS not available)")
			end
      end
   local _close_file = type(options.close_file) == "function" and options.close_file or function(file)
         return file:close()
      end
   local _chunkSize = type(options.chunkSize) ~= "number" and options.chunkSize or 2 ^ 13 -- 8K

   local _tarArchive <close> = _tar.open(source)
   assert(_tarArchive, "tar: Failed to open source file " .. tostring(source) .. "!")

   local _ignorePath = _flattenRootDir and _get_root_dir(_tarArchive) or ""
   local _il = #_ignorePath + 1 -- ignore length

	local _extendedHeader = {}
	local _globalExtendedHeader = {}

   for _, _entry in ipairs(_tarArchive:entries()) do
		local _isExtendedHeader
		-- _extendedHeader gets automatically injected global data, global header is just to update it properly if encountered
		_isExtendedHeader, _extendedHeader, _globalExtendedHeader = _parse_extended_header(_entry, _globalExtendedHeader)
		if _isExtendedHeader then
			goto CONTINUE
		end

		local _entryPath = type(_extendedHeader.path) == "string" and _extendedHeader.path or _entry:path()
      if #_entryPath:sub(_il) == 0 then
         -- skip empty paths
         goto CONTINUE
      end

      if not _filter(_entryPath:sub(_il), _entry:type()) then
         goto CONTINUE
      end

      local _targetPath = _path.file(_entryPath)
      if type(_transform_path) == "function" then -- if supplied transform with transform functions
         _targetPath = _transform_path(_entryPath:sub(_il), destination)
      elseif type(_mkdirp) == "function" and type(destination) == "string" then --mkdir supported we can use path as is :)
         _targetPath = _path.combine(destination, _entryPath:sub(_il))
      end

      if _entry:type() == tar.DIR then
         -- directory
         _mkdirp(_targetPath)
		elseif _entry:type() == tar.FILE or _entry:type() == tar.AFILE then
         _mkdirp(_path.dir(_targetPath))

			--if entry:type() == tar.FILE 
         local _f, _error = _open_file(_targetPath, "wb")
         assert(_f, "Failed to open file: " .. _targetPath .. " because of: " .. (_error or ""))

         while true do
            local _chunk = _entry:read(_chunkSize)
            if _chunk == nil then
               break
            end
            _write(_f, _chunk)
         end
         _close_file(_f)

         local _mode = type(_extendedHeader.mode) == "string" and tonumber(_extendedHeader.mode, 8) or _entry:mode()
         if _externalChmod then -- we got supplied chmod
            _chmod(_targetPath, _mode)
         else -- we use built in chmod
            local _valid, _permissions = pcall(string.format, "%o", _mode)
            if _valid and tonumber(_permissions) ~= 0 then -- asign only valid permissions
               pcall(_chmod, _targetPath, tonumber(_mode))
            end
         end
		elseif _entry:type() == tar.SYMLINK or _entry:type() == tar.HARDLINK then
			local _linkTarget = type(_extendedHeader.linkpath) == "string" and _extendedHeader.linkpath or  _entry:linkpath()
			if type(_mkdirp) == "function" and type(destination) == "string" then --mkdir supported we can use path as is :)
				if not _path.isabs(_linkTarget) then
					_linkTarget = _path.combine(destination, _linkTarget)
				end
			end
			_link(_linkTarget, _targetPath, _entry:type() == tar.SYMLINK)
			local _mode = type(_extendedHeader.mode) == "string" and tonumber(_extendedHeader.mode, 8) or _entry:mode()
         if _externalChmod then -- we got supplied chmod
            _chmod(_targetPath, _mode)
         else -- we use built in chmod
            local _valid, _permissions = pcall(string.format, "%o", _mode)
            if _valid and tonumber(_permissions) ~= 0 then -- asign only valid permissions
               pcall(_chmod, _targetPath, tonumber(_mode))
            end
         end
		else
			_log("TAR: unsupported entry type: " .. _entry:type() .. " for path: " .. _entryPath)
      end
		_extendedHeader = {}
      ::CONTINUE::
   end

end

---#DES 'tar.extract_file'
---
---Extracts single file from source archive into destination
---@param source string
---@param file string
---@param destination string
---@param options TarExtractOptions?
function tar.extract_file(source, file, destination, options)
   if type(destination) == "table" and options == nil then
      options = destination
      destination = file
   end
   local _options =
      _util.merge_tables(
      type(options) == "table" and options or {},
      {
         transform_path = function(path)
            return path == file and destination or path
         end,
         filter = function(path)
            return path == file
         end
      },
      true
   )
   return tar.extract(source, _path.dir(destination), _options)
end

---#DES 'tar.extract_string'
---
---Extracts single file from source archive into string
---@param source string
---@param file string
---@param options TarExtractOptions?
---@return string
function tar.extract_string(source, file, options)
   local _result = ""
   local _options =
      _util.merge_tables(
      type(options) == "table" and options or {},
      {
         open_file = function()
            return _result
         end,
         write = function(_, data)
            _result = _result .. data
         end,
         close_file = function()
         end,
         skipDestinationCheck = true, -- no destination dir
         filter = function(path)
            return path == file
         end,
         mkdirp = function()
         end, -- we do not want to create
         chmod = function()
         end
      },
      true
   )

   tar.extract(source, nil, _options)
   return _result
end

return _util.generate_safe_functions(tar)
