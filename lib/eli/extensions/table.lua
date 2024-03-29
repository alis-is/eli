local util = require"eli.util"

local te = {} -- table extensions

---#DES 'table.keys'
---
---Returns table keys
---@generic T
---@param t table<T, any>
---@return T[]
function te.keys(t)
	local _keyList = {}
	for k, _ in pairs(t) do
		table.insert(_keyList, k)
	end
	return _keyList
end

---#DES 'table.values'
---
---Returns table values
---@generic T
---@param t table<any, T>
---@return T[]
function te.values(t)
	local _vals = {}
	for _, v in pairs(t) do
		table.insert(_vals, v)
	end
	return _vals
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
function te.to_array(t)
	if util.is_array(t) then
		return t
	end
	local arr = {}
	local _keys = {}
	for k in pairs(t) do
		table.insert(_keys, k)
	end
	table.sort(_keys)

	for _, k in ipairs(_keys) do
		table.insert(arr, { key = k, value = t[k] })
	end
	return arr
end

local function base_get(obj, path)
	if type(obj) ~= "table" then
		return nil
	end
	if type(path) == "string" or type(path) == "number" then
		return obj[path]
	elseif util.is_array(path) then
		local _part = table.remove(path, 1)
		local _index = util.is_array(obj) and tonumber(_part) or _part
		if #path == 0 then
			return obj[_index]
		end
		return base_get(obj[_part], path)
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
function te.get(obj, path, default)
	local _result = base_get(obj, path)
	if _result == nil then
		return default
	end
	return _result
end

---#DES 'table.set'
---
---Sets value in path of table to value
---@generic T: table
---@param obj T
---@param path string|string[]
---@param value any
---@return T
function te.set(obj, path, value)
	if type(obj) ~= "table" then
		return obj
	end
	if type(path) == "string" or type(path) == "number" then
		obj[path] = value
	elseif util.is_array(path) then
		local _part = table.remove(path, 1)
		local _index = util.is_array(obj) and tonumber(_part) or _part
		if #path == 0 then
			obj[_index] = value
		else
			te.set(obj[_part], path, value)
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
---@param filterFn fun(k:string|number, v: T): boolean
---@return table<string, T>|T[]
function te.filter(t, filterFn)
	if type(filterFn) ~= "function" then
		return t
	end
	local isArray = util.is_array(t)

	local res = {}
	for k, v in pairs(t) do
		if filterFn(k, v) then
			if isArray and k ~= "n" then
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
---@param mapFn fun(element: T, k: string| number): any
---@return T[]|table<string|number, T>
function te.map(arr, mapFn)
	if type(mapFn) ~= "function" then
		return arr
	end
	local _result = {}
	for k, v in pairs(arr) do
		_result[k] = mapFn(v, k)
	end
	return _result
end

---#DES 'table.reduce'
---
---reduces array like table to single value
--- can be used to reduce dictionary like tables BUT value is passed as first argument and key as second
---@generic T, U
---@param arr T[]|table<string|number, T>
---@param reduceFn fun(acc: U, element: T, k: string| number): U
---@param initial U
---@return T
function te.reduce(arr, reduceFn, initial)
	if type(reduceFn) ~= "function" then
		return initial
	end
	local _acc = initial
	for k, v in pairs(arr) do
		_acc = reduceFn(_acc, v, k)
	end
	return _acc
end

---#DES 'table.includes'
---
--- checks whether table includes value
--- if provided arrOrTable is not a table returns false
--- for nil val always returns false (lua returns nil for values not in table)
---@param arrOrTable table
---@param val any
---@param useDeepComparison boolean? compares content of tables
---@return boolean
function te.includes(arrOrTable, val, useDeepComparison)
	if type(arrOrTable) ~= "table" or val == nil then return false end
	for _, v in pairs(arrOrTable) do
		if util.equals(v, val, useDeepComparison) then return true end
	end
	return false
end

---#DES 'table.has_key'
---
--- checks whether table includes value
--- if provided arrOrTable is not a table returns false
--- for nil k always returns false (lua returns nil for values not in table)
---@param arrOrTable table
---@param key any
---@return boolean
function te.has_key(arrOrTable, key)
	if type(arrOrTable) ~= "table" or key == nil then return false end
	for k, _ in pairs(arrOrTable) do
		if k == key then return true end
	end
	return false
end

---#DES 'table.is_array'
---
--- checks whether table is array
---@param t any
---@return boolean
function te.is_array(t)
	return util.is_array(t)
end

function te.globalize()
	for k, v in pairs(te) do
		table[k] = v
	end
end

return te
