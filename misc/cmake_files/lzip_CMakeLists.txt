project (lua_zip)  # project here actually means solution in premake

file(GLOB lua_zip_sources ./**.c)
set(lua_zip ${lua_zip_sources})

add_library (lua_zip  ${lua_zip})
target_link_libraries (lua_zip)
