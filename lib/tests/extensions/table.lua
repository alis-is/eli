local test = TEST or require"u-test"
local ok, table_extensions = pcall(require, "eli.extensions.table")

if not ok then
    test["eli.extensions.table available"] = function ()
        test.assert(false, "eli.extensions.table not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.extensions.table available"] = function ()
    test.assert(true)
end

test["keys"] = function ()
    local source = { a = "a", c = "c", b = "b" }
    local keys = table_extensions.keys(source)
    test.assert(#keys == 3)
    for i, v in ipairs(keys) do
        test.assert(source[v])
    end
end

test["values"] = function ()
    local source = { a = "a", c = "c", b = "b" }
    local values = table_extensions.values(source)
    test.assert(#values == 3)
    for i, v in ipairs(values) do
        test.assert(source[v] == v)
    end
end

test["to_array"] = function ()
    local source = { a = "aa", c = "cc", b = "bb" }
    local arr = table_extensions.to_array(source)
    test.assert(#arr == 3)

    for i, v in ipairs(arr) do
        test.assert(source[v.key] == v.value)
    end
end

test["is_array (array)"] = function ()
    local source = { "a", "c", "b" }
    test.assert(table_extensions.is_array(source))
end

test["is_array (not array)"] = function ()
    local source = { a = "a", c = "c", b = "b" }
    test.assert(not table_extensions.is_array(source))
end

test["filter"] = function ()
    local source = { a = "aa", c = "cc", b = "bb" }
    local result = table_extensions.filter(source, function (k, v) return k ~= "a" end)

    test.assert(result.a == nil, "filtered key found in result")
    source.a = nil
    for k, v in pairs(result) do
        test.assert(source[k] == v)
    end
end

test["get"] = function ()
    local t = {
        t2 = {
            v1 = "aaa",
        },
        v2 = "bbb",
        v3 = {
            { name = "item1" },
            { name = "item2" },
        },
    }
    test.assert(type(table_extensions.get(t, "t2")) == "table")
    test.assert(table_extensions.get(t, "v2") == "bbb")
    test.assert(table_extensions.get(t, "v3") == nil)
    test.assert(table_extensions.get(t, "v3", "ccc") == "ccc")

    test.assert(table_extensions.get(t, { "t2", "v1" }) == "aaa")
    test.assert(table_extensions.get(t, { "t2", "v2" }) == nil)
    test.assert(table_extensions.get("invalid", { "t2", "v2" }) == nil)
    test.assert(table_extensions.get(t, { "v3", "1", "name" }) == "item1")
    test.assert(table_extensions.get(t, { "v3", "2", "name" }) == "item2")

    local t2 = { "aaa", "bbb", "ccc" }
    test.assert(table_extensions.get(t2, { "t2", "v2" }) == nil)
    test.assert(table_extensions.get(t2, { "1" }) == "aaa")
    test.assert(table_extensions.get(t2, { "3" }) == "ccc")
end

test["set"] = function ()
    local t = {
        t2 = {
            v1 = "aaa",
        },
        v2 = "bbb",
    }
    table_extensions.set(t, "t3", {})
    test.assert(type(table_extensions.get(t, "t3")) == "table")
    test.assert(table_extensions.get(t, "v3") == nil)
    table_extensions.set(t, "v3", "vvv")
    test.assert(table_extensions.get(t, "v3") == "vvv")

    table_extensions.set(t, { "t2", "v1" }, "zzz")
    test.assert(table_extensions.get(t, { "t2", "v1" }) == "zzz")

    table_extensions.set(t, { "t3", "v1" }, "zzz")
    test.assert(table_extensions.get(t, { "t3", "v1" }) == "zzz")

    local t2 = { "aaa", "bbb", "ccc" }
    table_extensions.set(t2, "2", "zzz")
    test.assert(table_extensions.get(t2, { "2" }) == "zzz")

    -- errors
    table_extensions.set(t, "v4", "zzz")
    local _, err = table_extensions.set(t, { "v4", "v5" }, "zzz")
    test.assert(err ~= nil)

    local _, err = table_extensions.set(t, { "v5", "v6", "v7" }, "zzz")
    test.assert(err == nil)
    test.assert(table_extensions.get(t, { "v5", "v6", "v7" }) == "zzz")
    test.assert(table_extensions.get(t, { "v2" }) == "bbb")
end

test["map"] = function ()
    local t = {
        t2 = {
            v1 = "aaa",
        },
        v2 = "bbb",
    }
    local result = table_extensions.map(t, function (v, k) return tostring(k) .. " = " .. tostring(v) end)
    test.assert(result.t2:match"t2 = table:")
    test.assert(result.v2 == "v2 = bbb")
end

test["reduce"] = function ()
    local t = {
        t2 = {
            v1 = "aaa",
        },
        v2 = "bbb",
    }
    local result = table_extensions.reduce(t, function (acc, v, k)
        acc[k] = true
        return acc
    end, {})
    test.assert(result.t2 == true)
    test.assert(result.v2 == true)

    local t2 = { "aaa", "bbb", "ccc" }
    local result2 = table_extensions.reduce(t2, function (acc, v)
        return acc .. v
    end, "")
    test.assert(result2 == "aaabbbccc")
end

test["includes"] = function ()
    local nested = {
        v1 = "aaa",
    }
    local t = {
        t2 = nested,
        v2 = "bbb",
    }
    test.assert(table.includes(t, "bbb") == true)
    test.assert(table.includes(t, nil) == false)
    test.assert(table.includes(t, "v2") == false)
    test.assert(table.includes(t, nested) == true)
    test.assert(table.includes(t, { v1 = "aaa" }) == false)
    test.assert(table.includes(t, { v1 = "aaa" }, true) == true)

    local not_table = "not table"
    test.assert(table.includes(not_table --[[@as table]], "bbb") == false)
end

test["has_key"] = function ()
    local t = {
        t2 = {
            v1 = "aaa",
        },
        v2 = "bbb",
    }
    test.assert(table.has_key(t, "t2") == true)
    test.assert(table.has_key(t, nil) == false)
    test.assert(table.has_key(t, "t3") == false)
    test.assert(table.has_key(t, "v2") == true)

    local not_table = "not table"
    test.assert(table.has_key(not_table --[[@as table]], "t2") == false)
end

if not TEST then
    test.summary()
end
