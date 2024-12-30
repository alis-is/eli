-- conforms to semver 2.0
local generate_safe_functions = require"eli.util".generate_safe_functions

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
---@return SemVer?
function ver.parse(ver)
	if type(ver) ~= "string" then
		return nil
	end
	local metadata = ver:match".+%+(.+)"
	if (metadata ~= nil) then
		ver = ver:sub(1, #ver - #metadata - 1)
	end
	local prerelease = ver:match".+-([^%+]+)"
	if (prerelease ~= nil) then
		ver = ver:sub(1, #ver - #prerelease - 1)
	end

	local major = tonumber(ver:match"[^%.]+")
	local minor = tonumber(ver:match"[^%.]+.([^%.]+)")
	local patch = tonumber(ver:match"[^%.]+.[^%.]+.([^-]+)")

	return {
		major = major,
		minor = minor,
		patch = patch,
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

	local ver1
	if type(v1) == "string" then
		ver1 = ver.parse(v1)
	end
	local ver2
	if type(v2) == "string" then
		ver2 = ver.parse(v2)
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

return generate_safe_functions(ver)
