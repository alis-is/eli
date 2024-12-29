local is_os_extra_loaded, os_extra = pcall(require, "eli.os.extra")
local util = require"eli.util"

local os = {
    ---#DES os.EOS
    ---
    ---@type boolean
    EOS = is_os_extra_loaded,
}

return is_os_extra_loaded and util.merge_tables(os, os_extra) or os
