podman run -v $(pwd):"/root/luabuild" -v "$(pwd)/opt_cross:/opt/cross" -e TOOLCHAINS='x86_64-linux-musl-cross' elibuild
./run_tests.sh $(pwd)/build/eli proc.lua
