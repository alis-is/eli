-- Run from the repository root: eli tools/patches/deps-test.lua
-- Exercise the actual rule without running overlays, embedding, or writes.
local function read(file)
	local f = assert(io.open(file, "rb"))
	local text = f:read"a"
	f:close()
	return text
end

local init_template = read("tools/templates/eli-init.mustache")
assert(init_template:match("if %(luaL_dostring%(L, eli_init%) != LUA_OK%)%s*return lua_error%(L%);"),
	"embedded startup errors must escape pmain")

local rule = assert(read("tools/patches/deps.lua"):match("%[LUACONF_H%] = ({.-\n\t}),"))
local config = { global_modules = false }
local patch = assert(load("return " .. rule, "luaconf patch", "t",
	{ config = config, pairs = pairs, assert = assert }))().patch

local function check(source)
	config.global_modules = false
	local patched = patch(source)
	assert(patch(patched) == patched, "patch must be idempotent")
	local windows, unix = assert(patched:match("#define LUA_VDIR(.-)#else(.-)\n#endif%s*\n%s*/%*"))
	assert(not unix:match('LUA_[LC]DIR%s*"%?'), "global Unix search paths remain")
	assert(not unix:match('LUA_CDIR%s*"loadall'), "global loadall remains")
	assert(not windows:match('LUA_SHRDIR%s*"%?'), "shared Windows search path remains")
	assert(unix:find('"./?.lua;" "./?/init.lua"', 1, true))
	assert(unix:find('"./?.so"', 1, true))
	assert(windows:find('LUA_CDIR', 1, true))
	assert(windows:find([[".\\?.lua;" ".\\?\\init.lua"]], 1, true))
	local mac = assert(patched:match("#if defined%(LUA_USE_MACOSX%)(.-)\n#endif"))
	assert(not mac:find("LUA_USE_READLINE", 1, true))
	if source:find("#define LUA_USE_READLINE", 1, true) then
		assert(mac:find('#if !defined(LUA_READLINELIB)', 1, true))
	end
	assert(mac:find('"libedit.dylib"', 1, true))
	assert(mac:find("LUA_USE_DLOPEN", 1, true))
	config.global_modules = true
	local enabled = patch(source)
	assert(patch(enabled) == enabled)
	local paths = "(#define LUA_VDIR.-)\n/%*\n@@ LUA_DIRSEP"
	assert(enabled:match(paths) == assert(source:match(paths)), "enabled paths changed")
end

-- Last pinned Lua before the update (compact macro/string concatenation).
-- CI checkouts are shallow and may not contain that commit; skip then.
local old = assert(io.popen("git -C deps/lua show a5522f06d2679b8f18534fd6a9968f7eb539dc31:luaconf.h", "r"))
local old_source = old:read"a"
local old_ok = old:close()
if old_ok and old_source ~= "" then
	check(old_source)
else
	print("skipping old Lua check (commit not available in this checkout)")
end
-- Current upstream, regardless of whether the build has patched the worktree.
local current = assert(io.popen("git -C deps/lua show HEAD:luaconf.h", "r"))
local new_source = current:read"a"
assert(current:close())
check(new_source)
-- Also exercise tabs and varied indentation between adjacent tokens.
check((new_source:gsub('LUA_([A-Z]+DIR) ', 'LUA_%1\t'):gsub('\t\t', '    ')))
print("dependency patch regressions passed (old/new Lua, whitespace, idempotence)")
