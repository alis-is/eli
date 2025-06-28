cmake_minimum_required(VERSION 3.13)
include(CMakeDependentOption)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_CROSSCOMPILING CACHE BOOL ON FORCE)
project(eli)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${BUILD_FLAGS} -fPIC -fPIE -ffunction-sections -fdata-sections -g0 -Wl,--as-needed -Wno-sign-compare -Wl,--gc-sections -static")
set(LD_FLAGS "${LD_FLAGS} -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_CRT_SECURE_NO_WARNINGS")

if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -flto -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -DLUA_USE_LINUX")
elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -DLUA_USE_MACOSX")
elseif(CMAKE_SYSTEM_NAME STREQUAL Windows)
  # -DLUA_USE_WINDOWS is detected automatically
  if(NOT CMAKE_C_COMPILER_ID STREQUAL "Clang")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -flto -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions")
  endif()

  # -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions
  # causes STATUS_BAD_FUNCTION_TABLE on windows with clang so we compile without
endif()

# INCLUDE PATHS & DIRS
set(LUA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua/)
set(ZIP_LIB_INCLUDE ${CMAKE_BINARY_DIR}/deps/libzip/ ${CMAKE_SOURCE_DIR}/deps/libzip/lib/)

set(ZLIB_INCLUDE_DIR ${CMAKE_BINARY_DIR}/deps/zlib-ng/ CACHE STRING "zlib" FORCE)
set(ZLIB_LIBRARY ${CMAKE_BINARY_DIR}/deps/zlib-ng/libz.a)
set(MbedTLS_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/include)
set(MbedTLS_LIBRARY ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/library/libmbedtls.a)

include(${CMAKE_SOURCE_DIR}/deps/corehttp/httpFilePaths.cmake)

# include_directories(deps/lua/ ${ZLIB_INCLUDE_DIR} ${HTTP_INCLUDE_PUBLIC_DIRS} deps/libzip deps/mbedtls/include deps/curl/include ${CMAKE_SOURCE_DIR}/deps/zlib)
include_directories(deps/lua/ ${ZLIB_INCLUDE_DIR} ${HTTP_INCLUDE_PUBLIC_DIRS} deps/libzip deps/mbedtls/include ${CMAKE_SOURCE_DIR}/deps/zlib-ng ${CMAKE_SOURCE_DIR}/deps/lua-corehttp/include)

# MBEDTLS
set(ENABLE_ZLIB_SUPPORT ON CACHE BOOL "")
add_subdirectory(deps/mbedtls/ EXCLUDE_FROM_ALL)

# subprojects
set(ELI_STREAM_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-stream-extra/src)
set(ELI_OS_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-os-extra/src)
set(ELI_EXTRA_UTILS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-extra-utils/src)
set(ELI_PIPE_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-pipe-extra/src)
set(C11THREADS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/c11threads)

set(LSS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua-simple-socket/src)

add_subdirectory(deps/lua-is-tty/)
add_subdirectory(deps/lua-mbed-hash/)

add_subdirectory(deps/c11threads/)
add_subdirectory(deps/eli-extra-utils/)
target_include_directories(eli_extra_utils PRIVATE ${C11THREADS_INCLUDE})
add_subdirectory(deps/lua-simple-socket/)
target_include_directories(lssocket PRIVATE ${ELI_EXTRA_UTILS_INCLUDE} ${HTTP_INCLUDE_PUBLIC_DIRS})
target_compile_definitions(lssocket PRIVATE LSS_HAS_BUNDLED_ROOT_CERTIFICATES)
add_subdirectory(deps/lua-corehttp/)
target_include_directories(lcorehttp PRIVATE ${ELI_EXTRA_UTILS_INCLUDE} ${HTTP_INCLUDE_PUBLIC_DIRS} ${LSS_INCLUDE})
add_subdirectory(deps/corehttp/)
add_subdirectory(deps/lua-simple-ipc/)
target_include_directories(lua_simple_ipc PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-env-extra/)
target_include_directories(eli_env_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-fs-extra/)
target_include_directories(eli_fs_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-os-extra/)
target_include_directories(eli_os_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/eli-pipe-extra/)
target_include_directories(eli_pipe_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE} ${ELI_STREAM_EXTRA_INCLUDE})
add_subdirectory(deps/eli-proc-extra/)
target_include_directories(eli_proc_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE} ${ELI_STREAM_EXTRA_INCLUDE} ${ELI_OS_EXTRA_INCLUDE} ${ELI_PIPE_EXTRA_INCLUDE})
add_subdirectory(deps/eli-stream-extra/)
target_include_directories(eli_stream_extra PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/lua-mbed-bigint/)
target_include_directories(lua_mbed_bigint PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/lua-mbed-base64/)
target_include_directories(lua_mbed_base64 PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})
add_subdirectory(deps/lua-tar-read-native/)
target_include_directories(ltar PRIVATE ${ELI_EXTRA_UTILS_INCLUDE})

# ZLIB
set(ZLIB_COMPAT ON CACHE BOOL "")
set(ZLIB_ENABLE_TESTS OFF CACHE BOOL "")
set(WITH_AVX512 OFF CACHE BOOL "" FORCE)
set(WITH_AVX512VNNI OFF CACHE BOOL "" FORCE)
set(ZLIBNG_ENABLE_TESTS OFF CACHE BOOL "")
add_subdirectory(deps/zlib-ng/ EXCLUDE_FROM_ALL)
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

set(MBEDTLS_LIBRARY mbedtls CACHE INTERNAL "" FORCE)
set(MBEDX509_LIBRARY mbedx509 CACHE INTERNAL "" FORCE)
set(MBEDCRYPTO_LIBRARY mbedcrypto CACHE INTERNAL "" FORCE)
set(MBEDTLS_INCLUDE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/deps/mbedtls/include CACHE STRING "mbed" FORCE)

# ELI
# 1. eli interpreter
add_executable(eli deps/lua/onelua.c)
target_link_libraries(eli lis_tty lua_zip ltar eli_fs_extra eli_pipe_extra eli_proc_extra eli_stream_extra eli_os_extra eli_env_extra eli_extra_utils lua_mbed_bigint lua_mbed_base64 lua_simple_ipc lssocket corehttp lcorehttp mbedx509 mbedtls mbedcrypto lhash zip lzlib zlibstatic "-static")

if(APPLE)
  target_link_libraries(eli c11threads)
endif()

if(WIN32 OR MINGW)
  target_link_libraries(eli bcrypt advapi32 ws2_32 c11threads)
endif()

set_target_properties(eli PROPERTIES OUTPUT_NAME "eli")

# 2. eli compiler (not used right now)
# add_executable (elic lua/src/onelua.c)
# target_link_libraries (elic lis_tty lcurl lua_zip ltar eli_extra_utils curl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlib "-static")
# if(WIN32 OR MINGW)
# target_link_libraries (elic advapi32 ws2_32)
# endif()
# set_target_properties(elic PROPERTIES OUTPUT_NAME "elic")
