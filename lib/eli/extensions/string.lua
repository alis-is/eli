local es = {}

---#DES string.trim
---
---@param s string
---@return string
function es.trim(s)
	if type(s) ~= "string" then return s end
	return s:match"^()%s*$" and "" or s:match"^%s*(.*%S)"
end

---#DES string.split
---
---@param s string
---@param sep string?
---@param trim boolean?
---@return string[]
function es.split(s, sep, trim)
	if type(s) ~= "string" then return s end
	if sep == nil then
		sep = "%s"
	end
	local _result = {}
	for str in string.gmatch(s, "([^" .. sep .. "]+)") do
		if trim then
			str = _trim(str)
		end
		table.insert(_result, str)
	end
	return _result
end

---#DES string.join
---
---@overload fun(separator: string, data: any[]): string
---@param separator string
---@param ... any
---@return string
function es.join(separator, ...)
	local _result = ""
	if type(separator) ~= "string" then
		separator = ""
	end
	local _parts = table.pack(...)
	if #_parts > 0 and type(_parts[1]) == "table" then
		_parts = _parts[1]
	end

	for _, v in ipairs(_parts) do
		if #_result == 0 then
			_result = tostring(v)
		else
			_result = _result .. separator .. tostring(v)
		end
	end
	return _result
end

---#DES string.join_strings
---
---joins only strings, ignoring other values
---@overload fun(separator: string, data: string[]): string
---@param separator string
---@param ...string
---@return string
function es.join_strings(separator, ...)
	local _tmp = {}
	local _parts = table.pack(...)
	if #_parts > 0 and type(_parts[1]) == "table" then
		_parts = _parts[1]
	end
	for _, v in ipairs(_parts) do
		if type(v) == "string" then
			table.insert(_tmp, v)
		end
	end
	return _join(separator, table.unpack(_tmp))
end

---#DES string.interpolate
---
---Interpolates string with data from table. If table is not provided uses _G as source for interpolation.
---WARNING: _G does not contain local variables or upvalues in such scenario provide them through data parameter as table.
---@param format string
---@param data table?
---@return string
function es.interpolate(format, data)
	if data == nil then data = _G end
	if type(data) ~= "table" then data = {} end
	---@param w string
	---@return string
	local function _interpolater(w)
		if w:sub(1, 1) == "\\" then
			return w:sub(2)
		end
		local _v = data[w:sub(3, -2)]
		if _v == nil then _v = "" end
		return tostring(_v) or w
	end
	local _result = format:gsub("(\\?$%b{})", _interpolater)
	return _result
end

function es.globalize()
	string.split = es.split
	string.join = es.join
	string.join_strings = es.join_strings
	string.trim = es.trim
	string.interpolate = es.interpolate
end

return es
