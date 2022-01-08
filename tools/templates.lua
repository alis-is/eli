local templates = {}

templates.loadLibsTemplate = [[
/* eli additional libs */
  luaL_getsubtable(L, LUA_REGISTRYINDEX, "_PRELOAD");
  for (lib = preloadedlibs; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_setfield(L, -2, lib->name);
  }
  lua_pop(L, 1);  /* remove _PRELOAD table */
  int arg = lua_gettop(L);
  luaL_loadstring(L, lua_libs);
  lua_insert(L,1);
  lua_call(L,arg,1);
/* end eli additional libs */
}]]

templates.libsListTemplate = [[
/* eli additional libs */
{{#keys}}
int luaopen_{{.}}(lua_State *L);
{{/keys}}
static const luaL_Reg preloadedlibs[] = {
{{#pairs}}
  {"{{value}}", luaopen_{{key}}},
{{/pairs}}
  {NULL, NULL}
};

const char lua_libs[] = "{{{embedableLibs}}}";
/* end eli additional libs */

LUALIB_API void luaL_openlibs]]

templates.eliInitTemplate = [[
/* eli init */
  const char eli_init[] = "{{{embedableInit}}}";
  luaL_dostring(L, eli_init);
/* end eli init */
]]

templates.buildConfigureTemplate = [[
CC="{{{gcc}}}" CXX="{{{gpp}}}" AR="{{{ar}}}" LD="{{{ld}}}" RANLIB="{{{ranlib}}}" cmake {{{rootDir}}} \
-DCMAKE_AR="{{{ar}}}" -DCMAKE_C_COMPILER="{{{gcc}}}" -DCMAKE_CXX_COMPILER="{{{gpp}}}" -DCMAKE_RC_COMPILER="{{{rc}}}" \
-DCMAKE_BUILD_TYPE={{{BUILD_TYPE}}} -DCMAKE_C_FLAGS={{{ccf}}}
]]

return templates