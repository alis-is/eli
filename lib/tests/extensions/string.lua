local test = TEST or require"u-test"
local ok, string_extensions = pcall(require, "eli.extensions.string")

if not ok then
    test["eli.extensions.string available"] = function ()
        test.assert(false, "eli.extensions.string not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.extensions.string available"] = function ()
    test.assert(true)
end

test["trim"] = function ()
    local result = string_extensions.trim"   \ttest \t\n "
    test.assert(result == "test")
end

test["join"] = function ()
    local result = string_extensions.join(", ", "test", "join", "string")
    test.assert(result == "test, join, string")
    local ok, result = pcall(string_extensions.join, ", ", "test", { "join" }, "string")
    test.assert(ok and result:match"test, table:")
    local result = string_extensions.join(", ", { "test", "join", "string" })
    test.assert(result == "test, join, string")
end

test["join_strings"] = function ()
    local result = string_extensions.join_strings(", ", "test", "join", { test = "string" }, "string")
    test.assert(result == "test, join, string")
    local ok, result = pcall(string_extensions.join_strings, ", ", "test", { "join" }, "string")
    test.assert(ok and result == "test, string")
    local result = string_extensions.join_strings(", ", { "test", "join", { test = "string" }, "string" })
    test.assert(result == "test, join, string")
end

test["split"] = function ()
    local result = string_extensions.split("test, join, string", ",", true)
    test.assert(result[1] == "test" and result[2] == "join" and result[3] == "string")
end

test["interpolate"] = function ()
    local result = string_extensions.interpolate(
    "Hello from ${name}! This is formatted: ${n} ${n2}\nAnd this is escaped \\${escaped} and this a table value ${t}"
    , { name = "printf", n = 1, n2 = 2, escaped = "anyValiue", t = {} })
    test.assert(result:match
    "Hello from printf! This is formatted: 1 2\nAnd this is escaped ${escaped} and this a table value table: ")
end

test["globalize"] = function ()
    string_extensions.globalize()
    for k, v in pairs(string_extensions) do
        if k ~= "globalize" then
            test.assert(string[k] == v)
        end
    end
end

if not TEST then
    test.summary()
end
