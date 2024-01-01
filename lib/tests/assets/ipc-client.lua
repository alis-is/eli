local ipc = require"eli.ipc"

local client, err = ipc.connect"/tmp/test.sock"
client:write"ping"
