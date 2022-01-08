local lustache = require"lustache"
local hjson = require"hjson"
local _templates = require"tools.templates"

local log_success, log_info = util.global_log_factory("build", "success", "info")
GLOBAL_LOGGER.options.format = "standard"

local _config = hjson.parse(fs.read_file("config.hjson"))
local BUILD_TYPE = _config.build_type or "MINSIZEREL"

require"tools.download"
require"tools.create-env"
log_info("Building eli...")
fs.remove("release", { recurse = true })
fs.mkdirp("release")

--local _tmpname = os.tmpname
--local _root = os.cwd()
--os.tmpname = function()
--   return "/root/luabuild" .. _tmpname()
--end

local _toolchains = os.getenv("TOOLCHAINS")
if not _toolchains then
   if _config.toolchains then
      for _,toolchain in ipairs(_config.toolchains) do
         _toolchains = (_toolchains or "") + toolchain + ';'
      end
   end
   if not _toolchains then
      _toolchains="x86_64-linux-musl-cross"
   end
end

local _isMultitoolchain = _toolchains:find(";")

local function execute_collect_stdout(cmd)
   local _result = proc.exec(cmd, { stdout = "pipe" })
   return _result.exitcode, _result.stdoutStream:read("a")
end

local function prepare_ca_cert(dst)
   local tmp = os.tmpname()
   net.download_file("https://curl.se/ca/cacert.pem", tmp, { followRedirects = true })
   local certs = ""
   local ca = fs.read_file(tmp)
   for cert in ca:gmatch("%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-.-%-%-%-%-%-END CERTIFICATE%-%-%-%-%-") do
     certs = certs .. cert .. '\n'
   end
   fs.mkdirp(dst)
   fs.write_file(path.combine(dst, "cacert.pem"), certs)
   os.execute("chmod 644 " .. path.combine(dst, "cacert.pem"))
end

local function buildWithChain(id, buildDir)
   log_info("Building eli for "  .. id .. "...")
   if not fs.exists("/opt/cross/".. id) then
      log_info("Toolchain " .. id .. " not found. Downloading...")
      --fs.mkdirp("/opt/cross/" .. id)
      local tmp = os.tmpname()
      --local tmp2 = os.tmpname()
      net.download_file("https://more.musl.cc/10/i686-linux-musl/" .. id .. ".tgz", tmp)
      -- eli.tar can not handle links annd long links so we use system tar for now
      assert(os.execute("tar -xzvf " .. tmp .. " && mv " .. id .. " /opt/cross/"))
--      lz.extract(tmp, tmp2)
--      tar.extract(tmp2, "/opt/cross/" --[[.. id]], { flattenRootDir = true, filter = function (f)
--         print(f)
--         return true
--      end })
      log_success("Toolchain " .. id .. " downloaded.")
   end
   log_info("Initiating build eli for "  .. id .. "...")
   buildDir = buildDir or path.combine("build", id)
   fs.remove(buildDir, { recurse = true })
   fs.mkdirp(buildDir)

   local _oldCwd = os.cwd()
   os.chdir(buildDir)
   local _, gcc = execute_collect_stdout('find -H /opt/cross/' .. id ..' -name "*-gcc" -type f')
   local _, gpp = execute_collect_stdout('find -H /opt/cross/' .. id ..' -name "*-g++" -type f')
   local _, ld = execute_collect_stdout('find -H /opt/cross/' .. id ..' -name "*-ld" -type f')
   local _, ar = execute_collect_stdout('find -H /opt/cross/' .. id ..'/bin -name "*-ar" -type f ! -name "*-gcc-ar"')
   local _, ranlib = execute_collect_stdout('find -H /opt/cross/' .. id ..' -name "*-ranlib" -type f')
   local _, rc = execute_collect_stdout('find -H /opt/cross/' .. id ..' -name "*-windres" -type f')

   local _cmd = lustache:render(_templates.buildConfigureTemplate, {
      ld = ld:gsub("\n",""),
      ranlib = ranlib:gsub("\n",""),
      ar = ar:gsub("\n",""),
      gcc = gcc:gsub("\n",""),
      gpp = gpp:gsub("\n",""),
      rootDir = _oldCwd,
      rc = rc:gsub("\n",""),
      BUILD_TYPE = BUILD_TYPE,
      ccf = BUILD_TYPE == "MINSIZEREL" and "-s" or "" })

   log_info("Configuring (".. _cmd ..")...")
   os.execute(_cmd)
   log_info("Building (make)...")
   os.execute"make"
   os.chdir(_oldCwd)
   fs.copy_file(path.combine(buildDir, "eli"), "release/eli-unix-" .. id:gsub("%-linux%-musl%-cross", ""))
end

if _config.inject_CA then
   local caDir = "build/ca"
   prepare_ca_cert(caDir)
   local _mbedtls = fs.read_file"modules/curl/lib/vtls/mbedtls.c"
   local _cacert = fs.read_file(path.combine(caDir, "cacert.pem"))

   local _tmp_cert = ""
   for _, line in ipairs(string.split(_cacert, "\n")) do
      _tmp_cert = _tmp_cert .. '"'  .. require"tools.escape".escape_string(line, 'txt') .. '\\n"\n'
   end
   _tmp_cert = _tmp_cert:sub(1, #_tmp_cert -1) .. ';'
   local _caCerSnippet = [[mbedtls_x509_crt_init(&backend->cacert);
/* CA Certificates */
const char eli_cacert[] = ]] .. _tmp_cert .. [[
ret = mbedtls_x509_crt_parse(&backend->cacert, eli_cacert, sizeof(eli_cacert));
if (ret) {
#ifdef MBEDTLS_ERROR_C
mbedtls_strerror(ret, errorbuf, sizeof(errorbuf));
#endif /* MBEDTLS_ERROR_C */
failf(data, "Error reading ca cert file - mbedTLS: (-0x%%04X) %%s", -ret, errorbuf);
if(verifypeer)
return CURLE_SSL_CERTPROBLEM;
}
if(ssl_cafile && false)]]
   local content = _mbedtls:gsub("mbedtls_x509_crt_init%(&backend%->cacert%);.-if%(ssl_cafile.-%)", _caCerSnippet)
   fs.write_file("modules/curl/lib/vtls/mbedtls.c", content)
end

if _isMultitoolchain then 
   for toolchain in _toolchains:gmatch("[^;]+") do
      buildWithChain(toolchain)
   end
else
   buildWithChain(_toolchains, "build")
end

log_success("Build completed.")
log_info("Generating meta definitions...")
fs.remove(".meta", { recurse = true })
os.execute("chmod +x ./release/eli-unix-*")
os.execute("./release/eli-unix-$(uname -m) ./tools/meta-generator.lua")
zip.compress(".meta", "release/meta.zip", { recurse = true })
log_success("Meta definitions generated...")