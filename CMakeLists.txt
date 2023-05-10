cmake_minimum_required (VERSION 3.13)
include(CMakeDependentOption)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_CROSSCOMPILING CACHE BOOL ON FORCE)
project (eli)

set_directory_properties(PROPERTIES CURL_CA_BUNDLE "none")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Os -s -fPIC -fPIE -ffunction-sections -fdata-sections -g3 -Wl,--as-needed -Wno-sign-compare -Wl,--gc-sections -static -DCURL_STATICLIB")
set(LD_FLAGS "${LD_FLAGS} -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_CRT_SECURE_NO_WARNINGS")

if (CMAKE_SYSTEM_NAME STREQUAL Linux)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -DLUA_USE_LINUX")
elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -DLUA_USE_MACOSX")
elseif(CMAKE_SYSTEM_NAME STREQUAL Windows)
  # -DLUA_USE_WINDOWS is detected automatically
  if (NOT CMAKE_C_COMPILER_ID STREQUAL "Clang")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions")
  endif()
  # -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions
  # causes STATUS_BAD_FUNCTION_TABLE on windows with clang so we compile without
endif()

# INCLUDE PATHS & DIRS
set(CURL_INCLUDE  ${CMAKE_BINARY_DIR}/deps/curl/include/)
set(LUA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua/)
set(ZIP_LIB_INCLUDE ${CMAKE_BINARY_DIR}/deps/libzip/ ${CMAKE_SOURCE_DIR}/deps/libzip/lib/)

set(ZLIB_INCLUDE_DIR ${CMAKE_BINARY_DIR}/deps/zlib/ CACHE STRING "zlib" FORCE)
set(ZLIB_LIBRARY ${CMAKE_BINARY_DIR}/deps/zlib/libz.a)
set(MbedTLS_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/include)
set(MbedTLS_LIBRARY ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/library)

include_directories(deps/lua/ ${ZLIB_INCLUDE_DIR} deps/libzip deps/mbedtls/include deps/curl/include ${CMAKE_SOURCE_DIR}/deps/zlib)

# MBEDTLS
set(ENABLE_ZLIB_SUPPORT ON CACHE BOOL "")
add_subdirectory(deps/mbedtls/ EXCLUDE_FROM_ALL)

# subprojects
set(ELI_STREAM_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-stream-extra/src)
set(ELI_EXTRA_UTILS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-extra-utils/src)

add_subdirectory(deps/lua-is-tty/)
add_subdirectory(deps/lua-mbed-hash/)
add_subdirectory(deps/Lua-cURLv3/)
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
target_include_directories(lua_mbed_bigint PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/lua-tar-extract-native/)
target_include_directories(ltar PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})

if (NOT CMAKE_SYSTEM_NAME STREQUAL Windows)
  OPTION (CARES_STATIC "CARES_STATIC" ON)
  OPTION (CARES_STATIC_PIC "CARES_STATIC_PIC" ON)
  OPTION (CARES_SHARED "CARES_SHARED" OFF)
  OPTION (CARES_BUILD_TOOLS "CARES_BUILD_TOOLS" OFF)
  OPTION (CARES_INSTALL "CARES_INSTALL" OFF)
  add_subdirectory(deps/c-ares/)
  set(CARES_LIBS c-ares)

  # for libcurl
  option(ENABLE_ARES "ENABLE_ARES" ON)
  set(CARES_LIBRARY c-ares CACHE INTERNAL "" FORCE)
  set(CARES_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/deps/c-ares/include CACHE STRING "ares" FORCE)
endif()

# ZLIB
add_subdirectory(deps/zlib/ EXCLUDE_FROM_ALL)
add_custom_target(copy_zlib_files ALL DEPENDS zlibstatic)
add_custom_command(TARGET copy_zlib_files POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${ZLIB_INCLUDE_DIR}/libzlibstatic.a ${ZLIB_INCLUDE_DIR}/libz.a || exit 0
)

# LUA-ZLIB
add_subdirectory(deps/lua-zlib/)
target_include_directories(lzlib PRIVATE ${ZLIB_INCLUDE_DIR})
add_dependencies(lzlib copy_zlib_files)

# LIBZIP
set(CMAKE_POLICY_DEFAULT_CMP0063 NEW)
set(BUILD_SHARED_LIBS CACHE BOOL OFF FORCE)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/deps/libzip/ EXCLUDE_FROM_ALL)
add_dependencies(zip zlibstatic mbedx509 mbedtls mbedcrypto)
target_include_directories(zip PRIVATE ${ZLIB_INCLUDE_DIR} ${MbedTLS_INCLUDE_DIR})

# LUA-ZIP
set(LUA_ZIP_BUILD_SHARED OFF)
add_subdirectory(${CMAKE_SOURCE_DIR}/deps/lua-zip/)
target_include_directories(lua_zip PRIVATE ${LUA_INCLUDE} ${ZIP_LIB_INCLUDE})
add_dependencies(lua_zip zip)

# LIBCURL
## disable target export
option(CURL_ENABLE_EXPORT_TARGET "CURL_ENABLE_EXPORT_TARGET" OFF)
## force mbedtls
option(CURL_ENABLE_SSL "Enable SSL support" ON)
cmake_dependent_option(CURL_USE_MBEDTLS "Enable mbedTLS for SSL/TLS" ON CURL_ENABLE_SSL OFF)
set(MBEDTLS_LIBRARY mbedtls CACHE INTERNAL "" FORCE)
set(MBEDX509_LIBRARY mbedx509 CACHE INTERNAL "" FORCE)
set(MBEDCRYPTO_LIBRARY mbedcrypto CACHE INTERNAL "" FORCE)
set(MBEDTLS_INCLUDE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/include CACHE STRING "mbed" FORCE)

# disabled CA bundling (we inject our own into mbedtls loader)
option(CURL_CA_BUNDLE "CURL_CA_BUNDLE" "none")
option(CURL_CA_PATH "CURL_CA_PATH" "none")

# disable unecessary protocols and features
option(CURL_DISABLE_FTP "Disable FTP" OFF)
option(CURL_DISABLE_GOPHER "Disable GOPHER" ON)
option(CURL_DISABLE_DICT "Disable DICT" ON)
option(CURL_DISABLE_POP3 "CURL_DISABLE_POP3" ON)
option(CURL_DISABLE_IMAP "CURL_DISABLE_IMAP" ON)
option(CURL_DISABLE_MQTT "CURL_DISABLE_MQTT" ON)
option(CURL_DISABLE_TELNET "CURL_DISABLE_TELNET" ON)
option(CURL_DISABLE_RTSP "CURL_DISABLE_RTSP" ON)
option(CURL_DISABLE_TFTP "CURL_DISABLE_TFTP" ON)
option(CURL_DISABLE_SMB "CURL_DISABLE_SMB" ON)
option(CURL_DISABLE_SMTP "CURL_DISABLE_SMTP" ON)
option(CURL_DISABLE_NTLM "CURL_DISABLE_NTLM" ON)
option(CURL_DISABLE_LDAPS "CURL_DISABLE_LDAPS" ON)
option(CURL_DISABLE_PROGRESS_METER "CURL_DISABLE_PROGRESS_METER" ON)
option(CURL_DISABLE_NETRC "disables netrc parser" ON)
option(CURL_DISABLE_VERBOSE_STRINGS "CURL_DISABLE_VERBOSE_STRINGS" ON)
option(CURL_DISABLE_COOKIES "CURL_DISABLE_COOKIES" ON)
option(USE_UNIX_SOCKETS "USE_UNIX_SOCKETS" OFF)
option(USE_LIBIDN2 "USE_LIBIDN2" OFF)
option(ENABLE_THREADED_RESOLVER "ENABLE_THREADED_RESOLVER" OFF)

add_subdirectory(${CMAKE_SOURCE_DIR}/deps/curl/ EXCLUDE_FROM_ALL)
add_dependencies(libcurl zlibstatic mbedx509 mbedtls mbedcrypto ${CARES_LIBS})

# # LUA-CURL
add_dependencies(lcurl libcurl zlibstatic mbedx509 mbedtls mbedcrypto ${CARES_LIBS})
target_include_directories(lcurl PUBLIC ${CURL_INCLUDE})

# ELI
# 1. eli interpreter
add_executable (eli deps/lua/onelua.c)
# lcurl curl
target_link_libraries(eli lis_tty lua_zip ltar eli_fs_extra eli_proc_extra eli_pipe_extra eli_stream_extra eli_os_extra eli_env_extra eli_extra_utils lua_mbed_bigint lcurl libcurl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlibstatic ${CARES_LIBS} "-static")
if(WIN32 OR MINGW)
  target_link_libraries (eli bcrypt advapi32 ws2_32)
endif()
set_target_properties(eli PROPERTIES OUTPUT_NAME "eli") 

# 2. eli compiler (not used right now)
# add_executable (elic lua/src/onelua.c)
# target_link_libraries (elic lis_tty lcurl lua_zip ltar eli_extra_utils curl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlib "-static")
# if(WIN32 OR MINGW)
#   target_link_libraries (elic advapi32 ws2_32)
# endif()
# set_target_properties(elic PROPERTIES OUTPUT_NAME "elic") 
