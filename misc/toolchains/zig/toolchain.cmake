

set(SCRIPT_SUFFIX ".sh")

set(CMAKE_C_COMPILER "${CMAKE_CURRENT_LIST_DIR}/cc${SCRIPT_SUFFIX}" -target ${CLANG_TARGET})
set(CMAKE_CXX_COMPILER "${CMAKE_CURRENT_LIST_DIR}/cxx${SCRIPT_SUFFIX}" -target ${CLANG_TARGET})
set(CMAKE_AR "${CMAKE_CURRENT_LIST_DIR}/ar${SCRIPT_SUFFIX}")
set(CMAKE_RANLIB "${CMAKE_CURRENT_LIST_DIR}/ranlib${SCRIPT_SUFFIX}")

if (CMAKE_SYSTEM_NAME STREQUAL Windows)
	# we do not actually use RC_COMPILER but cmake requires it to generate project
	set(CMAKE_RC_COMPILER "windres") #/opt/cross/toolchains/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-windres")
	set(CMAKE_LD "${CMAKE_CURRENT_LIST_DIR}/lld-link${SCRIPT_SUFFIX}")
elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin)
	set(CMAKE_LD "${CMAKE_CURRENT_LIST_DIR}/ld64.lld${SCRIPT_SUFFIX}")
else()
	set(CMAKE_LD "${CMAKE_CURRENT_LIST_DIR}/ld.ldd${SCRIPT_SUFFIX}")
endif()
# wasm-ld