local _util = require "eli.util"

local function _keys(t)
    local _keyList = {}
    for k, _ in pairs(t) do
        table.insert(_keyList, k)
    end
    return _keyList
end

local function _values(t)
    local _vals = {}
    for _, v in pairs(t) do
        table.insert(_vals, v)
    end
    return _vals
end

local function _to_array(t)
    if _util.is_array(t) then
        return t
    end
    local arr = {}
    local _keys = {}
    for k in pairs(t) do
        table.insert(_keys, k)
    end
    table.sort(_keys)

    for _, k in ipairs(_keys) do
        table.insert(arr, {key = k, value = t[k]})
    end
    return arr
end

local function _base_get(obj, path)
    if type(obj) ~= "table" then
        return nil
    end
    if type(path) == "string" or type(path) == "number" then
        return obj[path]
    elseif _util.is_array(path) then
        local _part = table.remove(path, 1)
        local _index = _util.is_array(obj) and tonumber(_part) or _part
        if #path == 0 then
            return obj[_index]
        end
        return _base_get(obj[_part], path)
    else
        return nil
    end
end

local function _get(obj, path, default)
    local _result = _base_get(obj, path)
    if _result == nil then
        return default
    end
    return _result
end

local function _set(obj, path, value)
    if type(obj) ~= "table" then
        return obj
    end
    if type(path) == "string" or type(path) == "number" then
        obj[path] = value
    elseif _util.is_array(path) then
        local _part = table.remove(path, 1)
        local _index = _util.is_array(obj) and tonumber(_part) or _part
        if #path == 0 then
            obj[_index] = value
        else
            _set(obj[_part], path, value)
        end
    end
    return obj
end

local function _filter(t, _filterFn)
    if type(_filterFn) ~= "function" then
        return t
    end
    local isArray = _util.is_array(t)

    local res = {}
    for k, v in pairs(t) do
        if _filterFn(k, v) then
            if isArray then
                table.insert(res, v)
            else
                res[k] = v
            end
        end
    end
    return res
end

local function _map(arr, fn)
    if not _util.is_array(arr) or type(fn) ~= "function" then
        return arr
    end
    local _result = {}
    for _, v in ipairs(arr) do
        table.insert(_result, fn(v))
    end
    return _result
end

local function _globalize()
    table.get = _get
    table.set = _set
    table.map = _map
    table.to_array = _to_array
    table.keys = _keys
    table.values = _values
    table.filter = _filter
    table.is_array = _util.is_array
end

return {
    get = _get,
    set = _set,
    map = _map,
    to_array = _to_array,
    keys = _keys,
    values = _values,
    filter = _filter,
    is_array = _util.is_array,
    globalize = _globalize
}