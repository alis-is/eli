local util = {}

math.randomseed(os.time())

function util.is_array(t)
	if type(t) ~= "table" then
		return false
	end
	local n = t.n
	local i = 0
	for k in pairs(t) do
		i = i + 1
		if k ~= "n" and i ~= k then
			return false
		end
	end
	-- arrays package with table.pack have n key describing count of elements. So actual number of array indexes is i - 1
	if type(n) == "number" then return n == i - 1 end
	return true
end

---@alias ArrayMergeStrategy "default" | "hybrid" | "combine" | "prefer-t1" | "prefer-t2" | "overlay"

---@class MergeArraysOptions
---@field merge_strategy ArrayMergeStrategy | nil
---@field overwrite boolean? relevant only for hybrid/default strategy - overwrites nested fields of elements in t1 based on values in t2

---@type table<string, fun(t1: any[], t2: any[], options: MergeTablesOptions?): any[]>
local mergeArrayStrategies = {
	hybrid = function (t1, t2, options)
		local taken = {}
		local result = {}
		for _, v in ipairs(t1) do
			-- merge id based arrays
			if type(v) == "table" and (type(v.id) == "string" or type(v.id) == "number") then
				for i = 1, #t2, 1 do
					local v2 = t2[i]
					if type(v2) == "table" and v2.id == v.id then
						v = util.merge_tables(v, v2, options)
						taken[i] = true
						break
					end
				end
			end

			table.insert(result, v)
		end

		for i, v in ipairs(t2) do
			if not taken[i] then
				table.insert(result, v)
			end
		end
		return result
	end,
	combine = function (t1, t2)
		local result = { table.unpack(t1) }
		for _, v in ipairs(t2) do
			table.insert(result, v)
		end
		return result
	end,
	["prefer-t1"] = function (t1, t2)
		if t1 then return t1 end
		return t2
	end,
	["prefer-t2"] = function (t1, t2)
		if t2 then return t2 end
		return t1
	end,
	overlay = function (t1, t2)
		local result = util.clone(t1)
		for k, v in pairs(t2) do
			result[k] = v
		end
		return result
	end,
}

---@param t1 any[]
---@param t2 any[]
---@param options MergeArraysOptions
---@return any[]
local function merge_arrays(t1, t2, options)
	local merge_strategy = options.merge_strategy

	local merge_fn = mergeArrayStrategies[merge_strategy]
	if type(merge_fn) ~= "function" then
		merge_fn = mergeArrayStrategies.hybrid
	end

	return merge_fn(t1, t2, options --[[@as MergeTablesOptions]])
end

---#DES 'util.merge_arrays'
---@param t1 table
---@param t2 table
---@param options MergeArraysOptions?
---@return table?, string?
function util.merge_arrays(t1, t2, options)
	if not util.is_array(t1) then
		return nil, "t1 is not an array"
	end
	if not util.is_array(t2) then
		return nil, "t2 is not an array"
	end
	options = util.merge_tables(options, { merge_strategy = "default", overwrite = false } --[[@as MergeArraysOptions]])

	return merge_arrays(t1, t2, options)
end

---@class MergeTablesOptions
---@field array_merge_strategy ArrayMergeStrategy | nil
---@field overwrite boolean?

---#DES 'util.merge_tables'
---@generic TTable1: table
---@generic TTable2: table
---@param t1? TTable1
---@param t2? TTable2
---@param options boolean|MergeTablesOptions | nil
---@return TTable1 | TTable2
function util.merge_tables(t1, t2, options)
	if t1 == nil then
		return t2 or {}
	end
	if t2 == nil or type(t2) ~= "table" then
		return t1
	end
	if type(t1) ~= "table" then
		return t2
	end

	if type(options) == "boolean" then
		options = { overwrite = options }
	end
	if type(options) ~= "table" then
		options = { overwrite = false }
	end
	if type(options.overwrite) ~= "boolean" then
		options.overwrite = false
	end

	local result = {}
	if util.is_array(t1) and util.is_array(t2) then
		result = merge_arrays(t1, t2, {
			merge_strategy = options.array_merge_strategy,
			overwrite = options.overwrite,
		})
	else
		for k, v in pairs(t1) do
			result[k] = v
		end
		for k, v2 in pairs(t2) do
			local v1 = result[k]
			if type(v1) == "table" and type(v2) == "table" then
				result[k] = util.merge_tables(v1, v2, options)
			elseif type(v1) == "nil" then
				result[k] = v2
			elseif options.overwrite then
				result[k] = v2
			end
		end
	end
	return result
end

---#DES 'util.escape_magic_characters'
---@param s string
---@return string
function util.escape_magic_characters(s)
	if type(s) ~= "string" then
		return s
	end
	return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

---@param t table
---@param prefix string?
local function internal_print_table_deep(t, prefix)
	if type(t) ~= "table" then
		return
	end
	if prefix == nil then prefix = "\t" end
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(prefix .. k .. ":")
			internal_print_table_deep(v, prefix .. "\t")
		else
			print(prefix, k, v)
		end
	end
end

---#DES 'util.print_table'
---@param t table
---@param deep boolean?
function util.print_table(t, deep)
	if type(t) ~= "table" then
		return
	end
	for k, v in pairs(t) do
		if deep and type(v) == "table" then
			print(k .. ":")
			internal_print_table_deep(v)
		else
			print(k, v)
		end
	end
end

---@type Logger?
GLOBAL_LOGGER = GLOBAL_LOGGER or nil


---#DES 'util.global_log_factory'
---@param module string
---@param ... string
---@return fun(msg: string | LogMessage, vars: table?) ...
function util.global_log_factory(module, ...)
	---@type fun(msg: string, vars: table?)[]
	local result = {}
	if (type(GLOBAL_LOGGER) ~= "table" and etype(GLOBAL_LOGGER) ~= "ELI_LOGGER") or
	getmetatable(GLOBAL_LOGGER).__type ~= "ELI_LOGGER" then
		GLOBAL_LOGGER = (require"eli.Logger"):new()
	end

	for _, lvl in ipairs{ ... } do
		table.insert(
			result,
			function (msg, vars)
				if type(msg) ~= "table" then
					msg = { msg = msg }
				end
				msg.module = module
				return GLOBAL_LOGGER:log(msg, lvl, vars)
			end
		)
	end
	return table.unpack(result)
end

--- //TODO: Remove
---#DES 'util.remove_preloaded_lib'
-- this is provides ability to load not packaged eli from cwd
-- for debug purposes
function util.remove_preloaded_lib()
	for k, _ in pairs(package.loaded) do
		if k and k:match"eli%..*" then
			package.loaded[k] = nil
		end
	end
	for k, _ in pairs(package.preload) do
		if k and k:match"eli%..*" then
			package.preload[k] = nil
		end
	end
	print"eli.* packages unloaded."
end

---#DES 'util.random_string'
---@param length number
---@param charset table?
---@return string
function util.random_string(length, charset)
	if type(charset) ~= "table" then
		charset = {}
		for c = 48, 57 do
			table.insert(charset, string.char(c))
		end
		for c = 65, 90 do
			table.insert(charset, string.char(c))
		end
		for c = 97, 122 do
			table.insert(charset, string.char(c))
		end
	end
	if not length or length <= 0 then
		return ""
	end

	return util.random_string(length - 1) .. charset[math.random(1, #charset)]
end

---@generic T
---@param v T
---@param cache table?
---@param deep (boolean|number)?
---@param cloneMetatable boolean?
---@return T
local function internal_clone(v, cache, deep, cloneMetatable)
	if type(deep) == "number" then deep = deep - 1 end
	local should_go_deeper = deep == true or (type(deep) == "number" and deep >= 0)

	cache = cache or {}
	if type(v) == "table" then
		if cache[v] then
			return cache[v]
		else
			local clone_fn = should_go_deeper and internal_clone or function (v) return v end
			local copy = {}
			cache[v] = copy
			for k, v in next, v, nil do
				copy[clone_fn(k, cache, deep)] = clone_fn(v, cache, deep)
			end
			local meta = getmetatable(v)
			if meta and cloneMetatable then
				meta = clone_fn(meta, cache, deep)
			end
			setmetatable(copy, meta)
			return copy
		end
	else -- number, string, boolean, etc
		return v
	end
end

---#DES 'util.clone'
---@generic T
---@param v T
---@param deep (boolean|number)?
---@param cloneMetatable boolean?
---@return T
function util.clone(v, deep, cloneMetatable)
	return internal_clone(v, {}, deep, cloneMetatable)
end

---#DES 'util.equals'
---@param v any
---@param v2 any
---@param deep (boolean|number)?
---@return boolean
function util.equals(v, v2, deep)
	if type(deep) == "number" then deep = deep - 1 end
	local should_go_deeper = deep == true or (type(deep) == "number" and deep >= 0)

	if type(v) == "table" and type(v2) == "table" and should_go_deeper then
		for k, v in pairs(v) do
			local result = util.equals(v2[k], v, deep)
			if not result then return false end
		end
		return true
	else -- number, string, boolean, etc
		return v == v2
	end
end

function util.extract_error_info(error_message)
	if type(error_message) ~= "string" then
		return error_message, nil
	end
	-- Pattern to match the message and error code
	local pattern = "(.-)%s*%[(%d+)%]$"
	local message, code = error_message:match(pattern)
	if message and code then
		return message, tonumber(code) -- Convert code to a number
	else
		return error_message, nil -- If pattern doesn't match, return the whole message and nil for the code
	end
end

return util
