local lustache = require"lustache"
local hjson = require"hjson"
local config = hjson.parse(fs.read_file"config.hjson")

local log_success, log_info, log_warn = util.global_log_factory("create-env", "success", "info", "warn")

local generate_embedable_module = require"tools.embedable"
local templates = require"tools.templates"
local _buildUtil = require"tools.util"

log_info"overlaying deps"
-- // TODO: remove asDirEntries in the next version
local _entries = fs.read_dir("misc/deps-overlay", { recurse = true, as_dir_entries = true, asDirEntries = true })
for _, entry in ipairs(_entries) do
	if entry:type() ~= "directory" then
		local _dest = path.combine("deps", entry:fullpath():sub(#"misc/deps-overlay" + 2))
		log_info("copying " .. entry:fullpath() .. " to " .. _dest)

		fs.copy_file(entry:fullpath(), _dest)
	end
end


log_info"patching env"

local INIT_SOURCE = config.init
local LINIT_C = "deps/lua/linit.c"
local LSTATE_C = "deps/lua/lstate.c"
local LUA_C = "deps/lua/lua.c"
local LUA_H = "deps/lua/lua.h"
local LUACONF_H = "deps/lua/luaconf.h"
local LIBZIP_CMAKELISTS = "deps/libzip/CMakeLists.txt"
local MBED_MBEDTLS_CONFIG_H = "deps/mbedtls/include/mbedtls/mbedtls_config.h"
local MBED_CMAKELISTS_TXT = "deps/mbedtls/CMakeLists.txt"
local MBED_LIBRARY_CMAKELISTS_TXT = "deps/mbedtls/library/CMakeLists.txt"
local LUA_COREHTTP_CONFIG_H = "deps/lua-corehttp/include/core_http_config.h"

local patches = {
	[INIT_SOURCE] = {
		patch = function (file)
			local _versions = string.interpolate("ELI_LIB_VERSION = '${version}'\nELI_VERSION = '${version}'\n", config)
			local file, count = file:gsub("[ \t]-ELI_LIB_VERSION = .-\n[ \t]-ELI_VERSION = .-\n", "")
			if count == 0 then
				print(file)
				error"failed to inject new version"
			end
			return _versions .. file
		end,
	},
	[LINIT_C] = {
		validate = function (file)
			return file:match"\nLUALIB_API void luaL_openselectedlibs.-\n%s*}"
		end,
		patch = function (file)
			local _embedableLibs = generate_embedable_module(config.lua_libs, {
				minify = config.minify,
				escape = not config.compress,
				escapeForLuaGsub = not config.compress,
			})
			local _embedableLibsSize = #_embedableLibs
			if config.compress then
				_embedableLibs = _buildUtil.compress_string_to_c_bytes(_embedableLibs)
			end
			local _rendered = lustache:render(templates.LINIT_LIBS_LIST, {
				keys = table.keys(config.c_libs),
				pairs = table.to_array(config.c_libs),
				embedableLibs = _embedableLibs,
				compress = config.compress,
			})
			local _linit = file:gsub("/%* eli additional libs %*/.-/%* end eli additional libs %*/\n", "") -- cleanup potential old init
			   :gsub("\nLUALIB_API void luaL_openselectedlibs", _rendered)                        -- inject libs
			return _linit:gsub("\n%s-}%s-$", "\n" .. lustache:render(
				templates.LINIT_LIBS_LOAD,
				{ embedableLibsLength = _embedableLibsSize, compress = config.compress }
			))
		end,
	},
	[LSTATE_C] = {
		validate = function (file)
			return file:match"lua_close%s-%(lua_State %*L%)%s-{.-\n%s*}"
		end,
		patch = function (file)
			local helpers = [[/* Begin __unload helpers injection */
static int rununloadhooks (lua_State *L) {
  lua_getglobal(L, "____UNLOAD_MODULE");
  if (lua_istable(L, -1)) {
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
      if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
          lua_pop(L, 1);
          lua_warning(L, "error while running unload hook", 0);
        }
      }
      else
        lua_pop(L, 1);
    }
  }
  lua_pop(L, 1);
  return 0;
}
/* End __unload helpers injection */
]]
			local call = [[  /* Begin __unload call injection */
  L->status = LUA_OK;  /* unload hooks run as a normal protected call */
  if (lua_checkstack(L, 2)) {
    lua_pushcfunction(L, rununloadhooks);
    if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
      lua_pop(L, 1);
      lua_warning(L, "error while running unload hooks", 0);
    }
  }
  else
    lua_warning(L, "could not run unload hooks", 0);
  /* End __unload call injection */
]]

			file = file:gsub("[ \t]*/%* Begin __unload helpers injection %*/.-/%* End __unload helpers injection %*/\n?", "")
			file = file:gsub("[ \t]*/%* Begin __unload call injection %*/.-/%* End __unload call injection %*/\n?", "")
			file = file:gsub("[ \t]*/%* Begin __unload code injection %*/.-/%* End __unload code injection %*/\n?", "")

			-- The helpers must precede close_state, which runs them after the
			-- state's call frames and status are normalized but before objects
			-- are finalized. Calling them from lua_close (or before teardown)
			-- trips lua_pcall's normal-thread API check on a state that ended
			-- in error.
			local closeStateDef = file:find("static void close_state %(lua_State %*L%) {")
			if not closeStateDef then
				error"failed to find close_state function"
			end
			file = file:sub(1, closeStateDef - 1) .. helpers .. file:sub(closeStateDef)

			local anchor = "L->top.p = L->stack.p + 1;  /* empty the stack to run finalizers */"
			local anchorStart, anchorEnd = file:find(anchor, 1, true)
			if not anchorStart then
				error"failed to find close_state stack reset"
			end
			return file:sub(1, anchorEnd) .. "\n" .. call .. file:sub(anchorEnd + 2)
		end,
	},
	[LUA_C] = {
		validate = function (file)
			return file:match"createargtable%(L,.-\n"
		end,
		patch = function (file)
			local _new = file:gsub("/%* eli init %*/.-/%* end eli init %*/\n", "") -- cleanup old init
			local _, _end = _new:find"createargtable%(L,.-\n"

			local _embedable = generate_embedable_module({ { files = { config.init } } }, {
				amalgate = false,
				minify = config.minify,
			})
			local _rendered = lustache:render(templates.ELI_INIT, { embedableInit = _embedable })
			return _new:sub(1, _end) .. _rendered .. _new:sub(_end + 1)
		end,
	},
	[LUA_H] = {
		validate = function (file)
			return file:match"LUA_COPYRIGHT" and
			   file:match"#define LUA_COPYRIGHT[\t ]-LUA_RELEASE \"  Copyright %(C%) .- Lua.org, PUC%-Rio"
		end,
		patch = function (file)
			local COPYRIGHT_LINE_PATTERN = '#define LUA_COPYRIGHT[\t ]-LUA_RELEASE "  Copyright %(C%).-".-\n'

			local _copyright = file:match(COPYRIGHT_LINE_PATTERN)
			local _luaCopyright = _copyright:match"#define LUA_COPYRIGHT[\t ]-LUA_RELEASE \"  Copyright %(C%) .- Lua.org, PUC%-Rio"
			local _newCopyright = string.interpolate(
				"${lua_copyright}\\neli ${version}  Copyright (C) 2019-${year} alis.is\"\n", {
					lua_copyright = _luaCopyright,
					version = config.version,
					year = os.date"%Y",
				})
			local _start, _end = file:find(_copyright, 1, true)
			return file:sub(1, _start - 1) .. _newCopyright .. file:sub(_end + 1, file:len())
		end,
	},
	[LUACONF_H] = {
		validate = function (file)
			return file:match"#define LUA_VDIR"
		end,
		patch = function (file)
			if not config.global_modules and
				(not file:match"eliconf%.h" or file:match'LUA_LDIR%s*"%?%.lua;"%s*LUA_LDIR%s*"%?/init%.lua;"') then
				local _toReplace = {
					['\n[\t ]*LUA_LDIR%s*"%?%.lua;"%s*LUA_LDIR%s*"%?/init%.lua;"[\t ]*\\'] = "",
					['\n[\t ]*LUA_CDIR%s*"%?%.lua;"%s*LUA_CDIR%s*"%?/init%.lua;"[\t ]*\\'] = "",
					['LUA_CDIR%s*"%?%.so;"%s*LUA_CDIR%s*"loadall%.so;"'] = "",
					['\n[\t ]*LUA_SHRDIR%s*"%?%.lua;"%s*LUA_SHRDIR%s*"%?\\\\init%.lua;"[\t ]*\\'] = "",
				}
				for _pattern, _replacement in pairs(_toReplace) do
					local _count
					file, _count = file:gsub(_pattern, _replacement)
					assert(_count == 1, "failed to find luaconf global module path: " .. _pattern)
				end
			end
			-- Keep macOS readline optional, using Lua's dlopen/fallback path.
			file = file:gsub("(#if defined%(LUA_USE_MACOSX%)\n)(.-)(\n#endif)",
				function (prefix, body, suffix)
					return prefix .. body:gsub("#define LUA_USE_READLINE[^\n]*",
						'#if !defined(LUA_READLINELIB)\n#define LUA_READLINELIB\t\t"libedit.dylib"\n#endif') .. suffix
				end)
			if not file:match"eliconf%.h" then
				file = "#include <eliconf.h>\n" .. file
			end
			return file
		end,
	},
	[LIBZIP_CMAKELISTS] = {
		-- // TODO: handle in root CMakeLists.txt
		validate = function (file)
			return file:match"project%(libzip"
		end,
		patch = function (file)
			if file:find("SET(ZLIB_LIBRARY ${ZLIBLIBPATH})", 1, true) then
				return file
			end
			local _legacy = file:find("SET(ZLIB_INCLUDE_DIR", 1, true) or file:find("SET(ZLIB_LIBRARY", 1, true) or
				file:find("ZLIBINCLUDEDIR", 1, true) or file:find("ZLIBLIBPATH", 1, true) or
				file:find("CMAKE_MINIMUM_REQUIRED", 1, true)
			if not _legacy then
				return file
			end
			local _zlibPath = path.combine(os.cwd(), "build/deps/zlib/")
			local _toRemove = {
				"SET%(ZLIB_INCLUDE_DIR .-\n",
				"SET%(ZLIB_LIBRARY .-\n",
				"option%(ZLIBINCLUDEDIR .-\n",
				"option%(ZLIBLIBPATH .-\n",
			}
			for _, _pattern in ipairs(_toRemove) do
				local _count
				file, _count = file:gsub(_pattern, "")
				assert(_count == 1, "failed to find libzip zlib path: " .. _pattern)
			end
			local _count
			file, _count = file:gsub("CMAKE_MINIMUM_REQUIRED.-\n", [[CMAKE_MINIMUM_REQUIRED(VERSION 3.0.2)
option(ZLIBLIBPATH "path to zlib" ]] .. _zlibPath .. [[)
option(ZLIBINCLUDEDIR "path to zlib include dir" ]] .. _zlibPath .. [[)
SET(ZLIB_LIBRARY ${ZLIBLIBPATH})
SET(ZLIB_INCLUDE_DIR ${ZLIBINCLUDEDIR})

message( ${ZLIB_LIBRARY} )
message( ${ZLIBLIBPATH} )
message( ${ZLIB_INCLUDE_DIR} )
message( ${ZLIBINCLUDEDIR} )
]])
			assert(_count == 1, "failed to find libzip minimum required version")
			return file
		end,
	},
	[MBED_MBEDTLS_CONFIG_H] = {
		patch = function (file)
			file = file:gsub("/%* eli mbedtls overrides %*/.-/%* end eli mbedtls overrides %*/\n", "")
			return file .. lustache:render(templates.MBED_ELI_OVERRIDES, { overrides = config.mbedtlsOverrides })
		end,
	},
	[MBED_CMAKELISTS_TXT] = {
		patch = function (file)
			-- // TODO: remove after next mbedtls release
			-- right now compilation fails because of empty retval in docs
			if not file:match'# set%(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} %-Werror"%)' then
				file = file:gsub('set%(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} %-Werror"%)',
					'# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror")')
			end
			return file
		end,
	},
	[MBED_LIBRARY_CMAKELISTS_TXT] = {
		patch = function (file)
			if file:match"<CMAKE_RANLIB> %-no_warning_for_no_symbols %-c <TARGET>" then
				file = file:gsub("<CMAKE_RANLIB> %-no_warning_for_no_symbols %-c <TARGET>", "<CMAKE_RANLIB> <TARGET>")
			end
			return file
		end,
	},
	[LUA_COREHTTP_CONFIG_H] = {
		validate = function (file)
			return file:match"#define HTTP_USER_AGENT_VALUE"
		end,
		patch = function (file)
			-- #define HTTP_USER_AGENT_VALUE "lua-corehttp"
			-- replace user agent with eli version
			local _patched, _count = file:gsub("#define HTTP_USER_AGENT_VALUE .-\n",
				"#define HTTP_USER_AGENT_VALUE \"eli/" .. config.version .. "\"\n")
			assert(_count == 1, "failed to find corehttp user agent")
			return _patched
		end,
	},
}

for filePath, spec in pairs(patches) do
	log_info("patching " .. filePath)
	spec.validate = spec.validate or function () return true end
	local file = fs.read_file(filePath)

	if not spec.validate(file) then
		error("failed to validate " .. filePath)
	end
	local _patched = spec.patch(file)
	if not _patched then
		log_warn("can not patch " .. tostring(filePath) .. " - no content returned from patch function")
	else
		fs.write_file(filePath, _patched)
	end
end

local LSS_CAS = "deps/lua-simple-socket/src/certs.h"
local injects = {
	[LSS_CAS] = {
		generate = function (file)
			if not config.inject_ca then
				return file
			end
			local _certs = _buildUtil.get_ca_certs(os.getenv"ELI_REUSE_BUNDLED_CA_CERTS")
			local _certsAsByteArrays = table.map(_certs, function (cert)
				return table.map(
					table.filter(
						table.pack(string.byte(cert, 1, -1)),
						function (k)
							return type(k) == "number"
						end),
					function (b)
						return string.format("\\x%02x", b)
					end)
			end)
			local _certsFormatted = string.join("\n", table.map(_certsAsByteArrays, function (certAsByteArray)
				return '"' .. string.join("", certAsByteArray) .. '"'
			end))
			local _certSizes = string.join(",", table.map(_certsAsByteArrays, function (certAsByteArray)
				return #certAsByteArray
			end))

			local _rendered = lustache:render(templates.LSS_CAS, {
				certs = _certsFormatted,
				certSizes = _certSizes,
				certsCount = #_certs,
			})
			return _rendered
		end,
	},
}


for filePath, spec in pairs(injects) do
	log_info("injecting " .. filePath)

	local data = spec.generate()
	if not data then
		log_warn("can not inject " .. tostring(filePath) .. " - no content returned from inject function")
	else
		fs.write_file(filePath, data)
	end
end

log_success"succesfully patched dependencies"
