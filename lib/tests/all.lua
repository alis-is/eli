TEST = require 'u-test'
local _test = TEST
require"hash"
require"net"
require"fs"
require"proc"
require"env"
require"zip"
require"tar"
require"lz-tests"
require"util"
require"ver"
require"elios"

require"extensions.string"
require"extensions.table"

--[[
    NOTE:
    elify tests has to be run at last
    (elify modifies global env while other tests should be run in standard environment)
]]
require"elify"

local _ntests, _nfailed = _test.result()
_test.summary()