#ifndef ELI_CONF_H__
#define ELI_CONF_H__

#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>

#define LUA_TMPNAMTEMPLATE "eli"
#define LUA_TMPNAMBUFSIZE (MAX_PATH + 1)
#define lua_tmpnam(b, e)                                                      \
	{                                                                     \
		char buff[MAX_PATH];                                          \
		e = GetTempPathA(MAX_PATH, buff);                             \
		if (e > 0) {                                                  \
			e = GetTempFileNameA(buff, LUA_TMPNAMTEMPLATE, 0, b); \
		}                                                             \
		e = (e == 0);                                                 \
	}
#elif defined(LUA_USE_POSIX)
#define LUA_TMPNAMTEMPLATE "/tmp/eli_XXXXXX"
#endif

#endif