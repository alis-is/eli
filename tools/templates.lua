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
  char uncompressedLibs[{{{embedableLibsLength}}} + 1];
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
  
  uncompressedLibs[{{{embedableLibsLength}}}] = '\0';
  
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
-DCMAKE_AS="{{{as}}}" -DCMAKE_OBJDUMP="{{{objdump}}}" -DCMAKE_STRIP="{{{strip}}}" \
-DCMAKE_BUILD_TYPE={{{BUILD_TYPE}}} -DCMAKE_C_FLAGS={{{ccf}}} -DCURL_HOST={{{ch}}}
]]

templates.curlMbedTlsCertsLoader = [[mbedtls_x509_crt_init(&backend->cacert);
/* CA Certificates */
const char eli_cacerts[] = { {{{certs}}} };
const long unsigned int eli_cacertSizes[] = { {{{certSizes}}} };

long unsigned int shift = 0;
for (int i = 0; i < {{{certsCount}}}; i++) {
  ret = mbedtls_x509_crt_parse_der_nocopy(&backend->cacert, eli_cacerts + shift, eli_cacertSizes[i]);
  if (ret) {
    #ifdef MBEDTLS_ERROR_C
    mbedtls_strerror(ret, errorbuf, sizeof(errorbuf));
    #endif /* MBEDTLS_ERROR_C */
    failf(data, "Error reading ca cert file - mbedTLS: (-0x%%04X) %%s", -ret, errorbuf);
    if(verifypeer)
    return CURLE_SSL_CERTPROBLEM;
  }
  shift += eli_cacertSizes[i];
}
if(ssl_cafile && false)]]

templates.mbetTlsOverride = [[
/* eli mbedtls overrides */
{{#overrides}}
{{{.}}}
{{/overrides}}
{{^overrides}}
#undef MBEDTLS_ERROR_STRERROR_DUMMY
#undef MBEDTLS_VERSION_FEATURES
#undef MBEDTLS_X509_CSR_WRITE_C
#undef MBEDTLS_X509_CSR_READ_C
#undef MBEDTLS_X509_CSR_PARSE_C
#undef MBEDTLS_X509_CRL_WRITE_C
#undef MBEDTLS_X509_CRL_READ_C
#undef MBEDTLS_X509_CRL_PARSE_C
#undef MBEDTLS_DEBUG_C
#undef MBEDTLS_SSL_SRV_C
#undef MBEDTLS_X509_CREATE_C
#undef MBEDTLS_PEM_PARSE_C
#undef MBEDTLS_PEM_WRITE_C
#undef MBEDTLS_BASE64_C
#undef MBEDTLS_X509_CRT_WRITE_C
{{/overrides}}
/* end eli mbedtls overrides */
]]

return templates