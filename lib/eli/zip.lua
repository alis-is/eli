local fs = require "eli.fs"
local zip = require "lzip"
local _path = require "eli.path"
local _util = require "eli.util"
local _internalUtil = require "eli.internals.util"

local function _get_root_dir(zipArch)
   -- check whether we have all files in same dir
   local _paths = {}
   for i = 1, #zipArch do
      local _stat = zipArch:stat(i)
      table.insert(_paths, _stat.name)
   end
   return _internalUtil.get_root_dir(_paths)
end

local function extract(source, destination, options)
   if type(options) ~= "table" then
      options = {}
   end
   if fs.EFS and not options.skipDestinationCheck then
      assert(fs.file_type(destination) == "directory", "Destination not found or is not a directory: " .. destination)
   end

   local flattenRootDir = options.flattenRootDir or false
   local _externalChmod = type(options.chmod) == "function"
   local _openFlags = type(options.openFlags) == "number" and options.openFlags or zip.CHECKCONS
   -- optional functions
   local _mkdirp = fs.EFS and fs.mkdirp or function()
      end
   _mkdirp = type(options.mkdirp) == "function" and options.mkdirp or _mkdirp
   local _chmod = fs.EFS and fs.chmod or function()
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
   local _close_file = type(options.close_file) == "function" and options.close_file or function(file)
         return file:close()
      end

   local zipArch, err = zip.open(source, _openFlags)
   assert(zipArch ~= nil, err)

   local ignorePath = flattenRootDir and _get_root_dir(zipArch) or ""
   local il = #ignorePath + 1 -- ignore length

   for i = 1, #zipArch do
      local stat = zipArch:stat(i)

      if #stat.name:sub(il) == 0 then
         -- skip empty paths
         goto files_loop
      end

      if not _filter(stat.name:sub(il)) then
         goto files_loop
      end

      -- by default we assume that mkdir is nor supported and we cannot create directories
      local _targetPath = _path.filename(stat.name)
      if type(_transform_path) == "function" then -- if supplied transform with transform functions
         _targetPath = _transform_path(stat.name:sub(il), destination)
      elseif type(_mkdirp) == "function" and type(destination) == "string" then --mkdir supported we can use path as is :)
         _targetPath = _path.combine(destination, stat.name:sub(il))
      end

      if stat.name:sub(-(#"/")) == "/" then
         -- directory
         _mkdirp(_targetPath)
      else
         local comprimedFile = zipArch:open(i)
         local dir = _path.dir(_targetPath)
         _mkdirp(dir)

         local b = 0
         local _f, _error = _open_file(_targetPath, "w+b")
         assert(_f, "Failed to open file: " .. _targetPath .. " because of: " .. (_error or ""))
         local chunkSize = 2 ^ 13 -- 8K
         while b < stat.size do
            local bytes = comprimedFile:read(math.min(chunkSize, stat.size - b))
            _write(_f, bytes)
            b = b + math.min(chunkSize, stat.size - b)
         end
         _close_file(_f)

         local _externalAtrributes = zipArch:get_external_attributes(i)
         if _externalChmod then -- we got supplied chmod
            _chmod(_targetPath, _externalAtrributes)
         else -- we use built in chmod
            local _permAttributes = (_externalAtrributes / 2 ^ 16)
            local _valid, _permissions = pcall(string.format, "%o", _permAttributes)
            if _valid and tonumber(_permissions) ~= 0 then
               pcall(_chmod, _targetPath, tonumber(_permissions))
            end
         end
      end
      ::files_loop::
   end
   zipArch:close()
end

local function extract_file(source, file, destination, options)
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

   return extract(source, _path.dir(destination), _options)
end

local function extract_string(source, file, options)
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

   extract(source, nil, _options)
   return _result
end

local function get_files(source, options)
   if type(options) ~= "table" then
      options = {}
   end
   local flattenRootDir = options.flattenRootDir or false
   local _transform_path = options.transform_path or nil
   local _openFlags = type(options.openFlags) == "number" and options.openFlags or zip.CHECKCONS

   local zipArch, err = zip.open(source, _openFlags)
   assert(zipArch ~= nil, err)

   local ignorePath = flattenRootDir and _get_root_dir(zipArch) or ""
   local il = #ignorePath + 1 -- ignore length

   local files = {}
   for i = 1, #zipArch do
      local stat = zipArch:stat(i)

      if #stat.name:sub(il) == 0 then
         -- skip empty paths
         goto files_loop
      end
      local targetPath = stat.name:sub(il)
      if type(_transform_path) == "function" then -- if supplied transform with transform functions
         targetPath = _transform_path(stat.name:sub(il))
      end
      table.insert(files, targetPath)
      ::files_loop::
   end
   zipArch:close()
   return files
end

-- content is either file path or string
local function _add_to_archive(archive, path, type, content)
   if type == "directory" then
      archive:add_dir(path)
   elseif type == "file" then
      archive:add(path, "file", content)
   elseif type == "string" then
      archive:add(path, "string", content)
   else
      error("Unsupported data type for compression...")
   end
end

local function _open_archive(path, checkcons)
   local _result, _error
   if checkcons then
      _result, _error = zip.open(path, zip.CHECKCONS)
   else
      _result, _error = zip.open(path)
   end
   assert(_result, _error)
end

local function _new_archive(path)
   local _result, _error = zip.open(path, zip.OR(zip.CREATE, zip.EXCL))
   assert(_result, _error)
   return _result
end

local function _compress(source, target, options)
   if type(options) ~= "table" then
      options = {}
   end

   if fs.file_type(source) == nil then
      error("Cannot compress. Invalid source " .. (source or ""))
   end

   if options.overwrite then
      local _targetType = fs.file_type(target)
      if _targetType == "file" then
         fs.remove(target)
      elseif _targetType ~= nil then -- exists but not file
         error("Can not overwrite! Target is not a file. (" .. (_targetType or "unknown type") .. ")")
      end
   end

   local _skipLength = 1 -- dont skip anything
   if not options.preserveFullPath then
      local _targetName = _path.file(source)
      _skipLength = #source - #_targetName + 1
   end

   local _archive = _new_archive(target)
   if fs.file_type(source) == "file" then
      _add_to_archive(_archive, source:sub(_skipLength), "file", source)
      _archive:close()
      return
   end

   local _dirEntries = fs.read_dir(source, {recurse = options.recurse, asDirEntries = true})
   for _, entry in ipairs(_dirEntries) do
      _add_to_archive(_archive, entry:fullpath():sub(_skipLength), entry:type(), entry:fullpath())
   end
   _archive:close()
end

return _util.generate_safe_functions(
   {
      extract = extract,
      extract_file = extract_file,
      extract_string = extract_string,
      get_files = get_files,
      compress = _compress,
      add_to_archive = _add_to_archive,
      new_archive = _new_archive,
      open_archive = _open_archive
   }
)
