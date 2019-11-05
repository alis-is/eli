io = require"io"
lustache = require"lustache"
hjson=require"hjson"
separator = package.config:sub(1,1)
fs = require"eli.fs"
util = require"eli.util"
lfs = require"lfs"
path = require"eli.path"

readfile = fs.readfile
copyfile = fs.copyfile
writefile = fs.writefile

configFile = readfile("config.hjson")

config = hjson.parse(configFile)

-- add libraries
local generateEmbedableModules = require"tools.embedableStringGenerator"

embedableModules = generateEmbedableModules(config.lua_libs, config.minify)
embedableModules = embedableModules:gsub("%%", "%%%%")

loadLibs = [[
/* eli additional libs */
  luaL_getsubtable(L, LUA_REGISTRYINDEX, "_PRELOAD");
  for (lib = preloadedlibs; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_setfield(L, -2, lib->name);
  }
  lua_pop(L, 1);  /* remove _PRELOAD table */
  int arg = lua_gettop(L);
  luaL_loadstring(L, lua_libs);
  lua_insert(L,1);
  lua_call(L,arg,1);
/* end eli additional libs */
}]]

libs_template = [[
/* eli additional libs */
{{#keys}}
int luaopen_{{.}}(lua_State *L);
{{/keys}}
static const luaL_Reg preloadedlibs[] = {
{{#pairs}}
  {"{{value}}", luaopen_{{key}}},
{{/pairs}}
  {NULL, NULL}
};

const char lua_libs[] = "{{{embedableModules}}}";
/* end eli additional libs */

LUALIB_API void luaL_openlibs]]

libs = lustache:render(libs_template, { keys = util.keys(config.c_libs), pairs = util.toArray(config.c_libs), embedableModules = embedableModules })

linit = readfile("lua/src/linit.c")
assert(linit:match("\nLUALIB_API void luaL_openlibs.-\n}"))
newLinit = linit
newLinit = newLinit:gsub("/%* eli additional libs %*/.-/%* end eli additional libs %*/\n", "")
newLinit = newLinit:gsub("\nLUALIB_API void luaL_openlibs", libs)
start, _end = newLinit:find("\nLUALIB_API void luaL_openlibs.*$")
newLinit = newLinit:sub(1, start - 1) .. newLinit:sub(start, _end):gsub("\n}", '\n' .. loadLibs)

writefile("lua/src/linit.c", newLinit)                                                                                                                                                                       

-- add initialization scripts 
embedableModules = generateEmbedableModules({{ files = config.init }}, config.minify, false)
embedableModules = embedableModules:gsub("%%", "%%%%")
init_template = [[
/* eli init */
  const char eli_init[] = "{{{embedableModules}}}";
  int arg = lua_gettop(L);
  luaL_loadstring(L, eli_init);
  lua_insert(L,1);
  lua_call(L,arg,1);    
/* end eli init */
]]

init_sequence = lustache:render(init_template, { embedableModules = embedableModules })
luac = readfile("lua/src/lua.c")

assert(luac:match("createargtable%(L,.-\n"))

newLuac = luac:gsub("/%* eli init %*/.-/%* end eli init %*/\n", "")
start, _end = newLuac:find("createargtable%(L,.-\n")
newLuac = newLuac:sub(1, _end) .. init_sequence .. newLuac:sub(_end + 1)
writefile("lua/src/lua.c", newLuac)

-- setup copyright
luah = readfile("lua/src/lua.h")
copyrightPattern = '#define LUA_COPYRIGHT\tLUA_RELEASE "  Copyright %(C%).-"'

copyright = luah:match(copyrightPattern)
if not copyright:match("Eli.-cryon.io") then
   newCopyright = copyright:sub(1, copyright:len() - 1) .. '\\nEli ' .. config.version .. '  Copyright (C) 2019 cryon.io"'
   start, _end = luah:find(copyright, 1, true)
   writefile("lua/src/lua.h", luah:sub(1, start - 1) .. newCopyright .. luah:sub(_end + 1, luah:len()))
end


-- disable global modules
if not config.global_modules then 
   luaconfh = readfile("lua/src/luaconf.h")

   luaconfh = luaconfh:gsub('\n\t\tLUA_LDIR"%?%.lua;"  LUA_LDIR"%?/init%.lua;" \\', "")
   luaconfh = luaconfh:gsub('\n\t\tLUA_CDIR"%?%.lua;"  LUA_CDIR"%?/init%.lua;" \\', "")
   luaconfh = luaconfh:gsub('LUA_CDIR"%?%.so;" LUA_CDIR"loadall%.so;"', "")
   luaconfh = luaconfh:gsub('\n\t\tLUA_SHRDIR"%?%.lua;" LUA_SHRDIR"%?\\\\init%.lua;" \\', "")   
  
   writefile("lua/src/luaconf.h", luaconfh)
end

-- fix lzip
lzip = readfile("modules/lzip/lua_zip.c")
lzip = lzip:gsub("LUALIB_API int luaopen_brimworks_zip", "LUALIB_API int luaopen_lzip")
writefile("modules/lzip/lua_zip.c", lzip)

for _, download in ipairs(config.downloads) do 
   if download.cmakelists then 
      copyfile("cmake_files" .. separator .. download.cmakelists.source, download.cmakelists.destination)
   end      
end

-- fix libzip CMake
libzipCMake = readfile("modules/libzip/CMakeLists.txt")
zlibPath = path.combine(lfs.currentdir(), "build/modules/zlib/")
if not libzipCMake:match("SET%(ZLIB_INCLUDE_DIR " .. zlibPath) or not libzipCMake:match("SET%(ZLIB_LIBRARY " .. zlibPath) then
   libzipCMake = libzipCMake:gsub("SET%(ZLIB_INCLUDE_DIR .-\n", "")
   libzipCMake = libzipCMake:gsub("SET%(ZLIB_LIBRARY .-\n", "")
   libzipCMake = libzipCMake:gsub("option%(ZLIBINCLUDEDIR .-\n", "")
   libzipCMake = libzipCMake:gsub("option%(ZLIBLIBPATH .-\n", "")
   libzipCMake = libzipCMake:gsub("CMAKE_MINIMUM_REQUIRED.-\n", 
[[CMAKE_MINIMUM_REQUIRED(VERSION 3.0.2)
option(ZLIBLIBPATH "path to zlib" ]] .. zlibPath .. [[)
option(ZLIBINCLUDEDIR "path to zlib include dir" ]] .. zlibPath .. [[)
SET(ZLIB_LIBRARY ${ZLIBLIBPATH})
SET(ZLIB_INCLUDE_DIR ${ZLIBINCLUDEDIR})

message( ${ZLIB_LIBRARY} )
message( ${ZLIBLIBPATH} )
message( ${ZLIB_INCLUDE_DIR} )
message( ${ZLIBINCLUDEDIR} )
]])
   writefile("modules/libzip/CMakeLists.txt", libzipCMake)
end
