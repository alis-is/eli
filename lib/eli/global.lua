local string_extensions = require"eli.extensions.string"
local table_extensions = require"eli.extensions.table"

local global = {}

---#DES 'printf'
---
---Prints string with interpolation in C printf way in case of string varargs
---interpolating with table varargs if any ${varName} applicable
---@param format string
---@param ... any
---@deprecated use string.interpolate
function global.printf(format, ...)
	local args = table.pack(...)
	local interpolation_data = {}
	local to_remove = {}

	for i = 1, args.n do
		local v = args[i]
		if type(v) == "table" and not table_extensions.is_array(v) then
			for k, val in pairs(v) do
				interpolation_data[k] = val
			end
			table.insert(to_remove, i)
		end
	end
	for i = #to_remove, 1, -1 do
		table.remove(args, to_remove[i])
		args.n = args.n - 1
	end

	if next(interpolation_data) then
		format = string_extensions.interpolate(format, interpolation_data)
	end
	return io.write(string.format(format, table.unpack(args, 1, args.n)))
end

return global
