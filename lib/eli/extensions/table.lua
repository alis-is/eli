local util = require"eli.util"

local table_extensions = {} -- table extensions

---#DES 'table.keys'
---
---Returns table keys
---@generic T
---@param t table<T, any>
---@return T[]
function table_extensions.keys(t)
	local key_list = {}
	for k, _ in pairs(t) do
		table.insert(key_list, k)
	end
	return key_list
end

---#DES 'table.values'
---
---Returns table values
---@generic T
---@param t table<any, T>
---@return T[]
function table_extensions.values(t)
	local values = {}
	for _, v in pairs(t) do
		table.insert(values, v)
	end
	return values
end

---@class KeyValuePair
---@field key any
---@field value any

---#DES 'table.to_array'
---
---Converts table to array of {key, value} pairs
---@generic K, V
---@param t table<K, V>
---@return KeyValuePair --{key: K, value: V}[]
function table_extensions.to_array(t)
	if util.is_array(t) then
		return t
	end
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)

	local result = {}
	for _, k in ipairs(keys) do
		table.insert(result, { key = k, value = t[k] })
	end
	return result
end

local function base_get(obj, path)
	if type(obj) ~= "table" then
		return nil
	end
	if type(path) == "string" or type(path) == "number" then
		return obj[path]
	elseif util.is_array(path) and #path > 0 then
		local part = table.remove(path, 1)
		local index = util.is_array(obj) and tonumber(part) or part
		if #path == 0 then
			return obj[index]
		end
		return base_get(obj[part], path)
	else
		return nil
	end
end

---#DES 'table.get'
---
---Selects value from path from table or default if result is nil
---@param obj table
---@param path string|string[]
---@param default any
---@return any
function table_extensions.get(obj, path, default)
	local result = base_get(obj, util.clone(path))
	if result == nil then
		return default
	end
	return result
end

---#DES 'table.set'
---
---Sets value in path of table to value
---@generic T: table
---@param obj T
---@param path string|string[]
---@param value any
---@return T, string?
function table_extensions.set(obj, path, value)
	if obj == nil and #path > 0 then -- create table if obj is nil
		obj = {}
	elseif type(obj) ~= "table" then
		if #path > 0 then
			return nil, "cannot set nested value on a non-table object"
		end
		return value
	end
	path = util.clone(path)
	if type(path) == "string" or type(path) == "number" then
		obj[path] = value
	elseif util.is_array(path) and #path > 0 then
		local part = table.remove(path, 1)
		local index = util.is_array(obj) and tonumber(part) or part
		if #path == 0 then
			obj[index] = value
		else
			obj[part] = obj[part] or {} -- create table if not exists
			return table_extensions.set(obj[part], path, value)
		end
	end
	return obj
end

---#DES 'table.filter'
---
---Returns elements for which filter function returns true from table t
---@generic T
---@overload fun(t: table<string, T>, filterFn: fun(k:string|number, v: T): boolean): table<string, T>
---@param t table<string, T>|T[]
---@param filter_fn fun(k:string|number, v: T): boolean
---@return table<string, T>|T[]
function table_extensions.filter(t, filter_fn)
	if type(filter_fn) ~= "function" then
		return t
	end
	local is_array = util.is_array(t)

	local res = {}
	for k, v in pairs(t) do
		if filter_fn(k, v) then
			if is_array and k ~= "n" then
				table.insert(res, v)
			else
				res[k] = v
			end
		end
	end
	return res
end

---#DES 'table.map'
---
---maps array like table elemenets to corresponding values returned by mapFn
--- can be used to map dictionary like tables BUT value is passed as first argument and key as second
---@generic T
---@param arr T[]|table<string|number, T>
---@param map_fn fun(element: T, k: string| number): any
---@return T[]|table<string|number, T>
function table_extensions.map(arr, map_fn)
	if type(map_fn) ~= "function" then
		return arr
	end
	local result = {}
	for k, v in pairs(arr) do
		result[k] = map_fn(v, k)
	end
	return result
end

---#DES 'table.reduce'
---
---reduces array like table to single value
--- can be used to reduce dictionary like tables BUT value is passed as first argument and key as second
---@generic T, U
---@param arr T[]|table<string|number, T>
---@param reduce_fn fun(acc: U, element: T, k: string| number): U
---@param initial_value U
---@return T
function table_extensions.reduce(arr, reduce_fn, initial_value)
	if type(reduce_fn) ~= "function" then
		return initial_value
	end
	local accumulated_value = initial_value
	for k, v in pairs(arr) do
		accumulated_value = reduce_fn(accumulated_value, v, k)
	end
	return accumulated_value
end

---#DES 'table.includes'
---
--- checks whether table includes value
--- if provided arrOrTable is not a table returns false
--- for nil val always returns false (lua returns nil for values not in table)
---@param array_or_table table
---@param val any
---@param use_deep_comparison boolean? compares content of tables
---@return boolean
function table_extensions.includes(array_or_table, val, use_deep_comparison)
	if type(array_or_table) ~= "table" or val == nil then return false end
	for _, v in pairs(array_or_table) do
		if util.equals(v, val, use_deep_comparison) then return true end
	end
	return false
end

---#DES 'table.has_key'
---
--- checks whether table includes value
--- if provided arrOrTable is not a table returns false
--- for nil k always returns false (lua returns nil for values not in table)
---@param array_or_table table
---@param key any
---@return boolean
function table_extensions.has_key(array_or_table, key)
	if type(array_or_table) ~= "table" or key == nil then return false end
	for k, _ in pairs(array_or_table) do
		if k == key then return true end
	end
	return false
end

---#DES 'table.is_array'
---
--- checks whether table is array
---@param t any
---@return boolean
function table_extensions.is_array(t)
	return util.is_array(t)
end

function table_extensions.globalize()
	for k, v in pairs(table_extensions) do
		table[k] = v
	end
end

return table_extensions
