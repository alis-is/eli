return {
	LINIT_LIBS_LIST = fs.read_file"tools/templates/linit-libs-list.mustache",
	LINIT_LIBS_LOAD = fs.read_file"tools/templates/linit-libs-load.mustache",
	ELI_INIT = fs.read_file"tools/templates/eli-init.mustache",
	CURL_MBED_CA_LOADER = fs.read_file"tools/templates/curl-mbed-ca-loader.mustache",
	MBED_ELI_OVERRIDES = fs.read_file"tools/templates/mbed-eli-overrides.mustache",
	CMAKE_GCC = fs.read_file"tools/templates/cmake-gcc.mustache",
	CMAKE_CLANG = fs.read_file"tools/templates/cmake-clang.mustache",
}