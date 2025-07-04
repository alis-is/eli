local lustache = require"lustache"
local hjson = require"hjson"
local _templates = require"tools.templates"

local log_success, log_info = util.global_log_factory("build", "success", "info")
GLOBAL_LOGGER.options.format = "standard"

local _config = hjson.parse(fs.read_file"config.hjson")

require"tools.patches.deps"
log_info"Building eli..."

local BUILD_TYPE = nil
local BUILD_FLAGS = nil
local isDebug = false
local shouldRemoveOldBuild = false
-- Loop through the command-line arguments
for _, v in ipairs(arg) do
	-- Look for the --build-type= argument
	if v:find"--build-type=" then
		BUILD_TYPE = v:gsub("--build-type=", ""):upper()
	end

	-- Look for the --debug argument
	if v:find"--debug" then
		isDebug = true
		if v == "--debug" then
			BUILD_FLAGS = "-O0 -gfull"
		else
			BUILD_FLAGS = v:gsub("--debug=", "")
		end

		if BUILD_TYPE == nil or BUILD_TYPE == "MINSIZEREL" then
			BUILD_TYPE = "DEBUG"
		end
	end

	if v:find"--clean" then
		shouldRemoveOldBuild = true
	end
end
-- defaults
BUILD_TYPE = BUILD_TYPE or "MINSIZEREL"
BUILD_FLAGS = BUILD_FLAGS or "-Os -s -g0"


local _toolchains = os.getenv"TOOLCHAINS"
if not _toolchains then
	if _config.toolchains then
		for _, toolchain in ipairs(_config.toolchains) do
			_toolchains = (_toolchains or "") + toolchain + ";"
		end
	end
	if not _toolchains then
		_toolchains = "x86_64-linux-musl-cross"
	end
end

local _isMultitoolchain = _toolchains:find";"

local function execute_collect_stdout(cmd)
	local _result = proc.exec(cmd, { stdout = "pipe" })
	return _result.exitcode, _result.stdoutStream:read"a"
end

local function configure(id, rootDir, isZig, toolchainDor)
	local _cmd, builtBinaryId

	if isZig then
		local target = id:sub(#isZig + 1)
		local _start = target:find"-"
		local _end = target:find("-", _start + 1) or 0
		local system = target:sub(_start + 1, #target - (#target - _end) - 1)
		builtBinaryId = system .. "-" .. target:sub(0, _start - 1)
		if system:find"^macos" then
			system = "darwin"
		end
		-- capitalize
		system = system:sub(1, 1):upper() .. system:sub(2)

		_cmd = lustache:render(_templates.CMAKE_CLANG, {
			rootDir = rootDir,
			toolchainFile = path.combine(toolchainDor or rootDir, "misc/toolchains/zig/toolchain.cmake"),
			target = target,
			SYSTEM_NAME = system,
			BUILD_TYPE = BUILD_TYPE,
			BUILD_FLAGS = BUILD_FLAGS,
			inject_ca = _config.inject_ca and "ON" or "OFF",
		})
	else
		local _, gcc = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-gcc" -type f')
		local _, gpp = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-g++" -type f')
		local _, ld = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-ld" -type f')
		local _, ar = execute_collect_stdout("find -H /opt/cross/" ..
			id .. '/bin -name "*-ar" -type f ! -name "*-gcc-ar"')
		local _, ranlib = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-ranlib" -type f')
		local _, rc = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-windres" -type f')
		local _, strip = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-strip" -type f')
		local _, objdump = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-objdump" -type f')
		local _, as = execute_collect_stdout("find -H /opt/cross/" .. id .. ' -name "*-as" -type f')

		_cmd = lustache:render(_templates.CMAKE_GCC, {
			ld = ld:gsub("\n", ""),
			ranlib = ranlib:gsub("\n", ""),
			ar = ar:gsub("\n", ""),
			as = as:gsub("\n", ""),
			objdump = objdump:gsub("\n", ""),
			gcc = gcc:gsub("\n", ""),
			gpp = gpp:gsub("\n", ""),
			strip = strip:gsub("\n", ""),
			rootDir = rootDir,
			rc = rc:gsub("\n", ""),
			BUILD_TYPE = BUILD_TYPE,
			BUILD_FLAGS = BUILD_FLAGS,
			ccf = BUILD_TYPE == "MINSIZEREL" and "-s" or "",
			SYSTEM_NAME = id:match"mingw" and "Windows" or "Linux",
			ch = id:gsub("%-cross", ""),
			TOOLCHAIN_ROOT = path.combine(os.cwd(), path.combine("toolchains", id)),
			inject_ca = _config.inject_ca and "ON" or "OFF",
		})
		if id:match"mingw" or id:match"win" then
			builtBinaryId = "win-" .. id:gsub("%-w64%-mingw32%-cross", "")
		else
			builtBinaryId = "linux-" .. id:gsub("%-linux%-musl%-cross", "")
		end
	end

	log_info("Configuring (" .. _cmd .. ")...")
	os.execute(_cmd)
	return builtBinaryId
end

local function buildWithChain(id, buildDir)
	log_info("Building eli for " .. id .. "...")
	local isZig = id:match"^zig:"

	if not fs.exists("/opt/cross/" .. id) and not isZig then
		log_info("Toolchain " .. id .. " not found. Downloading...")
		--fs.mkdirp("/opt/cross/" .. id)
		local tmp = os.tmpname()
		local tmp2 = os.tmpname()
		local _ok = net.download_file("https://github.com/alis-is/musl-toolchains/releases/download/global/" ..
			id .. ".tgz", tmp)
		if not _ok then
			print"Mirror not found. Downloading from upstream."
			net.download_file("https://more.musl.cc/11/x86_64-linux-musl/" .. id .. ".tgz", tmp)
		end
		-- eli.tar can not handle links and long links so we use system tar for now
		--assert(os.execute("tar -xzvf " .. tmp .. " && mv " .. id .. " /opt/cross/"))
		lz.extract(tmp, tmp2)
		tar.extract(tmp2, "/opt/cross/" --[[.. id]], {
			flattenRootDir = true,
			filter = function (f)
				print(f)
				return true
			end,
		})
		os.remove(tmp)
		os.remove(tmp2)
		log_success("Toolchain " .. id .. " downloaded.")
	end
	if id:match"mingw" or id:match"win" then -- build kill binary
		log_info("Initiating build eli-kill for " .. id .. "...")
		local buildDir = "deps/eli-proc-extra/kill/build"
		if shouldRemoveOldBuild then
			fs.remove(buildDir, { recurse = true })
		end
		fs.mkdirp(buildDir)
		local _oldCwd = os.cwd()
		os.chdir(buildDir)
		local builtBinaryId = configure(id, path.combine(_oldCwd, "deps/eli-proc-extra/kill"), isZig, _oldCwd)
		log_info"Building eli-kill (make)..."
		if not os.execute"make" then
			error"Failed to build eli-kill!"
		end
		os.chdir(_oldCwd)

		-- patch eli proc extra
		local eliProcExtraKillBinary = fs.read_file"deps/eli-proc-extra/kill/build/kill.exe"
		local killBinaryBytes = table.map(
			table.filter(
				table.pack(string.byte(eliProcExtraKillBinary, 1, -1)),
				function (k)
					return type(k) == "number"
				end),
			function (b)
				return string.format("\\x%02x", b)
			end)
		local rendered = lustache:render(_templates.ELI_PROC_EXTRA_KILL_H, {
			binarySize = #eliProcExtraKillBinary + 1,
			binary = '"' .. string.join("", killBinaryBytes) .. '"',
		})
		fs.write_file("deps/eli-proc-extra/src/kill.h", rendered)
	end

	log_info("Initiating build eli for " .. id .. "...")
	buildDir = buildDir or path.combine("build", id)
	if isZig then
		buildDir = buildDir:gsub("zig:", "")
	end
	if shouldRemoveOldBuild then
		fs.remove(buildDir, { recurse = true })
	end
	fs.mkdirp(buildDir)

	local _oldCwd = os.cwd()
	os.chdir(buildDir)
	local builtBinaryId = configure(id, _oldCwd, isZig)
	log_info"Building eli (make)..."
	os.execute"make"
	os.chdir(_oldCwd)
	fs.mkdirp"release"
	local _buildSuffix = ""
	if isDebug then
		_buildSuffix = "-debug"
	end
	if fs.exists(path.combine(buildDir, "eli.exe")) then
		fs.copy_file(path.combine(buildDir, "eli.exe"), "release/eli-" .. builtBinaryId .. _buildSuffix .. ".exe")
	else
		fs.copy_file(path.combine(buildDir, "eli"), "release/eli-" .. builtBinaryId .. _buildSuffix)
	end
end

if _isMultitoolchain then
	for toolchain in _toolchains:gmatch"[^;]+" do
		buildWithChain(toolchain)
	end
else
	buildWithChain(_toolchains, "build")
end

log_success"Build completed."
if os.execute"chmod +x ./release/eli-linux-$(uname -m) && ./release/eli-linux-$(uname -m) -e \"print''\"" then
	log_info"Generating meta definitions..."
	fs.remove(".meta", { recurse = true })
	os.execute"chmod +x ./release/eli-linux-*"
	os.execute"./release/eli-linux-$(uname -m) ./tools/meta-generator.lua"
	fs.remove("release/meta.zip", {})
	os.execute('./release/eli-linux-$(uname -m) -e \'zip.compress(".meta", "release/meta.zip", { recurse = true })\'')
	log_success"Meta definitions generated..."
end
