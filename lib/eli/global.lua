local string_extensions = require"eli.extensions.string"
local table_extensions = require"eli.extensions.table"

local global = {}

---#DES 'printf'
---
---Prints string with interpolation in C printf way in case of string varargs
---interpolating with table varargs if any ${varName} applicable
---@param format string
---@param ... any
function global.printf(format, ...)
	local args = table.pack(...)
	for i, v in ipairs(args) do
		if type(v) == "table" and not table_extensions.is_array(args[1]) then
			-- interpolate
			local interpolation_table = table.remove(args, i)
			format = string_extensions.interpolate(format, interpolation_table)
		end
	end
	return io.write(string.format(format, ...))
end

return global
