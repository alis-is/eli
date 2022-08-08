local lustache = require "lustache"
local hjson = require "hjson"
local config = hjson.parse(fs.read_file("config.hjson"))

local log_success, log_info = util.global_log_factory("create-env", "success", "info")

local generate_embedable_module = require "tools.embedable"
local templates = require "tools.templates"
local _buildUtil = require "tools.util"

log_info("Build env prepartion.")

---rebuilds file based on recipe
---@param source string
---@param replace table<string, string>|fun(string): string
---@param conditionFn (fun(string): boolean)?
---@param target string|nil
local function rebuild_file(source, replace, conditionFn, target)
   if target == nil then target = source end

   local _file = fs.read_file(source)
   if type(conditionFn) == "function" then
      if not conditionFn(_file) then return end
   end
   if type(replace) == "table" then
      for pattern, v in pairs(replace) do
         _file = _file:gsub(pattern, v)
      end
   elseif type(replace) == "function" then
      _file = replace(_file)
   end
   fs.write_file(target, _file)
end

-- inject ELI versions
log_info("Injecting eli version...")
rebuild_file("lib/init.lua", function(file)
   local _start, _ = file:find("ELI_LIB_VERSION")
   if _start then file = file:sub(1, _start - 1) end
   return file .. "\nELI_LIB_VERSION = '" .. config.version .. "'\nELI_VERSION = '" .. config.version .. "'"
end)

-- add libraries
log_info("Building linit.c...")
assert(fs.read_file("lua/src/linit.c"):match("\nLUALIB_API void luaL_openlibs.-\n}"))
rebuild_file("lua/src/linit.c", function(file)
   local _embedableLibs = generate_embedable_module(config.lua_libs, { minify = config.minify, escape = not config.compress, escapeForLuaGsub = not config.compress })
   local _compressedLibs = ""
   if config.compress then
      _compressedLibs = _buildUtil.compress_string_to_c_bytes(_embedableLibs)
   end
   local _renderedLibs = lustache:render(templates.libsListTemplate,
      { keys = table.keys(config.c_libs), pairs = table.to_array(config.c_libs), embedableLibs = config.compress and _compressedLibs or _embedableLibs, compress = config.compress })
   local _newLinit = file:gsub("/%* eli additional libs %*/.-/%* end eli additional libs %*/\n", "")
       -- cleanup potential old init
       :gsub("\nLUALIB_API void luaL_openlibs", _renderedLibs) -- inject libs
   local _start, _end = _newLinit:find("\nLUALIB_API void luaL_openlibs.*$")
   return _newLinit:sub(1, _start - 1) ..
       _newLinit:sub(_start, _end):gsub("\n}",
          '\n' .. lustache:render(templates.loadLibsTemplate, { embedableLibsLength = #_embedableLibs, compress = config.compress  }))
end)

-- build new lua.c
log_info("Building lua.c...")
assert(fs.read_file("lua/src/lua.c"):match("createargtable%(L,.-\n"))
rebuild_file("lua/src/lua.c", function(file)
   local _newFile = file:gsub("/%* eli init %*/.-/%* end eli init %*/\n", "") -- cleanup old init
   local _, _end = _newFile:find("createargtable%(L,.-\n")

   local _embedableInit = generate_embedable_module({ { files = config.init } },
      { amalgate = false, minify = config.minify })
   local _renderedInit = lustache:render(templates.eliInitTemplate, { embedableInit = _embedableInit })
   return _newFile:sub(1, _end) .. _renderedInit .. _newFile:sub(_end + 1)
end)

-- add copyright
log_info("Injecting copyright...")
local _copyrightPattern = '#define LUA_COPYRIGHT[\t ]-LUA_RELEASE "  Copyright %(C%).-"'
rebuild_file("lua/src/lua.h", function(file)
   local _copyright = file:match(_copyrightPattern)
   local _newCopyright = _copyright:sub(1, _copyright:len() - 1) ..
       '\\nEli ' .. config.version .. '  Copyright (C) 2019-2022 alis-is"'
   local _start, _end = file:find(_copyright, 1, true)
   return file:sub(1, _start - 1) .. _newCopyright .. file:sub(_end + 1, file:len())
end, function(file)
   local _copyright = file:match(_copyrightPattern)
   return not _copyright:match("Eli.-alis%-is")
end)

if not config.global_modules then
   log_info("Disabling loading global modules...")
   -- disable loading system wide modules
   rebuild_file("lua/src/luaconf.h", {
      ['\n\t\tLUA_LDIR"%?%.lua;"  LUA_LDIR"%?/init%.lua;" \\'] = "",
      ['\n\t\tLUA_CDIR"%?%.lua;"  LUA_CDIR"%?/init%.lua;" \\'] = "",
      ['LUA_CDIR"%?%.so;" LUA_CDIR"loadall%.so;"'] = "",
      ['\n\t\tLUA_SHRDIR"%?%.lua;" LUA_SHRDIR"%?\\\\init%.lua;" \\'] = ""
   })
end

-- fix lzip
log_info("Renaming luaopen_brimworks_zip to luaopen_lzip in lua_zip.c...")
rebuild_file("modules/lzip/lua_zip.c", {
   ["LUALIB_API int luaopen_brimworks_zip"] = "LUALIB_API int luaopen_lzip"
})

-- fix libzip CMake
log_info("Fixing libzip CMakeLists...")
local _zlibPath = path.combine(os.cwd(), "build/modules/zlib/")
rebuild_file("modules/libzip/CMakeLists.txt", {
   ["SET%(ZLIB_INCLUDE_DIR .-\n"]  = "",
   ["SET%(ZLIB_LIBRARY .-\n"]      = "",
   ["option%(ZLIBINCLUDEDIR .-\n"] = "",
   ["option%(ZLIBLIBPATH .-\n"]    = "",
   ["CMAKE_MINIMUM_REQUIRED.-\n"]  = [[CMAKE_MINIMUM_REQUIRED(VERSION 3.0.2)
option(ZLIBLIBPATH "path to zlib" ]] .. _zlibPath .. [[)
option(ZLIBINCLUDEDIR "path to zlib include dir" ]] .. _zlibPath .. [[)
SET(ZLIB_LIBRARY ${ZLIBLIBPATH})
SET(ZLIB_INCLUDE_DIR ${ZLIBINCLUDEDIR})

message( ${ZLIB_LIBRARY} )
message( ${ZLIBLIBPATH} )
message( ${ZLIB_INCLUDE_DIR} )
message( ${ZLIBINCLUDEDIR} )
]]
}, function(file)
   return not file:match("SET%(ZLIB_INCLUDE_DIR " .. _zlibPath) or not file:match("SET%(ZLIB_LIBRARY " .. _zlibPath)
end)

log_success("Build environment ready.")
