local _separator = require "eli.path".default_sep()
local _join = require "eli.extensions.string".join

local function _get_root_dir(paths)
   -- check whether we have all files in same dir
   local _rootDirSegments = {}
   for _, _path in ipairs(paths) do
      if #_rootDirSegments == 0 then
         for _segment in string.gmatch(_path, "(.-)" .. _separator) do
            table.insert(_rootDirSegments, _segment)
         end
      else
         if not string.find(_path, "(.-)" .. _separator) then
            return "" -- found file in root, no usable root dir
         end
         local j = 1
         for _segment in string.gmatch(_path, "(.-)" .. _separator) do
            if _segment ~= _rootDirSegments[j] then
               _rootDirSegments = table.move(_rootDirSegments, 1, j - 1, 1, {})
               break
            end
            j = j + 1
         end
      end

      if #_rootDirSegments == 0 then
         break
      end
   end
   local _rootDir = _join("/", table.unpack(_rootDirSegments))
   if type(_rootDir) == "string" and #_rootDir > 0 and _rootDir:sub(#_rootDir, #_rootDir) ~= _separator then
      _rootDir = _rootDir .. _separator
   end
   return _rootDir or ""
end

return {
   get_root_dir = _get_root_dir
}
