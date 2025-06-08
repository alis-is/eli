-- conforms to semver 2.0
---@class SemVer
---@field major number
---@field minor number
---@field patch number
---@field prerelease string
---@field metadata string

local ver = {}

---#DES 'ver.parse'
---
---Parses version string and returns table with major, minor, path, prerelease
---and metadata values
---@param ver string
---@return SemVer?, string?
function ver.parse(ver)
	if type(ver) ~= "string" then
		return nil, "version must be a string"
	end

	local main, metadata = ver:match"([^+]+)%+(.*)"
	if not main then
		main = ver
	elseif metadata == "" or metadata == nil then
		return nil, "invalid version string: empty metadata"
	elseif metadata:find"+" then
		return nil, "invalid version string: multiple '+' characters"
	end

	local core, prerelease = main:match"([^%-]+)%-(.*)"
	if not core then
		core = main
	elseif prerelease == "" or prerelease == nil then
		return nil, "invalid version string: empty prerelease"
	end

	local major, minor, patch = core:match"^(%d+)%.(%d+)%.(%d+)$"
	if not major then
		major, minor = core:match"^(%d+)%.(%d+)$"
		patch = 0
	end
	if not major then
		major = core:match"^(%d+)$"
		minor = 0
		patch = 0
	end

	if not major then
		return nil, "invalid version core: " .. tostring(ver)
	end

	return {
		major = tonumber(major) or 0,
		minor = tonumber(minor) or 0,
		patch = tonumber(patch) or 0,
		prerelease = prerelease,
		metadata = metadata,
	}
end

---compare prerelease strings
---@param p1 string
---@param p2 string
---@return integer
local function compare_prerelase(p1, p2)
	if p1 == nil and p2 == nil then
		return 0
	elseif p1 == nil and p2 ~= nil then
		return 1
	elseif p2 == nil and p1 ~= nil then
		return -1
	end

	local p1_parts = {}
	for p in string.gmatch(p1, "[^%.]+") do
		table.insert(p1_parts, p)
	end

	local p2_parts = {}
	for p in string.gmatch(p2, "[^%.]+") do
		table.insert(p2_parts, p)
	end

	local range = #p1_parts > #p2_parts and #p2_parts or #p1_parts

	for i = 1, range do
		local sub_p1 = p1_parts[i]
		local sub_p2 = p2_parts[i]

		local p1_number = tonumber(sub_p1)
		local p2_number = tonumber(sub_p2)

		if p1_number and p2_number then
			if p1_number ~= p2_number then
				return p1_number > p2_number and 1 or -1
			end
		elseif p1_number and not p2_number then
			return -1
		elseif not p1_number and p2_number then
			return 1
		else -- string comparison
			local s_range = #sub_p1 > #sub_p2 and #sub_p2 or #sub_p1
			for j = 1, s_range do
				if sub_p1:sub(j, j) ~= sub_p2:sub(j, j) then
					return sub_p1:sub(j, j) > sub_p2:sub(j, j) and 1 or -1
				end
			end
			if #sub_p1 ~= #sub_p2 then
				return s_range == #sub_p1 and -1 or 1
			end
		end
	end
	if #p1_parts == #p2_parts then
		return 0
	end
	return range == #p1_parts and -1 or 1
end

---#DES 'ver.compare'
---
---If the semver v1 is newer than v2, returns 1. If the semver v2 is newer than v1,
---returns -1. If v1 equals v2, returns 0;
---@param v1 string
---@param v2 string
---@return integer
function ver.compare(v1, v2)
	if type(v1) == "number" and type(v2) == "number" then
		if v1 > v2 then
			return 1
		elseif v1 < v2 then
			return -1
		end
	end

	local ver1, err
	if type(v1) == "string" then
		ver1, err = ver.parse(v1)
		if err then
			error(err)
		end
	end
	local ver2
	if type(v2) == "string" then
		ver2, err = ver.parse(v2)
		if err then
			error(err)
		end
	end
	assert(type(ver1) == "table", "Invalid v1 version!")
	assert(type(ver2) == "table", "Invalid v2 version!")

	if ver1.major ~= ver2.major then
		return ver1.major > ver2.major and 1 or -1
	end

	if ver1.minor ~= ver2.minor then
		return ver1.minor > ver2.minor and 1 or -1
	end

	if ver1.patch ~= ver2.patch then
		return ver1.patch > ver2.patch and 1 or -1
	end

	return compare_prerelase(ver1.prerelease, ver2.prerelease)
end

return ver
