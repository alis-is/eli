-- Small, lexical path helpers. They do not touch the filesystem.

local path = {}

path.platform = package.config:sub(1, 1) == "\\" and "win" or "unix"

local function is_windows(platform)
	return (platform or path.platform) == "win"
end

local function separator(platform)
	return is_windows(platform) and "\\" or "/"
end

local function separator_pattern(platform)
	return is_windows(platform) and "[\\/]" or "/"
end

local function detect_separator(value, platform)
	if not is_windows(platform) then return "/" end
	local slash = value:find("/", 1, true)
	local backslash = value:find("\\", 1, true)
	if slash and not backslash then return "/" end
	if backslash and not slash then return "\\" end
end

---#DES 'path.default_sep'
---@param platform 'unix'|'win'?
---@return string
function path.default_sep(platform)
	return separator(platform)
end

local device_aliases = {
	CON = true, PRN = true, AUX = true, NUL = true,
	COM1 = true, COM2 = true, COM3 = true, COM4 = true, COM5 = true,
	COM6 = true, COM7 = true, COM8 = true, COM9 = true,
	LPT1 = true, LPT2 = true, LPT3 = true, LPT4 = true, LPT5 = true,
	LPT6 = true, LPT7 = true, LPT8 = true, LPT9 = true,
}

---#DES 'path.dev_alias'
---@param value string
---@return string?
function path.dev_alias(value)
	local name = value:match("[^\\/]+$")
	name = name and name:match("^[^%.]+")
	name = name and name:upper()
	return name and device_aliases[name] and name or nil
end

---#DES 'path.type'
---@param value string
---@param platform 'unix'|'win'?
---@return string
function path.type(value, platform)
	if not is_windows(platform) then return value:sub(1, 1) == "/" and "abs" or "rel" end
	if value:match("^\\\\%?\\[A-Za-z]:\\") then return "abs_long" end
	if value:match("^\\\\%?\\[Uu][Nn][Cc]\\") then return "unc_long" end
	if value:match("^\\\\%?\\") then return "global" end
	if value:match("^\\\\%.\\") then return "dev" end
	if value:match("^\\\\") then return "unc" end
	if path.dev_alias(value) then return "dev_alias" end
	if value:match("^[A-Za-z]:") then
		return value:match("^[A-Za-z]:[\\/]") and "abs" or "rel_drive"
	end
	return value:match("^[\\/]") and "abs_nodrive" or "rel"
end

---#DES 'path.isabs'
---@param value string
---@param platform 'unix'|'win'?
---@return boolean
function path.isabs(value, platform)
	if not is_windows(platform) then return value:sub(1, 1) == "/" end
	return value:match("^[A-Za-z]:[\\/]") ~= nil
		or value:match("^[\\/][\\/]") ~= nil
		or value:match("^[\\/]") ~= nil
end

---#DES 'path.endsep'
---@param value string
---@param platform 'unix'|'win'?
---@param ending boolean|string?
---@param default_sep string?
---@return string, boolean?
function path.endsep(value, platform, ending, default_sep)
	local pattern = separator_pattern(platform)
	if ending == nil then return value:match(pattern .. "+$") end
	if value == "" then return value, false end
	if ending == false or ending == "" then
		local result = value:gsub(pattern .. "+$", "")
		return result == "" and value or result, true
	end
	if value:match(pattern .. "$") then return value, true end
	local sep = ending == true and (detect_separator(value, platform) or default_sep or separator(platform)) or ending
	return value .. sep, true
end

---#DES 'path.sep'
---@param value string
---@param platform 'unix'|'win'?
---@param output_sep boolean|string?
---@param default_sep string?
---@param empty_names boolean?
---@return string
function path.sep(value, platform, output_sep, default_sep, empty_names)
	if output_sep == nil and empty_names == nil then return detect_separator(value, platform) end
	local sep = output_sep
	if sep == true then
		sep = default_sep or separator(platform)
	elseif sep == false then
		sep = detect_separator(value, platform) or default_sep or separator(platform)
	elseif sep == nil then
		sep = "%1"
	end
	assert(sep == "/" or sep == "\\" or sep == "%1", "invalid separator")
	return value:gsub(empty_names and separator_pattern(platform) or separator_pattern(platform) .. "+", sep)
end

---#DES 'path.file'
---@param value string
---@param platform 'unix'|'win'?
---@return string
function path.file(value, platform)
	return value:match(is_windows(platform) and "[^\\/]*$" or "[^/]*$")
end

---#DES 'path.nameext'
---@param value string
---@param platform 'unix'|'win'?
---@return string, string?
function path.nameext(value, platform)
	local file = path.file(value, platform)
	local name, ext = file:match("^(.-)%.([^%.]*)$")
	if not name or name == "" then return file, nil end
	return name, ext
end

---#DES 'path.ext'
---@param value string
---@param platform 'unix'|'win'?
---@return string?
function path.ext(value, platform)
	return select(2, path.nameext(value, platform))
end

---#DES 'path.dir'
---@param value string
---@param platform 'unix'|'win'?
---@return string?
function path.dir(value, platform)
	if value == "" or value == "." then return nil end
	local sep = separator_pattern(platform)
	if value:match("^" .. sep .. "+$")
		or (is_windows(platform) and value:match("^[A-Za-z]:" .. sep .. "*$")) then
		return nil
	end

	local index = value:match(".*()" .. sep)
	if not index then return "." end
	local parent = value:sub(1, index - 1)
	if parent == "" then return value:sub(index, index) end
	if is_windows(platform) and parent:match("^[A-Za-z]:$") then
		return parent .. value:sub(index, index)
	end
	return parent
end

---#DES 'path.combine'
---@param first string
---@param second string
---@param platform 'unix'|'win'?
---@param sep string?
---@param default_sep string?
---@return string?, string?
function path.combine(first, second, platform, sep, default_sep)
	if second == "" then return first end
	if first == "" then return second end

	local first_abs = path.isabs(first, platform)
	local second_abs = path.isabs(second, platform)
	if first_abs and second_abs then
		return nil, "cannot combine two absolute paths"
	elseif second_abs then
		first, second = second, first
	end

	sep = sep or detect_separator(first, platform) or detect_separator(second, platform)
		or default_sep or separator(platform)
	if not first:match(separator_pattern(platform) .. "$") then first = first .. sep end
	return first .. second
end

path.abs = path.combine

---#DES 'path.normalize'
---@param value string
---@param platform 'unix'|'win'?
---@param options {endsep: boolean|'leave'?}?
---@return string
function path.normalize(value, platform, options)
	options = options or {}
	local windows = is_windows(platform)
	local sep = detect_separator(value, platform) or options.default_sep or separator(platform)
	local sep_pattern = separator_pattern(platform)
	local trailing = value:match(sep_pattern .. "$") ~= nil
	local prefix = ""

	if windows then
		local drive = value:match("^([A-Za-z]:)")
		if drive then
			value = value:sub(3)
			prefix = drive
		end
	end
	local root = value:match("^" .. sep_pattern .. "+")
	if root then
		value = value:sub(#root + 1)
		prefix = prefix .. (windows and (#root > 1 and sep .. sep or sep) or "/")
	end

	local parts = {}
	for part in value:gmatch(windows and "[^\\/]+" or "[^/]+") do
		if part == "." then
			-- A lexical path never needs current-directory components.
		elseif part == ".." and parts[#parts] and parts[#parts] ~= ".." then
			table.remove(parts)
		elseif part == ".." and prefix == "" then
			parts[#parts + 1] = part
		elseif part ~= ".." then
			parts[#parts + 1] = part
		end
	end

	local result = prefix .. table.concat(parts, sep)
	if result == "" then result = "." end
	if (options.endsep == true or (options.endsep == "leave" and trailing))
		and result ~= "." and not result:match(sep_pattern .. "$") then
		result = result .. sep
	end
	return result
end

---#DES 'path.commonpath'
---@param first string
---@param second string
---@param platform 'unix'|'win'?
---@return string?
function path.commonpath(first, second, platform)
	if path.isabs(first, platform) ~= path.isabs(second, platform) then return nil end
	first = path.normalize(first, platform)
	second = path.normalize(second, platform)
	if first == second then return first end

	local left, right = first, second
	if is_windows(platform) then
		local first_drive = first:match("^%a:")
		local second_drive = second:match("^%a:")
		if (first_drive or ""):lower() ~= (second_drive or ""):lower() then return nil end
		left = left:lower():gsub("[\\/]", "\\")
		right = right:lower():gsub("[\\/]", "\\")
	end
	local shorter = #left <= #right and left or right
	local sep_byte = separator(platform):byte(1)
	local common = 0
	-- Scan one byte past the shorter path so a common path that is a prefix of
	-- the other is accepted at the end-of-string boundary.
	for index = 1, #shorter + 1 do
		local left_byte, right_byte = left:byte(index), right:byte(index)
		local left_sep = left_byte == nil or left_byte == sep_byte
		local right_sep = right_byte == nil or right_byte == sep_byte
		if left_sep and right_sep then
			common = index
		elseif left_byte ~= right_byte then
			break
		end
	end
	if common == 0 then return "" end
	if common > #shorter then common = #shorter end
	local prefix = #first == #shorter and first or second
	return prefix:sub(1, common)
end

---#DES 'path.depth'
---@param value string
---@param platform 'unix'|'win'?
---@return integer
function path.depth(value, platform)
	local count = 0
	for _ in value:gmatch(is_windows(platform) and "[^\\/]+" or "[^/]+") do count = count + 1 end
	return count
end

---#DES 'path.rel'
---@param value string
---@param pwd string
---@param platform 'unix'|'win'?
---@param sep string?
---@param default_sep string?
---@return string?
function path.rel(value, pwd, platform, sep, default_sep)
	local common = path.commonpath(value, pwd, platform)
	if common == nil then return nil end
	sep = sep or detect_separator(value, platform) or detect_separator(pwd, platform)
		or default_sep or separator(platform)
	local trailing = value:match(separator_pattern(platform) .. "$") ~= nil
	local from = pwd:sub(#common + 1):gsub("^" .. separator_pattern(platform) .. "+", "")
	local to = value:sub(#common + 1):gsub("^" .. separator_pattern(platform) .. "+", "")
	to = to:gsub(separator_pattern(platform) .. "+$", "")
	local result = (".." .. sep):rep(path.depth(from, platform)):gsub(separator_pattern(platform) .. "$", "")
	if to ~= "" then result = result ~= "" and result .. sep .. to or to end
	if result == "" then result = "." end
	if trailing and result ~= "." then result = result .. sep end
	return result
end

---#DES 'path.filename'
---@param value string
---@param platform 'unix'|'win'?
---@param replace (fun(match: string, reason: string): string)?
---@param break_on_error string?
---@return string?, string?, string?
function path.filename(value, platform, replace, break_on_error)
	local windows = is_windows(platform)
	local invalid = windows and "[%z\1-\31<>:\"|%?%*\\/]" or "[%z/]"
	local reason, message, pattern
	if value == "" then
		reason, message, pattern = "empty", "empty filename", ".*"
	elseif value == "." or value == ".." then
		reason, message, pattern = "dot", "filename is `.` or `..`", ".*"
	elseif value:find(invalid) then
		reason, message, pattern = "char", "invalid characters in filename", invalid
	elseif windows and path.dev_alias(value) then
		reason, message, pattern = "dev_alias", "filename is a Windows device alias", ".*"
	elseif #value > 255 then
		reason, message, pattern = "length", "filename too long", ".*"
	elseif value:find("^ +") or value:find(" +$") or value:find("%.$") then
		reason, message, pattern = "edge", "filename has unsafe leading/trailing characters", "^ +| +$|%.$"
	end
	if not reason then return value end
	if not replace or reason == break_on_error then return nil, message, reason end
	local result
	if reason == "edge" then
		result = value
		for _, edge in ipairs({ "^ +", " +$", "%.$" }) do
			result = result:gsub(edge, function (match) return replace(match, reason) end)
		end
	else
		result = value:gsub(pattern, function (match) return replace(match, reason) end)
	end
	if result == value then return nil, message, reason end
	return path.filename(result, platform, replace, reason)
end

return path
