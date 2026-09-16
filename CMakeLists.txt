cmake_minimum_required(VERSION 3.13)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_CROSSCOMPILING CACHE BOOL ON FORCE)
project(eli LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Build type flags come from tools/build.lua through the BUILD_FLAGS cache variable.
separate_arguments(ELI_BUILD_FLAGS UNIX_COMMAND "${BUILD_FLAGS}")
add_compile_options(
  ${ELI_BUILD_FLAGS}
  -fPIC
  -fPIE
  -ffunction-sections
  -fdata-sections
  -Wno-sign-compare
  -fno-ident
  $<$<NOT:$<CONFIG:Debug>>:-g0>
)
add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
add_compile_definitions(_DEFAULT_SOURCE)
add_compile_definitions(MBEDTLS_USER_CONFIG_FILE=\"mbedtls/eli_mbedtls_config.h\")
add_link_options(${ELI_BUILD_FLAGS} -fPIC -fPIE)
if(APPLE)
  add_link_options(-Wl,-dead_strip)
else()
  add_link_options(-Wl,--as-needed -Wl,--gc-sections -Wl,-Bsymbolic -static)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  # Static musl: local-exec TLS avoids __tls_get_addr, which zig's riscv64
  # libc.a defines as absolute and LLD cannot relocate.
  add_compile_options(-fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions -ftls-model=local-exec)
  add_compile_definitions(LUA_USE_LINUX)
  # LTO merges zig's compiler-rt bitcode, whose TLS model the backend keeps at
  # global-dynamic, so riscv64 static links must stay LTO-free.
  if(NOT CLANG_TARGET MATCHES "riscv64")
    add_compile_options(-flto)
    add_link_options(-flto)
  endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  add_compile_options(-fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions)
  add_compile_definitions(LUA_USE_MACOSX)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  # -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions
  # causes STATUS_BAD_FUNCTION_TABLE on windows with clang so we compile without
  if(NOT CMAKE_C_COMPILER_ID STREQUAL "Clang")
    add_compile_options(-flto -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions)
    add_link_options(-flto)
  endif()
endif()

# INCLUDES
set(LUA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua)
set(ZLIB_INCLUDE_DIR ${CMAKE_BINARY_DIR}/deps/zlib-ng CACHE STRING "zlib" FORCE)
set(ZLIB_SOURCE_DIR ${CMAKE_SOURCE_DIR}/deps/zlib-ng)
set(ZLIB_LIBRARY ${CMAKE_BINARY_DIR}/deps/zlib-ng/libz.a)
set(MBEDTLS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/mbedtls/include)
set(ZIP_LIB_INCLUDE ${CMAKE_BINARY_DIR}/deps/libzip ${CMAKE_SOURCE_DIR}/deps/libzip/lib)
set(COREHTTP_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua-corehttp/include)

set(ELI_STREAM_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-stream-extra/src)
set(ELI_OS_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-os-extra/src)
set(ELI_EXTRA_UTILS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-extra-utils/src)
set(ELI_PIPE_EXTRA_INCLUDE ${CMAKE_SOURCE_DIR}/deps/eli-pipe-extra/src)
set(C11THREADS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/c11threads)
set(LSS_INCLUDE ${CMAKE_SOURCE_DIR}/deps/lua-simple-socket/src)

include(${CMAKE_SOURCE_DIR}/deps/corehttp/httpFilePaths.cmake)

# MBEDTLS
set(ENABLE_ZLIB_SUPPORT ON CACHE BOOL "")
# mbedtls registers its own tests even though EXCLUDE_FROM_ALL omits their
# executables. Its option is cached, so force it off before entering that
# subdirectory; Eli's tests enable CTest below.
set(ENABLE_TESTING OFF CACHE BOOL "Build Mbed TLS tests." FORCE)
add_subdirectory(deps/mbedtls/ EXCLUDE_FROM_ALL)
unset(ENABLE_TESTING)

# SUBPROJECTS
add_subdirectory(deps/eli-worker/)
target_include_directories(eli_worker PRIVATE
  ${LUA_INCLUDE} ${C11THREADS_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE}
  ${ELI_OS_EXTRA_INCLUDE})

add_subdirectory(deps/lua-is-tty/)
target_include_directories(lis_tty PRIVATE ${LUA_INCLUDE})

add_subdirectory(deps/lua-mbed-hash/)
target_include_directories(lhash PRIVATE ${LUA_INCLUDE} ${MBEDTLS_INCLUDE})

add_subdirectory(deps/c11threads/)

add_subdirectory(deps/eli-extra-utils/)
target_include_directories(eli_extra_utils PRIVATE ${LUA_INCLUDE} ${C11THREADS_INCLUDE})

add_subdirectory(deps/lua-simple-socket/)
target_compile_definitions(lssocket PRIVATE LSS_HAS_BUNDLED_ROOT_CERTIFICATES)
target_include_directories(lssocket PRIVATE ${LUA_INCLUDE} ${MBEDTLS_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE}
  ${C11THREADS_INCLUDE})

add_subdirectory(deps/lua-corehttp/)
target_include_directories(lcorehttp PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE} ${HTTP_INCLUDE_PUBLIC_DIRS}
  ${COREHTTP_INCLUDE} ${LSS_INCLUDE} ${MBEDTLS_INCLUDE} ${ZLIB_INCLUDE_DIR} ${ZLIB_SOURCE_DIR})

add_subdirectory(deps/corehttp/)
target_include_directories(corehttp PUBLIC ${COREHTTP_INCLUDE})

add_subdirectory(deps/lua-simple-ipc/)
target_include_directories(lua_simple_ipc PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE})

add_subdirectory(deps/eli-fs-extra/)
target_include_directories(eli_fs_extra PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE})

add_subdirectory(deps/eli-os-extra/)
target_include_directories(eli_os_extra PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE}
  ${C11THREADS_INCLUDE})

add_subdirectory(deps/eli-pipe-extra/)
target_include_directories(eli_pipe_extra PRIVATE
  ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE} ${ELI_STREAM_EXTRA_INCLUDE})

add_subdirectory(deps/eli-proc-extra/)
target_include_directories(eli_proc_extra PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE}
  ${ELI_STREAM_EXTRA_INCLUDE} ${ELI_OS_EXTRA_INCLUDE} ${ELI_PIPE_EXTRA_INCLUDE}
  ${C11THREADS_INCLUDE})

add_subdirectory(deps/eli-stream-extra/)
target_include_directories(eli_stream_extra PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE})

add_subdirectory(deps/lua-mbed-bigint/)
target_include_directories(lua_mbed_bigint PRIVATE ${LUA_INCLUDE} ${MBEDTLS_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE})

add_subdirectory(deps/lua-mbed-base64/)
target_include_directories(lua_mbed_base64 PRIVATE ${LUA_INCLUDE} ${MBEDTLS_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE})

add_subdirectory(deps/lua-tar-read-native/)
target_include_directories(ltar PRIVATE ${LUA_INCLUDE} ${ELI_EXTRA_UTILS_INCLUDE})

# ZLIB
set(ZLIB_COMPAT ON CACHE BOOL "")
set(ZLIB_ENABLE_TESTS OFF CACHE BOOL "")
set(WITH_AVX512 OFF CACHE BOOL "" FORCE)
set(WITH_AVX512VNNI OFF CACHE BOOL "" FORCE)
set(ZLIBNG_ENABLE_TESTS OFF CACHE BOOL "")
add_subdirectory(deps/zlib-ng/ EXCLUDE_FROM_ALL)
add_custom_target(copy_zlib_files ALL DEPENDS zlibstatic)
add_custom_command(TARGET copy_zlib_files POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${ZLIB_INCLUDE_DIR}/libzlibstatic.a ${ZLIB_INCLUDE_DIR}/libz.a || exit 0
)

# LUA-ZLIB
add_subdirectory(deps/lua-zlib/)
target_include_directories(lzlib PRIVATE ${LUA_INCLUDE} ${ZLIB_INCLUDE_DIR} ${ZLIB_SOURCE_DIR})
add_dependencies(lzlib copy_zlib_files)

# LIBZIP
set(CMAKE_POLICY_DEFAULT_CMP0063 NEW)
set(BUILD_SHARED_LIBS CACHE BOOL OFF FORCE)
# libzip dropped its mbed TLS backend after 1.11.4; don't select it here.
set(ENABLE_MBEDTLS OFF CACHE BOOL "" FORCE)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/deps/libzip/ EXCLUDE_FROM_ALL)
add_dependencies(zip zlibstatic)
target_include_directories(zip PRIVATE ${ZLIB_INCLUDE_DIR} ${ZLIB_SOURCE_DIR})

# LUA-ZIP
set(LUA_ZIP_BUILD_SHARED OFF)
add_subdirectory(${CMAKE_SOURCE_DIR}/deps/lua-zip/)
target_include_directories(lua_zip PRIVATE ${LUA_INCLUDE} ${ZIP_LIB_INCLUDE} ${ZLIB_INCLUDE_DIR} ${ZLIB_SOURCE_DIR})
add_dependencies(lua_zip zip)

# ELI
add_executable(eli deps/lua/onelua.c)
target_include_directories(eli PRIVATE ${LUA_INCLUDE})
target_link_libraries(eli
  lis_tty lua_zip ltar eli_fs_extra eli_pipe_extra eli_proc_extra eli_stream_extra
  eli_worker eli_os_extra eli_extra_utils lua_mbed_bigint lua_mbed_base64 lua_simple_ipc lssocket corehttp lcorehttp
  mbedx509 mbedtls mbedcrypto lhash zip lzlib zlibstatic)

if(APPLE)
  target_link_libraries(eli c11threads)
endif()

if(WIN32 OR MINGW)
  target_link_libraries(eli bcrypt advapi32 ws2_32 c11threads)
endif()

option(ELI_BUILD_TESTS "Build native regression tests" OFF)
if(ELI_BUILD_TESTS)
  enable_testing()
  add_subdirectory(deps/eli-worker/tests)
  if(UNIX)
    add_subdirectory(deps/eli-os-extra/tests)
    add_subdirectory(deps/eli-proc-extra/tests)
    add_subdirectory(deps/lua-simple-socket/tests)
  endif()
  if(WIN32)
    add_subdirectory(deps/eli-proc-extra/tests)
  endif()
endif()
