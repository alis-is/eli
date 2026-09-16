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

test["environment API belongs to os"] = function ()
	local os_extra = require"eli.os.extra"
	test.assert(os.env == nil)
	test.assert(os_extra.env == nil)
	test.assert(type(os.get_env) == "function")
	test.assert(type(os.set_env) == "function")
	test.assert(os.setenv == os.set_env)
	test.assert(type(os.environment) == "function")
	test.assert(eli_env.get_env ~= os.get_env)
	test.assert(eli_env.set_env ~= os.set_env)
	test.assert(eli_env.environment ~= os.environment)
	test.assert(os.getenv ~= os.get_env)
	test.assert(os_extra.get_env == nil)
	test.assert(os_extra.set_env == nil)
	test.assert(os_extra.environment == nil)
	test.assert(eli_env.sleep == nil)
    local name = "ELI_ENV_MERGE_TEST"
    local previous = os.getenv(name)
    assert(eli_env.set_env(name, ""))
    test.assert(os.getenv(name) == "")
    test.assert(eli_env.environment()[name] == "")
    assert(eli_env.set_env(name, nil))
    test.assert(os.getenv(name) == nil)
    assert(eli_env.set_env(name, previous))
end

if not TEST then
    test.summary()
end
