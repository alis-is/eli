local util = require"eli.util"
local http = require"eli.net.http"

return util.merge_tables(http, {
	url = require"eli.net.url",
})
