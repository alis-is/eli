local lustache = require "lustache"
local hjson = require "hjson"
local _templates = require "tools.templates"
local _buildUtil = require "tools.util"

local log_success, log_info = util.global_log_factory("build", "success", "info")
GLOBAL_LOGGER.options.format = "standard"

local _config = hjson.parse(fs.read_file("config.hjson"))
local BUILD_TYPE = _config.build_type or "MINSIZEREL"

require "tools.patches.deps"
log_info("Building eli...")

--local _tmpname = os.tmpname
--local _root = os.cwd()
--os.tmpname = function()
--   return "/root/luabuild" .. _tmpname()
--end

local _toolchains = os.getenv("TOOLCHAINS")
if not _toolchains then
   if _config.toolchains then
      for _, toolchain in ipairs(_config.toolchains) do
         _toolchains = (_toolchains or "") + toolchain + ';'
      end
   end
   if not _toolchains then
      _toolchains = "x86_64-linux-musl-cross"
   end
end

local _isMultitoolchain = _toolchains:find(";")

local function execute_collect_stdout(cmd)
   local _result = proc.exec(cmd, { stdout = "pipe" })
   return _result.exitcode, _result.stdoutStream:read("a")
end

local function buildWithChain(id, buildDir)
   log_info("Building eli for " .. id .. "...")
   if not fs.exists("/opt/cross/" .. id) then
      log_info("Toolchain " .. id .. " not found. Downloading...")
      --fs.mkdirp("/opt/cross/" .. id)
      local tmp = os.tmpname()
      --local tmp2 = os.tmpname()
      local _ok = net.safe_download_file("https://github.com/alis-is/musl-toolchains/releases/download/global/" ..
         id .. ".tgz", tmp)
      if not _ok then
         print("Mirror not found. Downloading from upstream.")
         net.download_file("https://more.musl.cc/11/x86_64-linux-musl/" .. id .. ".tgz", tmp)
      end
      -- eli.tar can not handle links and long links so we use system tar for now
      assert(os.execute("tar -xzvf " .. tmp .. " && mv " .. id .. " /opt/cross/"))
      --      lz.extract(tmp, tmp2)
      --      tar.extract(tmp2, "/opt/cross/" --[[.. id]], { flattenRootDir = true, filter = function (f)
      --         print(f)
      --         return true
      --      end })
      log_success("Toolchain " .. id .. " downloaded.")
   end
   log_info("Initiating build eli for " .. id .. "...")
   buildDir = buildDir or path.combine("build", id)
   fs.remove(buildDir, { recurse = true })
   fs.mkdirp(buildDir)

   local _oldCwd = os.cwd()
   os.chdir(buildDir)
   local _, gcc = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-gcc" -type f')
   local _, gpp = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-g++" -type f')
   local _, ld = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-ld" -type f')
   local _, ar = execute_collect_stdout('find -H /opt/cross/' .. id .. '/bin -name "*-ar" -type f ! -name "*-gcc-ar"')
   local _, ranlib = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-ranlib" -type f')
   local _, rc = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-windres" -type f')
   local _, strip = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-strip" -type f')
   local _, objdump = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-objdump" -type f')
   local _, as = execute_collect_stdout('find -H /opt/cross/' .. id .. ' -name "*-as" -type f')

   local _cmd = lustache:render(_templates.buildConfigureTemplate, {
      ld = ld:gsub("\n", ""),
      ranlib = ranlib:gsub("\n", ""),
      ar = ar:gsub("\n", ""),
      as = as:gsub("\n", ""),
      objdump = objdump:gsub("\n", ""),
      gcc = gcc:gsub("\n", ""),
      gpp = gpp:gsub("\n", ""),
      strip = strip:gsub("\n", ""),
      rootDir = _oldCwd,
      rc = rc:gsub("\n", ""),
      BUILD_TYPE = BUILD_TYPE,
      ccf = BUILD_TYPE == "MINSIZEREL" and "-s" or "",
      SYSTEM_NAME = id:match("mingw") and "Windows" or "Linux",
      ch = id:gsub("%-cross", ""),
		TOOLCHAIN_ROOT = path.combine(os.cwd(), "toolchains/id")
   })

   log_info("Configuring (" .. _cmd .. ")...")
   os.execute(_cmd)
   log_info("Building (make)...")
   os.execute "make"
   os.chdir(_oldCwd)
   fs.mkdirp("release")
   if id:match("mingw") or id:match("mingw") then
      fs.copy_file(path.combine(buildDir, "eli.exe"), "release/eli-win-" .. id:gsub("%-w64%-mingw32%-cross", "") .. ".exe")
   else
      fs.copy_file(path.combine(buildDir, "eli"), "release/eli-unix-" .. id:gsub("%-linux%-musl%-cross", ""))
   end
end

if _isMultitoolchain then
   for toolchain in _toolchains:gmatch("[^;]+") do
      buildWithChain(toolchain)
   end
else
   buildWithChain(_toolchains, "build")
end

log_success("Build completed.")
if os.execute("chmod +x ./release/eli-unix-$(uname -m) && ./release/eli-unix-$(uname -m) -e \"print''\"") then
   log_info("Generating meta definitions...")
   fs.remove(".meta", { recurse = true })
   os.execute("chmod +x ./release/eli-unix-*")
   os.execute("./release/eli-unix-$(uname -m) ./tools/meta-generator.lua")
   fs.safe_remove("release/meta.zip", {})
   zip.compress(".meta", "release/meta.zip", { recurse = true })
   log_success("Meta definitions generated...")
end
