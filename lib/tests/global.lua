local _test = TEST or require 'u-test'
local _ok, _eliGlobals = pcall(require, "eli.global")

_test["global available"] = function ()
    _test.assert(_ok)
end
_test["printf C like"] = function ()
    local _oldWrite = io.write
    local _result
    io.write = function(data)
        _result = data
    end
    _eliGlobals.printf("Hello from %s! This is formatted: %f %e\n", "printf", 1, 2)
    io.write = _oldWrite
    _test.assert(_result == "Hello from printf! This is formatted: 1.000000 2.000000e+00\n")
end

_test["printf interpolated"] = function ()
    local _oldWrite = io.write
    local _result
    io.write = function(data)
        _result = data
    end
    _eliGlobals.printf("Hello from ${name}! This is formatted: ${n} ${n2}\nAnd this is escaped \\${escaped}", { name = "printf", n = 1, n2 = 2, escaped = "anyValiue"})
    io.write = _oldWrite
    _test.assert(_result == "Hello from printf! This is formatted: 1 2\nAnd this is escaped ${escaped}")
end

if not TEST then 
    _test.summary()
end