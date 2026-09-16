## eli - Lua interpreter & essentials 

Contains libs and function necessary for basic server side scripting.

Embedded libraries: 
- [eli](https://github.com/alis-is/eli/tree/main/lib)
- [eli.fs.extra](https://github.com/alis-is/eli-fs-extra)
- [eli.proc.extra](https://github.com/alis-is/eli-proc-extra)
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
2. `docker build -f ./containers/build/Containerfile -t elibuild ./containers/build`
3. `docker build -f ./containers/test/Containerfile -t elitest ./containers/test`
4. `docker run -w "/root/luabuild" -v $(pwd):"/root/luabuild":Z -v "$(pwd)/toolchains:/opt/cross" -e TOOLCHAINS='zig:x86_64-linux-musl;zig:x86_64-windows-gnu;zig:x86_64-macos-none' -it elibuild`
6. `docker run -w "/root/luabuild" -v $(pwd):"/root/luabuild":Z -it elitest`
7. Built binaries `eli` and `elic` will be created in release directory

*Note: You can choose build toolchain you like from https://musl.cc/ and set its name in TOOLCHAINS*

Tests:
- Run `./tools/test.sh [platform]` on Linux/macOS or `./tools/test.ps1 [platform]` on Windows
    * Example: `./tools/test.sh x86_64`

Native worker regressions: configure with `-DELI_BUILD_TESTS=ON`, build, then run
`ctest --test-dir build -R eli_worker_constructor --output-on-failure`.

Tools used for build: 

- eli
- [luasrcdiet](https://github.com/jirutka/luasrcdiet) (*for minfication*)

### Workers and thread safety

`eli.worker` runs each worker on a native thread with its own Lua state. Bundled
native modules synchronize the process-wide state they share (environment
variables, signals, TLS/PSA, socket initialization, subprocess helpers);
environment variables and the working directory are shared between states while
Lua globals and loaded modules are not.

Cross-state Lua code can coordinate through `worker.mutex()` locks. The native
lock is shared through spawn arguments, channel messages, and worker results,
but each state gets its own box: an acquisition never transfers, a box can only
be unlocked by the thread that acquired through it, and `try_lock()` never
blocks. A box releases its acquisition at scope exit when to-be-closed
(`local lock <close> = m; lock:lock(); ...`, including on error), when the
worker state exits, and if the handle is collected while held (keep it
referenced for as long as the lock is needed). A worker that dies while holding
a lock therefore never strands it.

Third-party native extensions are **not** automatically thread-safe just because
Lua states are independent. Any extension that touches process-global state
(environment, cwd, signals, shared file descriptors, libc helpers such as
`getenv`/`setlocale`) must provide the same synchronization or restrict the
operation to the main state. Statics and globals in a native module are shared by
every worker state in the process.

Workers block asynchronous signals so their handlers run only in the main state.
Child processes created with `proc.spawn` reset that mask in the child and handle
termination signals normally. `os.execute` and `io.popen` synchronize environment
inheritance, but their children inherit the worker's blocked mask; use `proc.spawn`
for subprocesses that must respond to signals such as `SIGTERM`.
