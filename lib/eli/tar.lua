local _fs = require "eli.fs"
local _tar = require "ltar"
local _path = require "eli.path"
local _tableExt = require "eli.extensions.table"
local _internalUtil = require "eli.internals.util"

local function _get_root_dir(entries)
   return _internalUtil.get_root_dir(
      _tableExt.map(
         entries,
         function(entry)
            return entry:path()
         end
      )
   )
end

local function _extract(source, destination, options)
   if _fs.EFS then
      assert(_fs.file_type(destination) == "directory", "Destination not found or is not a directory: " .. destination)
   end

   local _mkdirp = _fs.EFS and _fs.mkdirp or function()
      end
   local _chmod = _fs.EFS and _fs.chmod or function()
      end

   if type(options) ~= "table" then
      options = {}
   end
   local _flattenRootDir = options.flattenRootDir or false
   local _transform_path = options.transform_path or nil
   local _externalChmod = type(options.chmod) == "function"
   _chmod = type(options.chmod) == "function" and options.chmod or _chmod
   _mkdirp = type(options.mkdirp) == "function" and options.mkdirp or _mkdirp
   local _filter = type(options.filter) == "function" and options.filter or function()
      return true
   end
   local _chunkSize = options.chunkSize or 2 ^ 13 -- 8K

   local _tarEntries = _tar.open(source)
   assert(_tarEntries, "lz: Failed to open source file " .. tostring(source) .. "!")

   local _ignorePath = _flattenRootDir and _get_root_dir(_tarEntries) or ""
   local _il = #_ignorePath + 1 -- ignore length

   for _, _entry in ipairs(_tarEntries) do
      local _entryPath = _entry:path()
      if #_entryPath:sub(_il) == 0 then
         -- skip empty paths
         goto files_loop
      end

      if not _filter(_entryPath:sub(_il)) then
         goto files_loop
      end

      local _targetPath = _path.filename(_entryPath)
      if type(_transform_path) == "function" then -- if supplied transform with transform functions
         _targetPath = _transform_path(_entryPath:sub(_il), destination)
      elseif type(_mkdirp) == "function" then --mkdir supported we can use path as is :)
         _targetPath = _path.combine(destination, _entryPath:sub(_il))
      end

      if _entryPath:sub(-(#"/")) == "/" then
         -- directory
         _mkdirp(_targetPath)
      else
         _mkdirp(_path.dir(_targetPath))

         local _f, _error = io.open(_targetPath, "w+b")
         assert(_f, "Failed to open file: " .. _targetPath .. " because of: " .. (_error or ""))

         while true do
            local _chunk = _entry:read(_chunkSize)
            if _chunk == nil then
               break
            end
            _f:write(_chunk)
         end
         _f:close()

         local _mode = _entry:mode()
         if _externalChmod then -- we got supplied chmod
            _chmod(_targetPath, _mode)
         else -- we use built in chmod
            local _valid, _permissions = pcall(string.format, "%o", _mode)
            if _valid and tonumber(_permissions) ~= 0 then
               pcall(_chmod, _targetPath, tonumber(_permissions))
            end
         end
      end

      ::files_loop::
   end

   _tarEntries.archive:close()
end

local function _extract_file(source, file, destination, options)
   if type(destination) == "table" and options == nil then
      options = destination
      destination = _path.dir(file)
   end
   if type(options) ~= "table" then
      options = {}
   end
   local _options = options
   _options.filter = function(path)
      return path == file
   end

   return _extract(source, destination, options)
end

return {
   extract = _extract,
   extract_file = _extract_file
}
