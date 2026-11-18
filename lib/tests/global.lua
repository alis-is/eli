local test = TEST or require"u-test"
local ok, eli_globals = pcall(require, "eli.global")

test["global available"] = function ()
    test.assert(ok)
end
test["printf C like"] = function ()
    local old_write = io.write
    local result
    io.write = function (data)
        result = data
    end
    eli_globals.printf("Hello from %s! This is formatted: %f %e\n", "printf", 1, 2)
    io.write = old_write
    test.assert(result == "Hello from printf! This is formatted: 1.000000 2.000000e+00\n")
end

test["printf interpolated"] = function ()
    local old_write = io.write
    local result
    io.write = function (data)
        result = data
    end
    eli_globals.printf("Hello from ${name}! This is formatted: ${n} ${n2}\nAnd this is escaped \\${escaped}",
        { name = "printf", n = 1, n2 = 2, escaped = "anyValiue" })
    io.write = old_write
    test.assert(result == "Hello from printf! This is formatted: 1 2\nAnd this is escaped ${escaped}")
end

test["embedded release version"] = function ()
    local version = assert(require"hjson".parse(fs.read_file"../../config.hjson").version)
    test.assert(ELI_VERSION == version, "ELI_VERSION must match " .. version)
    test.assert(ELI_LIB_VERSION == version, "ELI_LIB_VERSION must match " .. version)
end

if not TEST then
    test.summary()
end
