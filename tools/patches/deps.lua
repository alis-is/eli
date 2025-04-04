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
local LUA_ZIP_C = "deps/lua-zip/lua_zip.c"
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
			return file:match"\nLUALIB_API void luaL_openlibs.-\n%s*}"
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
			   :gsub("\nLUALIB_API void luaL_openlibs", _rendered)                                -- inject libs
			local _start, _end = _linit:find"\nLUALIB_API void luaL_openlibs.*$"
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
			local unloadCode = [[
			/* Begin __unload code injection */

			lua_getglobal(L, "____UNLOAD_MODULE");  // Get the ____UNLOAD_MODULE table
			if (lua_istable(L, -1)) {
				lua_pushnil(L);  // first key for lua_next
				while (lua_next(L, -2) != 0) {
				  // -1 is the unload routine, -2 is the key (module name)
				  if (lua_isfunction(L, -1)) {
					 lua_call(L, 0, 0);  // unload
				  } else {
					 lua_pop(L, 1);  // pop unload if not a function
				  }
				}
				
			}	
			lua_pop(L, 1);  // Pop ____UNLOAD_MODULE

			/* End __unload code injection */
			]]

			-- check if patched alreadyt with `/* Begin __unload code injection */ .* /* End __unload code injection */`
			local start, _end = file:find"/%* Begin __unload code injection %*/.-/%* End __unload code injection %*/\n"
			local targetPos, targetContinueFrom
			if not start then
				-- find the close_state function
				start, _end = file:find"void lua_close%s-%(lua_State %*L%)%s-{.-\n%s*}"
				if not start then
					error"failed to find lua_close function"
				end
				-- find ` close_state(L);` position
				local closeStateStart, _ = file:sub(start, _end):find("close_state(L)", 1, true)
				if not closeStateStart then
					error"failed to find close_state(L);"
				end

				targetPos = start - 1 + closeStateStart - 1
				targetContinueFrom = targetPos + 1
			else
				targetPos = start - 1
				targetContinueFrom = _end
			end

			-- Locate the lua_close function and inject the __unload code
			local _patched = file:sub(1, targetPos) .. unloadCode .. file:sub(targetContinueFrom)

			return _patched
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
		patch = function (file)
			if not config.global_modules then
				local _toReplace = {
					['\n\t\tLUA_LDIR"%?%.lua;"  LUA_LDIR"%?/init%.lua;" \\'] = "",
					['\n\t\tLUA_CDIR"%?%.lua;"  LUA_CDIR"%?/init%.lua;" \\'] = "",
					['LUA_CDIR"%?%.so;" LUA_CDIR"loadall%.so;"'] = "",
					['\n\t\tLUA_SHRDIR"%?%.lua;" LUA_SHRDIR"%?\\\\init%.lua;" \\'] = "",
				}
				for _pattern, _replacement in pairs(_toReplace) do
					file = file:gsub(_pattern, _replacement)
				end
			end
			if not file:match"eliconf%.h" then
				file = "#include <eliconf.h>\n" .. file
			end
			return file
		end,
	},
	[LUA_ZIP_C] = {
		patch = function (file)
			local _toReplace = {
				["LUALIB_API int luaopen_brimworks_zip"] = "LUALIB_API int luaopen_lzip",
			}
			for _pattern, _replacement in pairs(_toReplace) do
				file = file:gsub(_pattern, _replacement)
			end
			return file
		end,
	},
	[LIBZIP_CMAKELISTS] = {
		-- // TODO: handle in root CMakeLists.txt
		patch = function (file)
			local _zlibPath = path.combine(os.cwd(), "build/deps/zlib/")
			local _toReplace = {
				["SET%(ZLIB_INCLUDE_DIR .-\n"] = "",
				["SET%(ZLIB_LIBRARY .-\n"] = "",
				["option%(ZLIBINCLUDEDIR .-\n"] = "",
				["option%(ZLIBLIBPATH .-\n"] = "",
				["CMAKE_MINIMUM_REQUIRED.-\n"] = [[CMAKE_MINIMUM_REQUIRED(VERSION 3.0.2)
option(ZLIBLIBPATH "path to zlib" ]] .. _zlibPath .. [[)
option(ZLIBINCLUDEDIR "path to zlib include dir" ]] .. _zlibPath .. [[)
SET(ZLIB_LIBRARY ${ZLIBLIBPATH})
SET(ZLIB_INCLUDE_DIR ${ZLIBINCLUDEDIR})

message( ${ZLIB_LIBRARY} )
message( ${ZLIBLIBPATH} )
message( ${ZLIB_INCLUDE_DIR} )
message( ${ZLIBINCLUDEDIR} )
]],
			}
			for _pattern, _replacement in pairs(_toReplace) do
				file = file:gsub(_pattern, _replacement)
			end
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
			return file:match"HTTP_USER_AGENT_VALUE"
		end,
		patch = function (file)
			-- #define HTTP_USER_AGENT_VALUE "lua-corehttp"
			-- replace user agent with eli version
			return file:gsub("#define HTTP_USER_AGENT_VALUE .-\n",
				"#define HTTP_USER_AGENT_VALUE \"eli/" .. config.version .. "\"\n")
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
			local _certs = _buildUtil.get_ca_certs()
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
