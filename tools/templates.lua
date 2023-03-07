local templates = {
	LINIT_LIBS_LIST = fs.read_file"tools/templates/linit-libs-list.mustache",
	LINIT_LIBS_LOAD = fs.read_file"tools/templates/linit-libs-load.mustache",
	ELI_INIT = fs.read_file"tools/templates/eli-init.mustache",
	CURL_MBED_CA_LOADER = fs.read_file"tools/templates/curl-mbed-ca-loader.mustache",
	MBED_ELI_OVERRIDES = fs.read_file"tools/templates/mbed-eli-overrides.mustache",
}

templates.buildConfigureTemplate = [[
CC="{{{gcc}}}" CXX="{{{gpp}}}" AR="{{{ar}}}" LD="{{{ld}}}" RANLIB="{{{ranlib}}}" cmake {{{rootDir}}} \
-DCMAKE_AR="{{{ar}}}" -DCMAKE_C_COMPILER="{{{gcc}}}" -DCMAKE_CXX_COMPILER="{{{gpp}}}" -DCMAKE_RC_COMPILER="{{{rc}}}" \
-DCMAKE_AS="{{{as}}}" -DCMAKE_OBJDUMP="{{{objdump}}}" -DCMAKE_STRIP="{{{strip}}}" \
-DCMAKE_BUILD_TYPE={{{BUILD_TYPE}}} -DCMAKE_C_FLAGS={{{ccf}}} -DCURL_HOST={{{ch}}} -DCMAKE_SYSTEM_NAME={{{SYSTEM_NAME}}} \
-DCMAKE_FIND_ROOT_PATH={{{TOOLCHAIN_ROOT}}}
]]

return templates
