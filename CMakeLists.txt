cmake_minimum_required (VERSION 2.6)
project (eli)

SET(BUILD_SHARED_LIBS OFF)
SET(CURL_HOST "x86_64-linux-musl")
SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -I${CMAKE_CURRENT_SOURCE_DIR}/modules/libzip -Os -DLUA_USE_POSIX -s -fPIC  -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto -g3 -Wl,--as-needed -Wl,--gc-sections")
SET(CMAKE_EXE_LINKER_FLAGS "-static -s")

include(ExternalProject)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/lua/src/
                ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib
                ${CMAKE_CURRENT_SOURCE_DIR}/modules/libzip/lib
                ${CMAKE_BINARY_DIR}/modules/libzip
                ${CMAKE_BINARY_DIR}/modules/mbedtls/include
                ${CMAKE_BINARY_DIR}/modules/curl/include
                )

# ZLIB PATHS
SET(ZLIB_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib)
SET(ZLIB_LIBRARY ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib/libz.a)             

# MBEDTLS
SET(ENABLE_ZLIB_SUPPORT ON CACHE BOOL "")
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/mbedtls/ EXCLUDE_FROM_ALL)

# subprojects                
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lua_is_tty/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lua_mbed_hash/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-extra-utils/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-fs-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-stream-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-pipe-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-proc-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-os-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/eli-env-extra/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lcurl/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lzlib/)

# ZLIB
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
add_library(zlib STATIC IMPORTED)
set_target_properties(zlib PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/modules/zlib/libz.a)

# LIBZIP
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
                           "-DMbedTLS_INCLUDE_DIR:STRING=${CMAKE_CURRENT_BINARY_DIR}/modules/mbedtls/include"
                           "-DMbedTLS_LIBRARY:STRING=${CMAKE_CURRENT_BINARY_DIR}/modules/mbedtls/library"
                           "-DZLIB_INCLUDE_DIR:STRING=${ZLIB_INCLUDE_DIR}"
                           "-DZLIB_LIBRARY:STRING=${ZLIB_LIBRARY}"
                           "-DCMAKE_RC_COMPILER:STRING=${CMAKE_RC_COMPILER}"
  BUILD_ALWAYS ON
)
add_dependencies(zip_lib zlib zlib_lib mbedtls)
add_library(zip STATIC IMPORTED)
add_dependencies(zip zip_lib zlib)
set_target_properties(zip PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/modules/libzip/lib/libzip.a)

# LUA-ZIP
SET(LUA_ZIP_BUILD_SHARED OFF)
SET(LIBZIP_INCLUDE_DIR ${ZLIB_INCLUDE_DIR})
SET(LUA_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lua/src/)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/modules/lzip/)
add_dependencies(lua_zip zip)

# LIBCURL
set(CURL_LIB_CPPFLAGS "-I${CMAKE_CURRENT_BINARY_DIR}/modules/mbedtls/include -I${CMAKE_CURRENT_BINARY_DIR}/modules/zlib -I${CMAKE_CURRENT_SOURCE_DIR}/modules/zlib")
set(CURL_LIB_LDFLAGS "-L${CMAKE_CURRENT_BINARY_DIR}/modules/mbedtls/library")
ExternalProject_Add(
  curl_lib
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/modules/curl/
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/modules/curl/configure "CFLAGS=-Os -s -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto" CPPFLAGS=${CURL_LIB_CPPFLAGS} CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER} LD=${CMAKE_LINKER} AR=${CMAKE_AR} RANLIB=${CMAKE_RANLIB} LD_LIBRARY_PATH=${CMAKE_CURRENT_BINARY_DIR}/modules/zlib LDFLAGS=${CURL_LIB_LDFLAGS}
                    --prefix=${CMAKE_BINARY_DIR}/modules/curl/
                    --without-ssl
                    --with-mbedtls=${CMAKE_BINARY_DIR}/modules/mbedtls
                    --without-libpsl
                    --without-libidn2
                    --disable-ares
                    --disable-cookies
                    --disable-manual
                    --disable-unix-sockets
                    --disable-versioned-symbols
                    --enable-hidden-symbols
                    --without-libdin
                    --without-librtmp
                    --disable-ldap
                    --disable-tftp
                    --disable-dict
#                    --disable-file
#                    --disable-ftp
                    --disable-ldaps
                    --disable-thread
                    --disable-dict
                    --disable-sspi
                    --disable-socketpair
                    --disable-doh
                    --disable-netrc
                    --disable-dnsshuffle
                    --disable-progress-meter
                    --without-quiche                                                                                                                                                            --without-libssh2                                                                                                                                                           --without-nss                                                                                                                                                               --without-strerror
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
                    --with-zlib=${CMAKE_CURRENT_SOURCE_DIR}/modules/zlib
                    --host=${CURL_HOST}
                    --disable-smb
                    --disable-mqtt
                    --disable-ntlm-wb
                    --disable-shared
                    --without-ca-bundle
                    --without-ca-path
  PREFIX ${CMAKE_BINARY_DIR}/modules/curl/
  BUILD_COMMAND make
  BUILD_IN_SOURCE 1
)
add_dependencies(curl_lib mbedtls zlib)
add_library(curl STATIC IMPORTED)
set_target_properties(curl PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/modules/curl/lib/libcurl.a)

# LUA-CURL
SET(CURL_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/curl/include)
SET(CURL_LIB_DIR ${CMAKE_CURRENT_BINARY_DIR}/modules/curl/lib)
add_dependencies(lcurl curl_lib)

# ELI
if(WIN32)
        add_definitions( -D_CRT_SECURE_NO_WARNINGS )
endif()

# 1. eli interpreter
link_directories (${LUA_BINARY_DIR})
add_executable (eli lua/src/onelua.c)
target_link_libraries (eli lis_tty lcurl lua_zip eli_fs_extra eli_proc_extra eli_pipe_extra eli_stream_extra eli_extra_utils eli_os_extra eli_env_extra curl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlib "-static") 
set_target_properties(eli PROPERTIES OUTPUT_NAME "eli") 

if(UNIX)
        target_link_libraries(eli m "-static")
endif()

# 2. eli compiler
link_directories (${LUA_BINARY_DIR})
add_executable (elic lua/src/onelua.c)
target_link_libraries (elic lis_tty lcurl lua_zip eli_fs_extra eli_proc_extra eli_pipe_extra eli_stream_extra eli_extra_utils eli_os_extra eli_env_extra curl mbedx509 mbedtls mbedcrypto lhash zip lzlib zlib "-static") 
set_target_properties(elic PROPERTIES OUTPUT_NAME "elic") 

if(UNIX)
        target_link_libraries(elic m "-static")
endif()
