project (lzlib)  # project here actually means solution in premake

file(GLOB lzlib_sources ./**.c)
set(lzlib ${lzlib_sources})

add_library (lzlib  ${lzlib})
target_link_libraries (lzlib)

