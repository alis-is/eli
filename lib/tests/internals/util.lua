local test = TEST or require"u-test"
local ok, internal_util = pcall(require, "eli.internals.util")

if not ok then
    test["eli.internals.util available"] = function ()
        test.assert(false, "eli.internals.util not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.internals.util get_root_dir"] = function ()
    local paths = {
        "src/__app/aaa/remove-all.lua",
        "src/__app/aaa/configure.lua",
        "src/__app/aaa/about.hjson",
        "src/__app/specs.json",
        "src/__app/ami.lua",
    }
    test.assert(internal_util.get_root_dir(paths):match"^src[/\\]__app[/\\]$")
    paths = {
        "src/__app/aaa/remove-all.lua",
        "src/__app/aaa/configure.lua",
        "src/__app/aaa/about.hjson",
        "src/__app/specs.json",
        "src/ami.lua",
    }
    test.assert(internal_util.get_root_dir(paths):match"^src[/\\]$")
    paths = {
        "src/__app/aaa/remove-all.lua",
        "src/__app/aaa/configure.lua",
        "src/__app/aaa/about.hjson",
        "specs.json",
        "src/ami.lua",
    }
    test.assert(internal_util.get_root_dir(paths):match"^$")
end

if not TEST then
    test.summary()
end
