local _test = TEST or require 'u-test'
local _ok, _exTable = pcall(require, "eli.extensions.table")

if not _ok then
    _test["eli.extensions.table available"] = function ()
        _test.assert(false, "eli.extensions.table not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.extensions.table available"] = function ()
    _test.assert(true)
end

_test["keys"] = function ()
    local _source = { a = 'a', c = 'c', b = 'b'}
    local _keys = _exTable.keys(_source)
    _test.assert(#_keys == 3)
    for i, v in ipairs(_keys) do 
        _test.assert(_source[v])
    end
end

_test["values"] = function ()
    local _source = { a = 'a', c = 'c', b = 'b'}
    local _values = _exTable.values(_source)
    _test.assert(#_values == 3)
    for i, v in ipairs(_values) do 
        _test.assert(_source[v] == v)
    end
end

_test["to_array"] = function ()
    local _source = { a = 'aa', c = 'cc', b = 'bb'}
    local _arr = _exTable.to_array(_source)
    _test.assert(#_arr == 3)

    for i, v in ipairs(_arr) do 
        _test.assert(_source[v.key] == v.value)
    end
end

_test["is_array (array)"] = function ()
    local _source = { 'a', 'c', 'b'}
    _test.assert(_exTable.is_array(_source))
end

_test["is_array (not array)"] = function ()
    local _source = { a = 'a', c = 'c', b = 'b'}
    _test.assert(not _exTable.is_array(_source))
end

_test["filter"] = function ()
    local _source = { a = 'aa', c = 'cc', b = 'bb'}
    local _result = _exTable.filter(_source, function(k,v) return k ~= 'a' end)

    _test.assert(_result.a == nil, "filtered key found in result")
    _source.a = nil
    for k, v in pairs(_result) do 
        _test.assert(_source[k] == v)
    end
end

_test["get"] = function ()
    local _t = {
        t2 = {
            v1 = "aaa"
        },
        v2 = "bbb"
    }
    _test.assert(type(_exTable.get(_t, "t2")) == "table")
    _test.assert(_exTable.get(_t, "v2") == "bbb")
    _test.assert(_exTable.get(_t, "v3") == nil)
    _test.assert(_exTable.get(_t, "v3", "ccc") == "ccc")

    _test.assert(_exTable.get(_t, { "t2", "v1" }) == "aaa")
    _test.assert(_exTable.get(_t, { "t2", "v2" }) == nil)
    _test.assert(_exTable.get("invalid", { "t2", "v2" }) == nil)

    local _t2 = { "aaa", "bbb", "ccc" }
    _test.assert(_exTable.get(_t2, { "t2", "v2" }) == nil)
    _test.assert(_exTable.get(_t2, { "1" }) == "aaa")
    _test.assert(_exTable.get(_t2, { "3" }) == "ccc")
end

_test["set"] = function ()
    local _t = {
        t2 = {
            v1 = "aaa"
        },
        v2 = "bbb"
    }
    _exTable.set(_t, "t3", {})
    _test.assert(type(_exTable.get(_t, "t3")) == "table")
    _test.assert(_exTable.get(_t, "v3") == nil)
    _exTable.set(_t, "v3", "vvv")
    _test.assert(_exTable.get(_t, "v3") == "vvv")

    _exTable.set(_t, { "t2", "v1" }, "zzz")
    _test.assert(_exTable.get(_t, { "t2", "v1" }) == "zzz")

    local _t2 = { "aaa", "bbb", "ccc" }
    _exTable.set(_t2, "2", "zzz")
    _test.assert(_exTable.get(_t2, { "2" }) == "zzz")
end

if not TEST then
    _test.summary()
end