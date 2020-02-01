# Eli
* [x] logs 
* [x] support for init scripts
* [ ] debug build
* [ ] smaller eli.path with smaller feature support, but with support for basic URL manipulation
* [ ] eli.fs.extra check whether file is locked

# Build 
* [x] toolchain configurable
* [ ] optional use of cache during build
* [ ] replace curl with libfetch (requires testing)

## CMakeLists 
* [ ] optional build Eli mini - without eli.net and curl related libs 

# Init scripts:
* [x] initialize ELI_LIB_VERSION, INTERPRETER, APP_ROOT_SCRIPT, APP_ROOT

# posix & windows specific functions
* [x] in eli.extra
* [ ] check for file lock

*NOTICE: wont be included on exotic platforms*