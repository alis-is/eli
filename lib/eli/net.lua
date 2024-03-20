--- META_INJECT
---
--- net = util.merge_tables(net.http, {
--- 	http = net.http,
--- 	url = require"eli.net.url",
--- })

local util = require"eli.util"
local http = require"eli.net.http"

return util.merge_tables(http, {
	http = http,
	url = require"eli.net.url",
})
