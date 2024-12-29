local string_extensions = {}

---#DES string.trim
---
---@param s string
---@return string
function string_extensions.trim(s)
	if type(s) ~= "string" then return s end
	return s:match"^()%s*$" and "" or s:match"^%s*(.*%S)"
end

---#DES string.split
---
---@param s string
---@param separator string?
---@param trim boolean?
---@return string[]
function string_extensions.split(s, separator, trim)
	if type(s) ~= "string" then return s end
	if separator == nil then
		separator = "%s"
	end
	local result = {}
	for str in string.gmatch(s, "([^" .. separator .. "]+)") do
		if trim then
			str = string_extensions.trim(str)
		end
		table.insert(result, str)
	end
	return result
end

---#DES string.join
---
---@overload fun(separator: string, data: any[]): string
---@param separator string
---@param ... any
---@return string
function string_extensions.join(separator, ...)
	local result = ""
	if type(separator) ~= "string" then
		separator = ""
	end
	local parts = table.pack(...)
	if #parts > 0 and type(parts[1]) == "table" then
		parts = parts[1]
	end

	for _, v in ipairs(parts) do
		if #result == 0 then
			result = tostring(v)
		else
			result = result .. separator .. tostring(v)
		end
	end
	return result
end

---#DES string.join_strings
---
---joins only strings, ignoring other values
---@overload fun(separator: string, data: string[]): string
---@param separator string
---@param ...string
---@return string
function string_extensions.join_strings(separator, ...)
	local strings = {}
	local parts = table.pack(...)
	if #parts > 0 and type(parts[1]) == "table" then
		-- if passed as table use it as parts
		parts = parts[1]
	end
	for _, v in ipairs(parts) do
		if type(v) == "string" then
			table.insert(strings, v)
		end
	end
	return string_extensions.join(separator, table.unpack(strings))
end

---#DES string.interpolate
---
---Interpolates string with data from table. If table is not provided uses _G as source for interpolation.
---WARNING: _G does not contain local variables or upvalues in such scenario provide them through data parameter as table.
---@param format string
---@param data table?
---@return string
---@return number
function string_extensions.interpolate(format, data)
	if data == nil then data = _G end
	if type(data) ~= "table" then data = {} end

	local count_of_replaces = 0

	---@param w string
	---@return string
	local function interpolater(w)
		if w:sub(1, 1) == "\\" then -- remove escape characters
			return w:sub(2)
		end
		local value = data[w:sub(3, -2)]
		if value == nil then value = "" end
		count_of_replaces = count_of_replaces + 1
		return tostring(value) or w
	end
	local result = format:gsub("(\\?$%b{})", interpolater)
	return result, count_of_replaces
end

function string_extensions.globalize()
	string.split = string_extensions.split
	string.join = string_extensions.join
	string.join_strings = string_extensions.join_strings
	string.trim = string_extensions.trim
	string.interpolate = string_extensions.interpolate
end

return string_extensions
