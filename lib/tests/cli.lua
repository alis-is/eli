local test = TEST or require"u-test"
local ok, eli_cli = pcall(require, "eli.cli")

if not ok then
    test["eli.cli available"] = function ()
        test.assert(false, "eli.cli not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.cli available"] = function ()
    test.assert(true)
end

test["parse args"] = function ()
    arg = {
        [-1] = "",
        [0] = "",
        [1] = "-q",
    }

    print(require"hjson".stringify(eli_cli.parse_args()))
    test.assert(true)
end

if not TEST then
    test.summary()
end
