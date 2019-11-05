## eli - Lua interpreter & essentials 

Contains libs and function necessary for basic server side scripting.

Embedded libraries: 
- [eli](https://github.com/cryon-io/eli-lib)
- [hjson ](https://github.com/cryi/hjson-lua)
- [lustache](https://github.com/Olivine-Labs/lustache)
- [argparse](https://github.com/mpeterv/argparse)
- [curl](https://github.com/curl/curl) + [lcurl](https://github.com/Lua-cURL/Lua-cURLv3)
- [libzip](https://github.com/nih-at/libzip) + [lzip](https://github.com/brimworks/lua-zip)
- [mbedtls](https://github.com/ARMmbed/mbedtls) and [zlib](https://github.com/madler/zlib) (*for curl*)

Predefined variables:
- `interpreter` - path to interpreter
- `appRootScript` - path to executed script 
- `appRoot` - path to directory containing `appRootScript`

### Build eli

Requirements:
- docker

Steps:
1. `git clone https://github.com/cryon-io/eli && cd eli`
2. `docker build -t elibuild .`
3. `chmod +x eli`
4. `docker run -v $(pwd):"/root/luabuild" -e TOOLCHAINS='x86_64-linux-musl-cross;i686-linux-musl-cross' elibuild`
5. Built binaries `eli` and `elic` will be created in build directory and per `<toolchain>` subdirectories

*Note: You can choose build toolchain you like from https://musl.cc/ and set its name in TOOLCHAINS*

Libraries used for build: 

- eli v0.1.0 with all embedded libraries
- [luasrcdiet](https://github.com/jirutka/luasrcdiet) (*for minfication*)