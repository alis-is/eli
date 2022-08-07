local _test = TEST or require "u-test"
local _ok, _exString = pcall(require, "eli.extensions.string")

if not _ok then
    _test["eli.extensions.string available"] = function()
        _test.assert(false, "eli.extensions.string not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.extensions.string available"] = function()
    _test.assert(true)
end

_test["trim"] = function()
    local _result = _exString.trim("   \ttest \t\n ")
    _test.assert(_result == "test")
end

_test["join"] = function()
    local _result = _exString.join(", ", "test", "join", "string")
    _test.assert(_result == "test, join, string")
    local _ok, _result = pcall(_exString.join, ", ", "test", { "join" }, "string")
    _test.assert(_ok and _result:match("test, table:"))
    local _result = _exString.join(", ", { "test", "join", "string" })
    _test.assert(_result == "test, join, string")
end

_test["join_strings"] = function()
    local _result = _exString.join_strings(", ", "test", "join", { test = "string" }, "string")
    _test.assert(_result == "test, join, string")
    local _ok, _result = pcall(_exString.join_strings, ", ", "test", { "join" }, "string")
    _test.assert(_ok and _result == "test, string")
    local _result = _exString.join_strings(", ", { "test", "join", { test = "string" }, "string" })
    _test.assert(_result == "test, join, string")
end

_test["split"] = function()
    local _result = _exString.split("test, join, string", ",", true)
    _test.assert(_result[1] == "test" and _result[2] == "join" and _result[3] == "string")
end

_test["interpolate"] = function()
    local _result = _exString.interpolate("Hello from ${name}! This is formatted: ${n} ${n2}\nAnd this is escaped \\${escaped} and this a table value ${t}"
        , { name = "printf", n = 1, n2 = 2, escaped = "anyValiue", t = {} })
    _test.assert(_result:match("Hello from printf! This is formatted: 1 2\nAnd this is escaped ${escaped} and this a table value table: 0x"))
end

_test["globalize"] = function()
    _exString.globalize()
    for k, v in pairs(_exString) do
        if k ~= "globalize" then
            _test.assert(string[k] == v)
        end
    end
end

if not TEST then
    _test.summary()
end
