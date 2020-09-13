local io = require "io"
local _eliPath = require "eli.path"
local dir = _eliPath.dir
local combine = _eliPath.combine
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables
local efsLoaded, efs = pcall(require, "eli.fs.extra")
local hash = require "lmbed_hash"

local function _check_efs_available(operation)
   if not efsLoaded then
      if operation ~= nil and operation ~= "" then
         error("Extra fs api not available! Operation " .. operation .. " failed!")
      else
         error("Extra fs api not available!")
      end
   end
end

local function read_file(src)
   local f = assert(io.open(src, "r"), "No such a file or directory - " .. src)
   local result = f:read("a*")
   f:close()
   return result
end

local function write_file(dst, content)
   local f = assert(io.open(dst, "w"), "No such a file or directory - " .. dst)
   f:write(content)
   f:close()
end

local function copy_file(src, dst)
   assert(src ~= dst, "Identical source and destiontion path!")
   local srcf = assert(io.open(src, "r"), "No such a file or directory - " .. src)
   local dstf = assert(io.open(dst, "w"), "Failed to open file for write - " .. dst)

   local size = 2 ^ 12 -- 4K
   while true do
      local block = srcf:read(size)
      if not block then
         break
      end
      dstf:write(block)
   end
   srcf:close()
   dstf:close()
end

local function mkdirp(dst)
   _check_efs_available("mkdirp")
   local parent = dir(dst)
   if parent ~= nil then
      mkdirp(parent)
   end
   efs.mkdir(dst)
end

local function _remove(dst, options)
   if not efsLoaded then
      -- fallback to os delete
      local _ok, _error = os.remove(dst)
      assert(_ok, _error or "")
   end

   if type(options) ~= "table" then 
      options = {}
   end

   local recurse = options.recurse
   local contentOnly = options.contentOnly
   options.contentOnly = false -- for recursive calls

   if efs.file_type(dst) == nil then
      return
   end
   if efs.file_type(dst) == "file" then
      local _ok, _error = os.remove(dst)
      assert(_ok, _error or "")
   end
   if recurse then
      for o in efs.iter_dir(dst) do
         local fullPath = combine(dst, o)
         if o ~= "." and o ~= ".." then
            if efs.file_type(fullPath) == "file" then
               local _ok, _error = os.remove(fullPath)
               assert(_ok, _error or "")
            elseif efs.file_type(fullPath) == "directory" then
               _remove(fullPath, options)
            end
         end
      end
   end
   if not contentOnly then 
      efs.rmdir(dst)
   end
end

local function move(src, dst)
   return require "os".rename(src, dst)
end

local function exists(path)
   _check_efs_available("exists")
   if efs.file_type(path) then
      return true
   else
      return false
   end
end

local function mkdir(...)
   _check_efs_available("mkdir")
   efs.mkdir(...)
end

local function hash_file(src, options)
   if type(options) ~= "table" then
      options = {}
   end
   if options.type ~= "sha512" then
      options.type = "sha256"
   end
   local srcf = assert(io.open(src, "r"), "No such a file or directory - " .. src)
   local size = 2 ^ 12 -- 4K

   if options.type == "sha256" then
      local ctx = hash.sha256_init()
      while true do
         local block = srcf:read(size)
         if not block then
            break
         end
         hash.sha256_update(ctx, block)
      end
      return hash.sha256_finish(ctx, options.hex)
   else
      local ctx = hash.sha512_init()
      while true do
         local block = srcf:read(size)
         if not block then
            break
         end
         hash.sha512_update(ctx, block)
      end
      return hash.sha512_finish(ctx, options.hex)
   end
end

local function _direntry_type(entry)
   if type(entry) == "string" then
      return efs.file_type(entry)
   elseif type(entry) == "userdata" and entry.__type == "ELI_DIRENTRY" then
      return entry:type()
   end
   return nil
end

local function _read_dir_recurse(path, asDirEntries, lenOfPathToRemove)
   if type(_lenOfPathToRemove) ~= 'number' then 
      _lenOfPathToRemove = 0
   end 
   local _entries = efs.read_dir(path, asDirEntries)
   local result = {}
   for _, entry in ipairs(_entries) do
      local _path = asDirEntries and entry:fullpath() or combine(path, entry)
      if _direntry_type(asDirEntries and entry or _path) == "directory" then
         local _subEntries = _read_dir_recurse(_path, asDirEntries, lenOfPathToRemove)
         for _, subEntry in ipairs(_subEntries) do
            table.insert(result, subEntry)
         end
      end
      table.insert(result, asDirEntries and entry or _path:sub(lenOfPathToRemove + 1))
   end
   return result
end

local function _read_dir(path, options)
   if type(options) ~= "table" then
      options = {}
   end
   if options.recurse then
      local _lenOfPathToRemove = path:match(".*/") and #path or #path + 1
      if options.returnFullPaths then 
         _lenOfPathToRemove = 0
      end
      return _read_dir_recurse(path, options.asDirEntries, _lenOfPathToRemove)
   end
   local _result = efs.read_dir(path, options.asDirEntries)
   if not options.asDirEntries and options.returnFullPaths then 
      for i, v in ipairs(_result) do 
         _result[i] = combine(path, v)
      end
   end
   return _result
end

local function _chown(path, uid, gid, options)
   if type(options) ~= "table" then
      options = {}
   end

   if not options.recurse or efs.file_type(path) ~= "directory" then
      return efs.chown(path, uid, gid)
   end

   efs.chown(path, uid, gid)

   _paths = _read_dir(path, {recurse = true, returnFullPaths = true})
   for _, _path in ipairs(_paths) do
      efs.chown(_path, uid, gid)
   end
end

local fs = {
   write_file = write_file,
   read_file = read_file,
   copy_file = copy_file,
   mkdir = mkdir,
   mkdirp = mkdirp,
   remove = _remove,
   exists = exists,
   move = move,
   EFS = efsLoaded,
   hash_file = hash_file,
   read_dir = _read_dir,
   chown = _chown
}

if efsLoaded then
   local result = generate_safe_functions(merge_tables(fs, efs))
   result.safe_iter_dir = nil -- not supported
   return result
else
   return generate_safe_functions(fs)
end
