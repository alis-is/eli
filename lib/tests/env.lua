  
local _test = TEST or require 'u-test'
local _ok, _eliEnv = pcall(require, "eli.env")

if not _ok then 
    _test["eli.env available"] = function ()
        _test.assert(false, "eli.env not available")
    end
    if not TEST then 
        _test.summary()
        os.exit()
    else 
        return 
    end
end

_test["eli.env available"] = function ()
    _test.assert(true)
end

_test["get_env"] = function ()
    local _path = _eliEnv.get_env("PATH")
    _test.assert(type(_path) == 'string')
end

if not _eliEnv.EENV then
    if not TEST then 
        _test.summary()
        print"EENV not detected, only basic tests executed..."
        os.exit()
    else 
        print"EENV not detected, only basic tests executed..."
        return 
    end
end

_test["set_env"] = function ()
    local _ok = _eliEnv.set_env("t", "test_value")
    _test.assert(_ok)
    local _t = _eliEnv.get_env("t")
    _test.assert(_t == 'test_value')
end

_test["environment"] = function ()
    local _env = _eliEnv.environment()
    _test.assert(type(_env) == 'table')
end

if not TEST then 
    _test.summary()
end