--[[ // TODO consider implications of merging proc with os and fs with io ]]
local is_elified = false
local overridden_values = {}
local util = require"eli.util"

local function elify()
	if (is_elified) then
		return
	end
	local special = { os = true }
	local exclude = { "eli%..*%.extra", "eli%.extensions%..*", "eli%.elify", "eli%.global" }
	for k, _ in pairs(package.preload) do
		if not k:match"eli%..*" then
			goto continue
		end
		for _, exclusion_pattern in ipairs(exclude) do
			if k:match(exclusion_pattern) then
				goto continue
			end
		end
		local eli_module_id = k:match"eli%.(.*)"
		if not eli_module_id or special[eli_module_id] then
			goto continue
		end
		_, _G[eli_module_id] = pcall(require, k)
		::continue::
	end
	overridden_values.os = os
	os = util.merge_tables(os, require"eli.os")

	-- extensions
	for k, _ in pairs(package.preload) do
		if not k:match"eli%.extensions%..*" then
			goto continue
		end
		local eli_extension_id = k:match"eli%.extensions%.(.*)"
		if not eli_extension_id then
			goto continue
		end
		local extension = require(k)
		if type(extension.globalize) == "function" then
			extension.globalize()
		end
		::continue::
	end

	---#DES 'etype'
	---
	--- extended type check - checks the type of a value and returns a string representation of it.
	--- @param value any
	--- @return string
	etype = function (value)
		local value_type = type(value)
		if value_type == "table" or value_type == "userdata" then
			local __type = value.__type
			if type(__type) ~= "string" and type(__type) ~= "function" then
				local _meta = getmetatable(value) or {}
				__type = _meta.__type
			end
			local type_of_type = type(__type)
			if type_of_type == "string" then
				return __type
			elseif type_of_type == "function" then
				return __type()
			end
		end
		return value_type
	end

	-- inject globals
	for k, v in pairs(require"eli.global") do
		_G[k] = v
	end
	is_elified = true
end

return {
	elify = elify,
	get_overriden_values = function ()
		return overridden_values
	end,
	is_elified = function ()
		return is_elified == true
	end,
}
