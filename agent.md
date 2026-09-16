# Development and builds with Podman

Run host commands below from the repository root. Use the checked-in container
definitions and build scripts as the source of truth. The examples target an
x86_64 Linux host; the build image currently downloads x86_64 Zig 0.15.2.

## Working on the project

- Lua APIs live in `lib/eli/`, startup code in `lib/init.lua`, and Lua tests in
  `lib/tests/`. Native modules live in Git submodules under `deps/`.
- `config.hjson` defines the version, native module names, embedded Lua modules,
  and certificate injection. Add new native module registrations there.
- `tools/build.lua` first runs `tools/patches/deps.lua`: it copies
  `misc/deps-overlay/` into dependencies, patches Lua, and embeds the Lua library.
  Change overlays or patch templates when changing generated dependency code;
  editing only the generated copy will be overwritten on the next build.
- Run the full build script after changing Lua sources, startup code, config,
  overlays, or patch templates. A CMake-only rebuild does not regenerate the
  embedded Lua library. Native C-only edits can use the incremental build below.
- Inspect submodules explicitly: many have `ignore = dirty` in `.gitmodules`, so
  the top-level status does not show all dependency edits. Preserve existing work.

```sh
git status --short
git submodule foreach --recursive 'git status --short'
```

On a fresh checkout, initialize the pinned dependencies before building. Do not
use `--remote` to update dependency versions as part of a routine build.

```sh
git submodule update --init --recursive
```

## Build the images

Podman and network access are required. The build image installs a bootstrap
`eli` and Zig; the test image installs QEMU and `go-httpbin`.

```sh
podman build -f containers/build/Containerfile -t localhost/elibuild containers/build
podman build -f containers/test/Containerfile -t localhost/elitest containers/test
```

The commands mount the checkout at `/root/luabuild`, matching CI. `:Z` supplies
the SELinux label for this bind mount. Use the same container path consistently:
CMake caches absolute source and compiler paths. Do not reuse a host-configured
build directory inside the container. Use `--clean` if its cached paths differ;
this removes the selected build directory and rebuilds it.

## Build Linux for development

```sh
podman run --rm \
  -w /root/luabuild -v "$PWD:/root/luabuild:Z" \
  -e TOOLCHAINS='zig:x86_64-linux-musl;' \
  localhost/elibuild
```

The image entrypoint is `eli tools/build.lua`; append build-script flags directly
after the image name. For a debug build, append `--debug`. For a clean debug
build, append `--clean --debug`.

Keep the trailing semicolon in the single-target example: it selects the build
script's per-target directory mode. Without a semicolon, a single target uses
`build/` instead of `build/x86_64-linux-musl/`.

Outputs for this example:

- Working executable: `build/x86_64-linux-musl/eli`.
- Release copy: `release/eli-linux-x86_64`.
- Debug release copy, when requested: `release/eli-linux-x86_64-debug`.
- The build script also attempts to generate `.meta/` and `release/meta.zip`
  using the host-architecture Linux release executable.

The build script stops when CMake or make fails. Verify the actual build output
and run the executable before relying on a release artifact.

## Cross-build

```sh
podman run --rm \
  -w /root/luabuild -v "$PWD:/root/luabuild:Z" \
  -e TOOLCHAINS='zig:x86_64-linux-musl;zig:x86_64-windows-gnu;zig:x86_64-macos-none;zig:aarch64-macos-none' \
  localhost/elibuild
```

Each target gets its own directory under `build/` and a named binary under
`release/` (`eli-windows-x86_64.exe`, `eli-macos-x86_64`, etc.). Zig targets do
not need the optional `toolchains:/opt/cross` mount used by GCC cross-toolchains.
Cross-compilation success does not establish that platform's runtime tests pass.
Avoid simultaneous full builds against the same checkout: dependency patching
and generated sources are shared across targets.

## Incremental native builds and native tests

After a full container build has generated the dependencies, override the image
entrypoint to use a shell. This rebuilds C sources and enables the native tests:

```sh
podman run --rm \
  -w /root/luabuild -v "$PWD:/root/luabuild:Z" \
  --entrypoint /bin/sh localhost/elibuild -ec '
    cmake -S . -B build/x86_64-linux-musl -DELI_BUILD_TESTS=ON
    cmake --build build/x86_64-linux-musl --target eli eli_worker_constructor_test eli_proc_user_lookup_test -j2
    ctest --test-dir build/x86_64-linux-musl -R "eli_worker_constructor|eli_proc_user_lookup" --output-on-failure
  '
```

This updates the working executable, not the copy under `release/`. Use the
working executable for targeted checks, or rerun the full build script before
testing release artifacts. Native user-lookup tests are Unix-only.

## Lua tests

Run targeted suites from `lib/tests/` so their relative imports and fixtures
resolve. Use the freshly built executable, not the image's bootstrap `eli`:

```sh
podman run --rm \
  -w /root/luabuild/lib/tests -v "$PWD:/root/luabuild:Z" \
  --entrypoint /bin/sh localhost/elibuild -ec '
    for suite in worker.lua worker_teardown.lua proc.lua signal.lua; do
      timeout 120 ../../build/x86_64-linux-musl/eli "$suite"
    done
  '
```

For the full Linux suite, first refresh the release binary with the full build
script, then run the test image. Its entrypoint is `tools/test.sh`:

```sh
podman run --rm \
  -w /root/luabuild -v "$PWD:/root/luabuild:Z" \
  localhost/elitest x86_64
```

Pass the architecture explicitly. With no argument the runner attempts x86_64,
i686, and aarch64, requiring their release binaries. It starts `go-httpbin` on
container loopback port 8081, writes `httpbin.log` in the checkout, and runs
`all.lua` with a 900-second watchdog. No host port publishing is needed.
Inspect `httpbin.log` if service startup fails. Container removal cleans up the
test service. Linux containers do not execute the macOS or Windows suites.

## Before handing off changes

- Run focused tests for the behavior changed; include worker/process tests when
  modifying native shared state or subprocess handling.
- Check `git diff --check` in the root and each changed submodule. Review both
  handwritten changes and generated dependency differences.
- Keep build outputs, caches, and `httpbin.log` out of source commits. Do not
  discard unrelated edits or reset dirty submodules to clean up a build.
- Report which target was built, which tests ran, and any untested platforms.
