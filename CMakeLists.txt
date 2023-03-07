cmake_minimum_required (VERSION 3.13)
include(ExternalProject)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
project (eli)

set(BUILD_SHARED_LIBS OFF)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Os -s -fPIC -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto -g3 -Wl,--as-needed -Wl,--gc-sections -DCURL_STATICLIB -static")

if(CMAKE_SYSTEM_NAME STREQUAL Windows) 
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_POSIX_THREAD_SAFE_FUNCTIONS")
  set(HAVE_STRERRORLEN_S CACHE BOOL OFF FORCE)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_CRT_SECURE_NO_WARNINGS")
  # -DLUA_USE_WINDOWS is detected automatically with _WIN32 flag
elseif (CMAKE_SYSTEM_NAME STREQUAL Linux)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_CRT_SECURE_NO_WARNINGS -DLUA_USE_POSIX")
endif()

# INCLUDE PATHS & DIRS
set(CURL_INCLUDE  ${CMAKE_BINARY_DIR}/deps/curl/include/)
set(LUA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua/src/)
set(ZIP_LIB_INCLUDE ${CMAKE_SOURCE_DIR}/deps/libzip/lib/)

set(ZLIB_INCLUDE_DIR ${CMAKE_BINARY_DIR}/deps/zlib/)
set(ZLIB_LIBRARY ${CMAKE_BINARY_DIR}/deps/zlib/libz.a)
set(MbedTLS_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/include)
set(MbedTLS_LIBRARY ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/library)

include_directories(deps/lua/src/ ${ZLIB_INCLUDE_DIR} deps/libzip deps/mbedtls/include deps/curl/include)

# MBEDTLS
set(ENABLE_ZLIB_SUPPORT ON CACHE BOOL "")
add_subdirectory(deps/mbedtls/ EXCLUDE_FROM_ALL)

# subprojects
set(ELI_STREAM_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-stream-extra/src)
set(ELI_EXTRA_UTILS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-extra-utils/src)

add_subdirectory(deps/lua-is-tty/)
add_subdirectory(deps/lua-mbed-hash/)
add_subdirectory(deps/Lua-cURLv3/)
add_subdirectory(deps/lua-zlib/)
target_include_directories(lzlib PRIVATE ${ZLIB_INCLUDE_DIR})
add_subdirectory(deps/eli-extra-utils/)
add_subdirectory(deps/eli-env-extra/)
target_include_directories(eli_env_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-fs-extra/)
target_include_directories(eli_fs_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-os-extra/)
target_include_directories(eli_os_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-pipe-extra/)
target_include_directories(eli_pipe_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE} ${ELI_STREAM_EXTRA_INCLUDE})
add_subdirectory(deps/eli-proc-extra/)
target_include_directories(eli_proc_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE} ${ELI_STREAM_EXTRA_INCLUDE})
add_subdirectory(deps/eli-stream-extra/)
target_include_directories(eli_stream_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/lua-mbed-bigint/)
target_include_directories(lua_mbed_bigint PUBLIC ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/lua-tar-extract-native/)
target_include_directories(ltar PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})

# ZLIB
add_subdirectory(deps/zlib/)
add_custom_target(copy_zlib_files ALL DEPENDS zlibstatic)
add_custom_command(TARGET copy_zlib_files POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/deps/zlib/*.h ${ZLIB_INCLUDE_DIR}
)
if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  add_custom_command(TARGET copy_zlib_files POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${ZLIB_INCLUDE_DIR}/libzlibstatic.a ${ZLIB_INCLUDE_DIR}/libz.a
  )
endif()
# disable other targets
set_target_properties(example example64 minigzip minigzip64 zlib PROPERTIES EXCLUDE_FROM_ALL 1)

# LIBZIP
# set(ENABLE_COMMONCRYPTO CACHE BOOL OFF FORCE)
# set(ENABLE_GNUTLS CACHE BOOL OFF FORCE)
# set(ENABLE_MBEDTLS CACHE BOOL ON FORCE)
# set(ENABLE_OPENSSL CACHE BOOL OFF FORCE)
# set(ENABLE_WINDOWS_CRYPTO CACHE BOOL OFF FORCE)
# set(ENABLE_BZIP2 CACHE BOOL OFF FORCE)
# set(ENABLE_LZMA CACHE BOOL OFF FORCE)
# set(ENABLE_ZSTD CACHE BOOL OFF FORCE)
# set(BUILD_TOOLS CACHE BOOL OFF FORCE)
# set(BUILD_REGRESS CACHE BOOL OFF FORCE)
# set(BUILD_EXAMPLES CACHE BOOL OFF FORCE)
# set(BUILD_DOC CACHE BOOL OFF FORCE)

# if (CMAKE_SYSTEM_NAME STREQUAL Linux)
#   set(HAVE__CLOSE CACHE BOOL OFF FORCE)
#   set(HAVE__DUP CACHE BOOL OFF FORCE)
#   set(HAVE__FDOPEN CACHE BOOL OFF FORCE)
#   set(HAVE__FILENO CACHE BOOL OFF FORCE)
#   set(HAVE__SETMODE CACHE BOOL OFF FORCE)
#   set(HAVE__STRDUP CACHE BOOL OFF FORCE)
#   set(HAVE__STRTOI64 CACHE BOOL OFF FORCE)
#   set(HAVE__STRTOUI64 CACHE BOOL OFF FORCE)
#   set(HAVE__UNLINK CACHE BOOL OFF FORCE)
#   set(HAVE_ARC4RANDOM CACHE BOOL OFF FORCE)
#   set(HAVE_CLONEFILE CACHE BOOL OFF FORCE)
#   set(HAVE_EXPLICIT_MEMSET CACHE BOOL OFF FORCE)
#   set(HAVE_GETPROGNAME CACHE BOOL OFF FORCE)
#   set(HAVE_MEMCPY_S CACHE BOOL OFF FORCE)
#   set(HAVE_SETMODE CACHE BOOL OFF FORCE)
#   set(HAVE_STRERROR_S CACHE BOOL OFF FORCE)
#   set(HAVE_STRICMP CACHE BOOL OFF FORCE)
#   set(HAVE_STRNCPY_S CACHE BOOL OFF FORCE)
# endif()

#set(CMAKE_POLICY_DEFAULT_CMP0063 NEW)
set(BUILD_SHARED_LIBS CACHE BOOL OFF FORCE)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/deps/libzip/)
add_dependencies(zip zlibstatic)
target_include_directories(zip PUBLIC ${ZLIB_INCLUDE_DIR})

# LUA-ZIP
set(LUA_ZIP_BUILD_SHARED OFF)
add_subdirectory(${CMAKE_SOURCE_DIR}/deps/lua-zip/)
target_include_directories(lua_zip PUBLIC ${LUA_INCLUDE} ${ZIP_LIB_INCLUDE})
add_dependencies(lua_zip zip)

# LIBCURL
set(CURL_LIB_CPPFLAGS "-I${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/include -I${ZLIB_INCLUDE_DIR} -DCURL_STATICLIB")
set(CURL_LIB_LDFLAGS "-L${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/library -L${ZLIB_INCLUDE_DIR}")
ExternalProject_Add(
  curl_lib
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps/curl/
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/deps/curl/configure "CFLAGS=${CMAKE_C_FLAGS}" CPPFLAGS=${CURL_LIB_CPPFLAGS} CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER} LD=${CMAKE_LINKER} AR=${CMAKE_AR} AS=${CMAKE_AS} RANLIB=${CMAKE_RANLIB} RC=${CMAKE_RC_COMPILER} LD_LIBRARY_PATH=${ZLIB_INCLUDE_DIR} LDFLAGS=${CURL_LIB_LDFLAGS}
                    --prefix=${CMAKE_BINARY_DIR}/deps/curl/
                    #--without-ssl
                    --with-mbedtls=${CMAKE_BINARY_DIR}/deps/mbedtls
                    --without-libpsl
                    --without-libidn2
                    --disable-ares
                    --disable-cookies
                    --disable-manual
                    --disable-unix-sockets
                    --disable-versioned-symbols
                    --without-librtmp
                    --disable-ldap
                    --disable-tftp
                    --disable-dict
                    --disable-pthreads
                    --disable-threaded-resolver
                    --disable-ldaps
                    --disable-dict
                    --disable-sspi
                    --disable-socketpair
                    --disable-doh
                    --disable-netrc
                    --disable-dnsshuffle
                    --disable-progress-meter
                    --without-quiche
                    --without-libssh2
                    --without-nss
                    --disable-pop3
                    --disable-smtp
                    --disable-telnet
                    --disable-rtsp
                    --disable-imap
                    --disable-gopher
                    --disable-verbose
                    --disable-libcurl-option
                    --without-nghttp2
                    --without-zlib
                    --with-zlib=${ZLIB_INCLUDE_DIR}
                    --host=${CURL_HOST}
                    --disable-smb
                    --disable-mqtt
                    --disable-ntlm
                    --disable-ntlm-wb
                    --disable-shared
                    --without-ca-bundle
                    --without-ca-path
                    --enable-static
                    --enable-symbol-hiding
  PREFIX ${CMAKE_BINARY_DIR}/deps/curl/
  BUILD_COMMAND make
  BUILD_IN_SOURCE 1
)
add_dependencies(curl_lib mbedtls copy_zlib_files zlibstatic)
add_library(curl STATIC IMPORTED)
set_target_properties(curl PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/deps/curl/lib/libcurl.a)
add_dependencies(curl curl_lib)

# LUA-CURL
add_dependencies(lcurl curl_lib)
target_include_directories(lcurl PUBLIC ${CURL_INCLUDE})

# ELI
# 1. eli interpreter
add_executable (eli deps/lua/onelua.c)
target_link_libraries(eli lis_tty lcurl lua_zip ltar eli_fs_extra eli_proc_extra eli_pipe_extra eli_stream_extra eli_os_extra eli_env_extra eli_extra_utils lua_mbed_bigint curl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlibstatic "-static")
if(WIN32 OR MINGW)
  target_link_libraries (eli bcrypt advapi32 ws2_32 )
endif()
set_target_properties(eli PROPERTIES OUTPUT_NAME "eli") 

# 2. eli compiler (not used right now)
# add_executable (elic lua/src/onelua.c)
# target_link_libraries (elic lis_tty lcurl lua_zip ltar eli_extra_utils curl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlib "-static")
# if(WIN32 OR MINGW)
#   target_link_libraries (elic advapi32 ws2_32)
# endif()
# set_target_properties(elic PROPERTIES OUTPUT_NAME "elic") 
