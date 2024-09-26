--[[ // TODO consider implications of merging proc with os and fs with io ]]
local _elified = false
local _overridenValues = {}
local util = require"eli.util"

local function _elify()
	if (_elified) then
		return
	end
	local _special = { os = true }
	local _exclude = { "eli%..*%.extra", "eli%.extensions%..*", "eli%.elify", "eli%.global" }
	for k, v in pairs(package.preload) do
		if not k:match"eli%..*" then
			goto continue
		end
		for _, _ex in ipairs(_exclude) do
			if k:match(_ex) then
				goto continue
			end
		end
		local _efk = k:match"eli%.(.*)"
		if not _efk or _special[_efk] then
			goto continue
		end
		_, _G[_efk] = pcall(require, k)
		::continue::
	end
	_overridenValues.os = os
	os = util.merge_tables(os, require"eli.os")

	-- extensions
	for k, v in pairs(package.preload) do
		if not k:match"eli%.extensions%..*" then
			goto continue
		end
		local _efk = k:match"eli%.extensions%.(.*)"
		if not _efk then
			goto continue
		end
		local _extension = require(k)
		if type(_extension.globalize) == "function" then
			_extension.globalize()
		end
		::continue::
	end

	etype = function (v)
		local _t = type(v)
		if _t == "table" or _t == "userdata" then
			local _type = v.__type
			if type(_type) ~= "string" and type(_type) ~= "function" then
				local _meta = getmetatable(v) or {}
				_type = _meta.__type
			end
			local _ttype = type(_type)
			if _ttype == "string" then
				return _type
			elseif _ttype == "function" then
				return _type()
			end
		end
		return _t
	end

	-- inject globals
	for k, v in pairs(require"eli.global") do
		_G[k] = v
	end
	_elified = true
end

return {
	elify = _elify,
	get_overriden_values = function ()
		return _overridenValues
	end,
	is_elified = function ()
		return _elified == true
	end,
}
