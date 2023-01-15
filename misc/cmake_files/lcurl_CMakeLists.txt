cmake_minimum_required (VERSION 2.9)
project (lcurl)  # project here actually means solution in premake

file(GLOB lcurl_sources ./src/**.c)
set(lcurl ${lcurl_sources})

add_library (lcurl  ${lcurl})
target_link_libraries (lcurl)