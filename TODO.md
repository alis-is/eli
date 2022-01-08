# Additional Extra docs & External docs (non essential)
[ ] extra.proc
[ ] extra.stream
[ ] extra.pipe
[ ] extra.fs - filetype
[ ] lzip - ZipArchive

# Eli
* [x] logs 
* [x] support for init scripts
* [x] create independent stream and pipe library
* [x] rewrite eli.proc.extra to provide more consistent eliProc
* [ ] debug build
* [ ] smaller eli.path with smaller feature support, but with support for basic URL manipulation
* [ ] eli.fs.extra check whether file is locked

# Build 
* [x] toolchain configurable
* [x] replace curl with libfetch (requires testing)
* [x] mount and use toolchain dir during build (toolchain caching)
* [ ] optional use of cache during build
* [ ] windows build

## CMakeLists 
* [ ] optional build Eli mini - without eli.net and libcurl related libs 

# Init scripts:
* [x] initialize ELI_LIB_VERSION, INTERPRETER, APP_ROOT_SCRIPT, APP_ROOT