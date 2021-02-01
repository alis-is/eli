## eli - Lua interpreter & essentials 

Contains libs and function necessary for basic server side scripting.

Embedded libraries: 
- [eli](https://github.com/cryon-io/eli/tree/master/lib)
- [eli.fs.extra](https://github.com/cryon-io/eli-fs-extra)
- [eli.proc.extra](https://github.com/cryon-io/eli-proc-extra)
- [eli.env.extra](https://github.com/cryon-io/eli-env-extra)
- [eli.os.extra](https://github.com/cryon-io/eli-os-extra)
- [eli.pipe.extra](https://github.com/cryon-io/eli-pipe-extra)
- [eli.stream.extra](https://github.com/cryon-io/eli-stream-extra)
- [eli.extra.utils](https://github.com/cryon-io/eli-extra-utils)
- [hjson ](https://github.com/cryi/hjson-lua)
- [lustache](https://github.com/Olivine-Labs/lustache)
- [lua-cURLv3](https://github.com/Lua-cURL/Lua-cURLv3)
- [lzip](https://github.com/brimworks/lua-zip) + [libzip](https://github.com/nih-at/libzip) + [zlib](https://github.com/madler/zlib)
- [mbedtls](https://github.com/ARMmbed/mbedtls)

Predefined variables:
- `interpreter` - path to interpreter
- `APP_ROOT_SCRIPT` - path to executed script 
- `APP_ROOT` - path to directory containing `APP_ROOT_SCRIPT`
- `ELI_LIB_VERSION` - version of eli library

### Install latest binary release (currently unix only)

`wget https://raw.githubusercontent.com/cryon-io/eli/master/install.sh -O /tmp/install.sh && sh /tmp/install.sh`

### Build eli

Build requirements:
- docker or podman

Steps:
1. `git clone https://github.com/cryon-io/eli && cd eli`
2. `docker build -t elibuild .`
3. `docker run -v $(pwd):"/root/luabuild" -v "$(pwd)/toolchains:/opt/cross" -e TOOLCHAINS='x86_64-linux-musl-cross;i686-linux-musl-cross' elibuild`
4. Built binaries `eli` and `elic` will be created in build directory and per `<toolchain>` subdirectories

*Note: You can choose build toolchain you like from https://musl.cc/ and set its name in TOOLCHAINS*

Tests:
- Run `run_tests.sh` with args <path to built binary> and <test suite>
    * Example: `./run_tests.sh $(pwd)/build/eli all.lua`

Libraries used for build: 

- eli v0.1.0 with all embedded libraries
- [luasrcdiet](https://github.com/jirutka/luasrcdiet) (*for minfication*)
