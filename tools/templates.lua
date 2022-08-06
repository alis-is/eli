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
{{#compress}}
  char uncompressedLibs[{{{embedableLibsLength}}}];
  z_stream i_stream;
  i_stream.zalloc = Z_NULL;
  i_stream.zfree = Z_NULL;
  i_stream.opaque = Z_NULL;
  
  i_stream.avail_in = (uInt)sizeof(lua_libs);           // size of input
  i_stream.next_in = (Bytef *)lua_libs;                 // input char array
  i_stream.avail_out = (uInt)sizeof(uncompressedLibs);  // size of output
  i_stream.next_out = (Bytef *)uncompressedLibs;        // output char array

  inflateInit(&i_stream);
  inflate(&i_stream, Z_NO_FLUSH);
  inflateEnd(&i_stream);
  
  uncompressedLibs[{{{embedableLibsLength}}} - 1] = '\0';
  
  luaL_loadstring(L, uncompressedLibs);
{{/compress}}
{{^compress}}
  luaL_loadstring(L, lua_libs);
{{/compress}}
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

#include "zlib.h"
{{#compress}}
const char lua_libs[] = { {{{embedableLibs}}} };
{{/compress}}
{{^compress}}
const char lua_libs[] = "{{{embedableLibs}}}";
{{/compress}}
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
-DCMAKE_BUILD_TYPE={{{BUILD_TYPE}}} -DCMAKE_C_FLAGS={{{ccf}}} -DCURL_HOST={{{ch}}}
]]

templates.curlMbedTlSCertsLoader = [[mbedtls_x509_crt_init(&backend->cacert);
/* CA Certificates */
{{#compress}}
const char eli_cacert[] = { {{{certs}}} };
char uncompressedCerts[{{{certsLength}}}];

#include "zlib.h"
z_stream i_stream;
i_stream.zalloc = Z_NULL;
i_stream.zfree = Z_NULL;
i_stream.opaque = Z_NULL;

i_stream.avail_in = (uInt)sizeof(eli_cacert);           // size of input
i_stream.next_in = (Bytef *)eli_cacert;                 // input char array
i_stream.avail_out = (uInt)sizeof(uncompressedCerts);  // size of output
i_stream.next_out = (Bytef *)uncompressedCerts;        // output char array

inflateInit(&i_stream);
inflate(&i_stream, Z_NO_FLUSH);
inflateEnd(&i_stream);

ret = mbedtls_x509_crt_parse(&backend->cacert, eli_cacert, sizeof(uncompressedCerts));
{{/compress}}
{{^compress}}
const char eli_cacert[] = "{{{certs}}}";
ret = mbedtls_x509_crt_parse(&backend->cacert, eli_cacert, sizeof(eli_cacert));
{{/compress}}
if (ret) {
#ifdef MBEDTLS_ERROR_C
mbedtls_strerror(ret, errorbuf, sizeof(errorbuf));
#endif /* MBEDTLS_ERROR_C */
failf(data, "Error reading ca cert file - mbedTLS: (-0x%%04X) %%s", -ret, errorbuf);
if(verifypeer)
return CURLE_SSL_CERTPROBLEM;
}
if(ssl_cafile && false)]]

return templates