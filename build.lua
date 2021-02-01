local downloadfile = require"eli.net".downloadfile
local os = require"os"
local lfs = require"lfs"
local lustache = require"lustache"

local hjson=require"hjson"
local fs = require"eli.fs"
local path = require"eli.path"

local BUILD_TYPE = arg[1] or "MINSIZEREL"

readfile = fs.readfile
mkdirp = fs.mkdirp
delete = fs.delete
writefile = fs.writefile

configFile = readfile("config.hjson")
config = hjson.parse(configFile)

require"tools.download"
print("Preparing env")
require"tools.create-env"
print("env prepared")

toolchains = os.getenv("TOOLCHAINS")
if not toolchains then
   if config.toolchains then
      for _,toolchain in ipairs(config.toolchains) do
         toolchains = (toolchains or "") + toolchain + ';'
      end
   end
   if not toolchains then
      toolchains="x86_64-linux-musl-cross"
   end
end

multichain = toolchains:find(";")

local function execute(cmd)
   local f = io.popen(cmd)
   output = f:read"a*"
   exit, signal = f:close()
   return exit, signal, output
end

local function getCACert(dst)
   local tmp = os.tmpname()
   downloadfile("https://curl.se/ca/cacert.pem", tmp, { followRedirects = true })
   local certs = ""
   local ca = readfile(tmp)
   for cert in ca:gmatch("%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-.-%-%-%-%-%-END CERTIFICATE%-%-%-%-%-") do
     certs = certs .. cert .. '\n'
   end 
   mkdirp(dst)
   writefile(path.combine(dst, "cacert.pem"), certs)
   os.execute("chmod 644 " .. path.combine(dst, "cacert.pem"))
end

local function buildWithChain(id, buildDir)
   -- download toolchain if not available
   if lfs.attributes("/opt/cross/".. id) == nil then
      local tmp = os.tmpname()
      downloadfile("https://more.musl.cc/10/i686-linux-musl/" .. id .. ".tgz", tmp)
      os.execute("tar -xzvf " .. tmp .. " && mv " .. id .. " /opt/cross/".. id)
   end
   buildDir = buildDir or path.combine("build", id)
   os.execute("rm -r "..buildDir)
   delete(buildDir, true)
   mkdirp(buildDir)

   oldDir = lfs.currentdir()
   lfs.chdir(buildDir)
   exit, signal, gcc = execute('find -H /opt/cross/' .. id ..' -name "*-gcc" -type f')
   exit, signal, gpp = execute('find -H /opt/cross/' .. id ..' -name "*-g++" -type f')
   exit, signal, ld = execute('find -H /opt/cross/' .. id ..' -name "*-ld" -type f')
   exit, signal, ar = execute('find -H /opt/cross/' .. id ..'/bin -name "*-ar" -type f ! -name "*-gcc-ar"')
   exit, signal, ranlib = execute('find -H /opt/cross/' .. id ..' -name "*-ranlib" -type f')
   exit, signal, rc = execute('find -H /opt/cross/' .. id ..' -name "*-windres" -type f')

   configureTemplate = [[
CC="{{{gcc}}}" CXX="{{{gpp}}}" AR="{{{ar}}}" LD="{{{ld}}}" RANLIB="{{{ranlib}}}" cmake {{{rootDir}}} \
-DCMAKE_AR="{{{ar}}}" -DCMAKE_C_COMPILER="{{{gcc}}}" -DCMAKE_CXX_COMPILER="{{{gpp}}}" -DCMAKE_RC_COMPILER="{{{rc}}}" \
-DCMAKE_BUILD_TYPE={{{BUILD_TYPE}}} -DCMAKE_C_FLAGS={{{ccf}}}
]]
   cmd = lustache:render(configureTemplate, {
      ld = ld:gsub("\n",""),
      ranlib = ranlib:gsub("\n",""),
      ar = ar:gsub("\n",""),
      gcc = gcc:gsub("\n",""),
      gpp = gpp:gsub("\n",""),
      rootDir = oldDir,
      rc = rc:gsub("\n",""),
      BUILD_TYPE = BUILD_TYPE,
      ccf = BUILD_TYPE == "MINSIZEREL" and "-s" or "" })

   print(cmd)
   os.execute(cmd)
   os.execute"make"
   lfs.chdir(oldDir) 
end 

function lines(s)
        if s:sub(-1)~="\n" then s=s.."\n" end
        return s:gmatch("(.-)\n")
end

if config.inject_CA then
   local caDir = "build/ca"
   getCACert(caDir)
   mbedtls = readfile"modules/curl/lib/vtls/mbedtls.c"
   local cacert = readfile(path.combine(caDir, "cacert.pem")) -- "/etc/ssl/certs/ca-certificates.crt"  --(path.combine(caDir, "cacert.pem"))

   tmp_cert = ""
   for line in lines(cacert) do
      tmp_cert = tmp_cert .. '"'  .. require"tools.escape".escape_string(line, 'txt') .. '\\n"\n'
   end
   tmp_cert = tmp_cert:sub(1, #tmp_cert -1)
   tmp_cert = tmp_cert .. ';'
   inject = [[mbedtls_x509_crt_init(&backend->cacert);
/* CA Certificates */
const char eli_cacert[] = ]] .. tmp_cert .. [[
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
   local content = mbedtls:gsub("mbedtls_x509_crt_init%(&backend%->cacert%);.-if%(ssl_cafile.-%)", inject)
   writefile("modules/curl/lib/vtls/mbedtls.c", content)
end

mkdirp("/opt/cross/")
if multichain then 
   for toolchain in toolchains:gmatch("[^;]+") do 
      buildWithChain(toolchain)   
   end
else 
   buildWithChain(toolchains, "build")
end
