local _test = TEST or require "u-test"
local _ok, _eliCli = pcall(require, "eli.cli")

if not _ok then
    _test["eli.cli available"] = function()
        _test.assert(false, "eli.cli not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.cli available"] = function()
    _test.assert(true)
end

_test["parse args"] = function()
    arg = {
        [-1] = "",
        [0] = "",
        [1] = "-q"
    }

    print(require"hjson".stringify(_eliCli.parse_args()))
    _test.assert(true)
end

if not TEST then
    _test.summary()
end
