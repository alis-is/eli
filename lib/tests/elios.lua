local _test = TEST or require "u-test"
local _ok, _elios = pcall(require, "eli.os")

if not _ok then
    _test["eli.os available"] = function()
        _test.assert(false, "eli.os not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.os available"] = function()
    _test.assert(true)
end

if not _elios.EOS then
    if not TEST then
        _test.summary()
        print "EOS not detected, only basic tests executed..."
        os.exit()
    else
        print "EOS not detected, only basic tests executed..."
        return
    end
end

_test["sleep"] = function()
    local _referencePoint = os.date("%S")
    _elios.sleep(10)
    local _afterSleep = os.date("%S")
    local _diff = _afterSleep - _referencePoint
    if _diff < 0 then _diff = _diff + 60 end
    _test.assert(_diff > 8 and _diff < 12)
end

_test["chdir & cwd"] = function()
    local _cwd = _elios.cwd()
    _elios.chdir("tmp")
    local _newCwd = _elios.cwd()
    _test.assert(_cwd ~= _newCwd)
    _elios.chdir(_cwd)
    _newCwd = _elios.cwd()
    _test.assert(_cwd == _newCwd)
end

if not TEST then
    _test.summary()
end
