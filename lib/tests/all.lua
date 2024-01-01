TEST = require"u-test"
local _test = TEST
require"t_hjson"
require"t_bigint"
require"t_base64"
require"hash"
require"net"
require"net.url"
require"fs"
require"proc"
require"env"
require"zip"
require"tar"
require"lz"
require"util"
require"ver"
require"elios"
require"global"
require"signal"
require"ipc"

require"extensions.string"
require"extensions.table"

require"internals.util"

--[[
    NOTE:
    elify tests has to be run at last
    (elify modifies global env while other tests should be run in standard environment)
]]
require"elify"

local _ntests, _nfailed = _test.result()
_test.summary()
