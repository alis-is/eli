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

`wget -q https://raw.githubusercontent.com/alis-is/eli/master/install.sh -O /tmp/install.sh && sudo sh /tmp/install.sh`

### Build eli

Build requirements:
- docker or podman

Steps:
1. `git clone https://github.com/alis-is/eli && cd eli`
2. `docker build -t elibuild ./tools/containers/build`
3. `docker build -t elitest ./tools/containers/test`
4. `docker run -w "/root/luabuild" -v $(pwd):"/root/luabuild" -v "$(pwd)/toolchains:/opt/cross" -e TOOLCHAINS='x86_64-linux-musl-cross;i686-linux-musl-cross;aarch64-linux-musl-cross' -it elibuild`
6. `docker run -w "/root/luabuild" -v $(pwd):"/root/luabuild" -it elitest`
7. Built binaries `eli` and `elic` will be created in release directory

*Note: You can choose build toolchain you like from https://musl.cc/ and set its name in TOOLCHAINS*

Tests:
- Run `run_tests.sh` with args <path to built binary> and <test suite>
    * Example: `./run_tests.sh $(pwd)/build/eli all.lua`

Libraries used for build: 

- eli 0.23.2
- [luasrcdiet](https://github.com/jirutka/luasrcdiet) (*for minfication*)
