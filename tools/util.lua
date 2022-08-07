
---comment
---@param data string
---@return string
local function _compress_string_to_c_bytes(data)
	local _byteArray = table.map(
		table.filter(table.pack(string.byte(lz.compress_string(data), 1, -1)),
		   function(k)
			  return type(k) == "number"
		   end
		),
		function(b)
		   return string.format("0x%02x", b)
		end
	 )
	 return string.join(",", _byteArray)
end

return {
	compress_string_to_c_bytes = _compress_string_to_c_bytes
}