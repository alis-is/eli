## eli - Lua interpreter & essentials 

Contains libs and function necessary for basic server side scripting.

Embedded libraries: 
- [eli](https://github.com/alis-is/eli/tree/main/lib)
- [eli.fs.extra](https://github.com/alis-is/eli-fs-extra)
- [eli.proc.extra](https://github.com/alis-is/eli-proc-extra)
- [eli.env.extra](https://github.com/alis-is/eli-env-extra)
- [eli.os.extra](https://github.com/alis-is/eli-os-extra)
- [eli.pipe.extra](https://github.com/alis-is/eli-pipe-extra)
- [eli.stream.extra](https://github.com/alis-is/eli-stream-extra)
- [eli.extra.utils](https://github.com/alis-is/eli-extra-utils)
- [hjson](https://github.com/hjson/hjson-lua)
- [lustache](https://github.com/Olivine-Labs/lustache)
- [lzip](https://github.com/brimworks/lua-zip) + [libzip](https://github.com/nih-at/libzip) + [zlib](https://github.com/madler/zlib)
- [corehttp](https://github.com/FreeRTOS/coreHTTP)
- [lua-corehttp](https://github.com/alis-is/lua-corehttp)
- [lua-simple-socket](https://github.com/alis-is/lua-simple-socket)
- [lua-simple-ipc](https://github.com/alis-is/lua-simple-ipc)
- [mbedtls](https://github.com/ARMmbed/mbedtls)
- [lua-mbed-base64](https://github.com/alis-is/lua-mbed-base64) + [lua-mbed-bigint](https://github.com/alis-is/lua-mbed-bigint) + [lua-mbed-hash](https://github.com/alis-is/lua-mbed-hash)

Predefined variables:
- `interpreter` - path to interpreter
- `APP_ROOT_SCRIPT` - path to executed script 
- `APP_ROOT` - path to directory containing `APP_ROOT_SCRIPT`
- `ELI_LIB_VERSION` - version of eli library

### Install latest binary release (currently unix only)

`wget -q https://raw.githubusercontent.com/alis-is/eli/main/install.sh -O /tmp/install.sh && sudo sh /tmp/install.sh`

### Build eli

Build requirements:
- docker or podman

Steps:
1. `git clone https://github.com/alis-is/eli && cd eli`
2. `docker build -t elibuild ./containers/build`
3. `docker build -t elitest ./containers/test`
4. `docker run -w "/root/luabuild" -v $(pwd):"/root/luabuild" -v "$(pwd)/toolchains:/opt/cross" -e TOOLCHAINS='zig:x86_64-linux-musl;zig:x86_64-windows-gnu;zig:x86_64-macos-none' -it elibuild`
6. `docker run -w "/root/luabuild" -v $(pwd):"/root/luabuild" -it elitest`
7. Built binaries `eli` and `elic` will be created in release directory

*Note: You can choose build toolchain you like from https://musl.cc/ and set its name in TOOLCHAINS*

Tests:
- Run `run_tests.sh` with args <path to built binary> and <test suite>
    * Example: `./run_tests.sh $(pwd)/build/eli all.lua`

Tools used for build: 

- eli
- [luasrcdiet](https://github.com/jirutka/luasrcdiet) (*for minfication*)
