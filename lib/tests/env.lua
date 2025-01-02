local test = TEST or require"u-test"
local ok, eli_env = pcall(require, "eli.env")

if not ok then
    test["eli.env available"] = function ()
        test.assert(false, "eli.env not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.env available"] = function ()
    test.assert(true)
end

test["get_env"] = function ()
    local path = eli_env.get_env"PATH"
    test.assert(type(path) == "string")
end

if not eli_env.EENV then
    if not TEST then
        test.summary()
        print"EENV not detected, only basic tests executed..."
        os.exit()
    else
        print"EENV not detected, only basic tests executed..."
        return
    end
end

test["set_env"] = function ()
    local ok = eli_env.set_env("t", "test_value")
    test.assert(ok)
    local t = eli_env.get_env"t"
    test.assert(t == "test_value")
end

test["environment"] = function ()
    local env = eli_env.environment()
    test.assert(type(env) == "table")
end

if not TEST then
    test.summary()
end
