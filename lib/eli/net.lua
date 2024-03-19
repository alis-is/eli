--- #META_HINT keep-file
--- #META_RETURNS net

local util = require"eli.util"
local http = require"eli.net.http"

return util.merge_tables(http, {
	http = http,
	url = require"eli.net.url",
})
