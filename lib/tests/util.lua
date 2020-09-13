  
local _test = TEST or require 'u-test'
local _ok, _eliUtil = pcall(require, "eli.util")

if not _ok then 
    _test["eli.util available"] = function ()
        _test.assert(false, "eli.util not available")
    end
    if not TEST then 
        _test.summary()
        os.exit()
    else 
        return 
    end
end

_test["eli.util available"] = function ()
    _test.assert(true)
end

_test["keys"] = function ()
    local _source = { a = 'a', c = 'c', b = 'b'}
    local _keys = _eliUtil.keys(_source)
    _test.assert(#_keys == 3)
    for i, v in ipairs(_keys) do 
        _test.assert(_source[v])
    end
end

_test["values"] = function ()
    local _source = { a = 'a', c = 'c', b = 'b'}
    local _values = _eliUtil.values(_source)
    _test.assert(#_values == 3)
    for i, v in ipairs(_values) do 
        _test.assert(_source[v] == v)
    end
end

_test["to_array"] = function ()
    local _source = { a = 'aa', c = 'cc', b = 'bb'}
    local _arr = _eliUtil.to_array(_source)
    _test.assert(#_arr == 3)

    for i, v in ipairs(_arr) do 
        _test.assert(_source[v.key] == v.value)
    end
end

_test["is_array (array)"] = function ()
    local _source = { 'a', 'c', 'b'}
    _test.assert(_eliUtil.is_array(_source))
end

_test["is_array (not array)"] = function ()
    local _source = { a = 'a', c = 'c', b = 'b'}
    _test.assert(not _eliUtil.is_array(_source))
end

_test["merge_tables (dictionaries - unique keys)"] = function ()
    local _t1 = { a = 'a', c = 'c', b = 'b'}
    local _t2 = { d = 'd', f = 'f', e = 'e'}
    local _result = _eliUtil.merge_tables(_t1, _t2)
    for k,v in pairs(_t1) do 
        _test.assert(_result[k] == v)
    end
    for k,v in pairs(_t2) do 
        _test.assert(_result[k] == v)
    end
end

_test["merge_tables (dictionaries - no overwrite)"] = function ()
    local _t1 = { a = 'a', c = 'c', b = 'b'}
    local _t2 = { d = 'd', f = 'f', e = 'e', c = 'a'}
    local _result = _eliUtil.merge_tables(_t1, _t2)
    for k,v in pairs(_t1) do 
        _test.assert(_result[k] == v)
    end
    for k,v in pairs(_t2) do 
        if k ~= 'c' then
            _test.assert(_result[k] == v)
        end
    end
end

_test["merge_tables (dictionaries - overwrite)"] = function ()
    local _t1 = { a = 'a', c = 'c', b = 'b'}
    local _t2 = { d = 'd', f = 'f', e = 'e', c = 'a'}
    local _result = _eliUtil.merge_tables(_t1, _t2, true)
    for k,v in pairs(_t1) do 
        if (k ~= 'c') then 
            _test.assert(_result[k] == v)
        end
    end
    for k,v in pairs(_t2) do 
        _test.assert(_result[k] == v)
    end
end

_test["merge_tables (array)"] = function ()
    local _t1 = { 'a', 'c', 'b' }
    local _t2 = { 'd', 'f', 'e' }
    local _result = _eliUtil.merge_tables(_t1, _t2)
    _test.assert(#_result == 6)

    local _matched = 0
    for i,v in ipairs(_result) do
        for i2, v2 in ipairs(_t1) do 
            if v == v2 then 
                _matched = _matched + 1 
            end
        end
    end
    for i,v in ipairs(_result) do
        for i2, v2 in ipairs(_t2) do 
            if v == v2 then 
                _matched = _matched + 1 
            end
        end
    end
    _test.assert(_matched == 6)
end

_test["filter_table"] = function ()
    local _source = { a = 'aa', c = 'cc', b = 'bb'}
    local _result = _eliUtil.filter_table(_source, function(k,v) return k ~= 'a' end)

    _test.assert(_result.a == nil, "filtered key found in result")
    _source.a = nil
    for k, v in pairs(_result) do 
        _test.assert(_source[k] == v)
    end
end

_test["global_log_factory (GLOBAL_LOGGER == nil)"] = function ()
    local _debug = _eliUtil.global_log_factory("test/util", "debug")
    _test.assert(pcall(_debug, "test"))
end

_test["global_log_factory (GLOBAL_LOGGER == 'ELI_LOGGER')"] = function ()
    local _called = false
    GLOBAL_LOGGER = {
        log = function(logger, msg, lvl)
            _called = true
            _test.assert(logger.__type == 'ELI_LOGGER')
            _test.assert(lvl == 'debug')
        end,
        __type = "ELI_LOGGER"
    }
    local _debug = _eliUtil.global_log_factory("test/util", "debug")
    _test.assert(pcall(_debug, "test"))
    _test.assert(_called)
end

if not TEST then 
    _test.summary()
end