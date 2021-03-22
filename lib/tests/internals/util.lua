local _test = TEST or require "u-test"
local _ok, _internalUtil = pcall(require, "eli.internals.util")

if not _ok then
    _test["eli.internals.util available"] = function()
        _test.assert(false, "eli.internals.util not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.internals.util get_root_dir"] = function()
    local _paths = {
        "src/__app/aaa/remove-all.lua",
        "src/__app/aaa/configure.lua",
        "src/__app/aaa/about.hjson",
        "src/__app/specs.json",
        "src/__app/ami.lua"
    }
    _test.assert(_internalUtil.get_root_dir(_paths) == "src/__app/")
    _paths = {
        "src/__app/aaa/remove-all.lua",
        "src/__app/aaa/configure.lua",
        "src/__app/aaa/about.hjson",
        "src/__app/specs.json",
        "src/ami.lua"
    }
    _test.assert(_internalUtil.get_root_dir(_paths) == "src/")
    _paths = {
        "src/__app/aaa/remove-all.lua",
        "src/__app/aaa/configure.lua",
        "src/__app/aaa/about.hjson",
        "specs.json",
        "src/ami.lua"
    }
    _test.assert(_internalUtil.get_root_dir(_paths) == "")
end

if not TEST then
    _test.summary()
end
