cmake_minimum_required (VERSION 2.6)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -I${CMAKE_CURRENT_SOURCE_DIR}/modules/libzip -Os -DLUA_USE_POSIX -s -fPIC")
SET(BUILD_SHARED_LIBS OFF)
SET(CMAKE_EXE_LINKER_FLAGS "-static")

project (lua)

add_definitions(-DLIBFETCH_WITH_MBEDTLS)

include(ExternalProject)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/lua/src/ 
                ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib 
                ${CMAKE_CURRENT_SOURCE_DIR}/modules/libzip/lib 
                ${CMAKE_BINARY_DIR}/modules/libzip 
                ${CMAKE_BINARY_DIR}/modules/mbedtls/include
                ${CMAKE_CURRENT_SOURCE_DIR}/modules/apk-tools/libfetch/
                )

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/mbedtls/ EXCLUDE_FROM_ALL)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lua_is_tty/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lua_mbed_hash/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-fs-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-proc-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-env-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/apk-tools/libfetch/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lfetch/)
add_dependencies(fetch mbedtls)
add_dependencies(lfetch fetch mbedtls)

ExternalProject_Add(
  zlib_lib
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/modules/zlib/
  UPDATE_COMMAND ""
  INSTALL_COMMAND ""
  BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib
  BUILD_ALWAYS ON
  CMAKE_CACHE_ARGS         "-DCMAKE_C_COMPILER:STRING=${CMAKE_C_COMPILER}"
                           "-DCMAKE_CXX_COMPILER:STRING=${CMAKE_CXX_COMPILER}"
                           "-DCMAKE_LINKER:STRING=${CMAKE_LINKER}"
                           "-DCMAKE_AR:STRING=${CMAKE_AR}"
                           "-DCMAKE_ARRANLIB:STRING=${CMAKE_RANLIB}"
                           "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_FLAGS}"
                           "-DCMAKE_RC_COMPILER:STRING=${CMAKE_RC_COMPILER}"
  BUILD_ALWAYS ON
)

add_custom_command(TARGET zlib_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/modules/zlib/*.h ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib
)

SET(ZLIB_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib)
SET(ZLIB_LIB_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib)
SET(ENABLE_ZLIB_SUPPORT ON CACHE BOOL "")
add_library(zlib STATIC IMPORTED)
set_target_properties(zlib PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib/libz.a)
#add_dependencies(zlib zlip_lib)

ExternalProject_Add(
  zip_lib
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/modules/libzip/
  BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/libzip
  UPDATE_COMMAND ""
  INSTALL_COMMAND ""
  CMAKE_CACHE_ARGS         "-DENABLE_COMMONCRYPTO:BOOL=OFF"
                           "-DENABLE_GNUTLS:BOOL=OFF"
                           "-DENABLE_MBEDTLS:BOOL=ON"
                           "-DENABLE_OPENSSL:BOOL=OFF"
                           "-DENABLE_WINDOWS_CRYPTO:BOOL=OFF"
                           "-DENABLE_BZIP2:BOOL=OFF"
                           "-DBUILD_TOOLS:BOOL=OFF"
                           "-DBUILD_REGRESS:BOOL=OFF"
                           "-DBUILD_EXAMPLES:BOOL=OFF"
                           "-DBUILD_DOC:BOOL=OFF"
                           "-DBUILD_SHARED_LIBS:BOOL=OFF"
                           "-DCMAKE_C_COMPILER:STRING=${CMAKE_C_COMPILER}"
                           "-DCMAKE_CXX_COMPILER:STRING=${CMAKE_CXX_COMPILER}"
                           "-DCMAKE_LINKER:STRING=${CMAKE_LINKER}"
                           "-DCMAKE_AR:STRING=${CMAKE_AR}"
                           "-DCMAKE_ARRANLIB:STRING=${CMAKE_RANLIB}"
                           "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_FLAGS}"
                           "-DMBEDTLS_INCLUDE_DIR:STRING=${CMAKE_CURRENT_BINARY_DIR}/modules/mbedtls/include"
                           "-DMBEDTLS_LIBRARIES:STRING=${CMAKE_CURRENT_BINARY_DIR}/modules/mbedtls/library"
                           "-DZLIBINCLUDEDIR:STRING=${ZLIB_INCLUDE_DIR}"
                           "-DZLIBLIBPATH:STRING=${ZLIB_LIB_DIR}"
                           "-DCMAKE_RC_COMPILER:STRING=${CMAKE_RC_COMPILER}"
  BUILD_ALWAYS ON
)
add_dependencies(zip_lib mbedtls zlib zlib_lib)

add_library(zip STATIC IMPORTED)
set_target_properties(zip PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/modules/libzip/lib/libzip.a)
add_dependencies(zip zip_lib zlib)

set(LUA_ZIP_BUILD_SHARED OFF CACHE BOOL "")
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lzip/)
add_dependencies(lzip zip)

if(WIN32)
        add_definitions( -D_CRT_SECURE_NO_WARNINGS )
endif()

# 1. eli interpreter

link_directories (${LUA_BINARY_DIR})
add_executable (eli  lua/src/onelua.c)
target_link_libraries (eli lis_tty lfetch fetch mbed_compat lzip eli_fs_extra eli_proc_extra eli_env_extra mbedx509 mbedtls mbedcrypto lhash zip zlib "-static") 
add_dependencies(eli zip)
set_target_properties(eli PROPERTIES OUTPUT_NAME "eli") 

if(UNIX)
        target_link_libraries(eli m "-static")
endif()

# 2. eli compiler

link_directories (${LUA_BINARY_DIR})
add_executable (elic  lua/src/onelua.c)
target_link_libraries (elic lis_tty lfetch fetch mbed_compat lzip eli_fs_extra eli_proc_extra eli_env_extra mbedx509 mbedtls mbedcrypto lhash zip zlib "-static") 
add_dependencies(elic zip)
set_target_properties(elic PROPERTIES OUTPUT_NAME "elic") 


if(UNIX)
        target_link_libraries(elic m "-static")
endif()
