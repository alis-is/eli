local build = require"tools.util"
local destination = assert(arg[1], "usage: tools/download-ca-certs.lua <destination>")
local ok, err = build.download_ca_bundle(destination)

assert(ok, err)
