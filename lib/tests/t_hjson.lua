local test = TEST or require"u-test"
local ok, hjson = pcall(require, "hjson")
local _, eli_util = pcall(require, "eli.util")

if not ok then
    test["hjson available"] = function ()
        test.assert(false, "hjson not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["hjson available"] = function ()
    test.assert(true)
end

local data = {
    test = {
        nested = true,
        type = "object",
    },
    root = "root level",
    test2 = { "nested", "array" },
    test3 = {
        nested1 = {
            type = "nested object",
            level = 2,
        },
        nested2 = {
            type = "nested object",
            level = 2,
        },
    },
}

local encoded = [[{
    root: root level
    test: {
        nested: true
        type: object
    }
    test2: [
        nested
        array
    ]
    test3: {
        nested1: {
            level: 2
            type: nested object
        }
        nested2: {
            level: 2
            type: nested object
        }
    }
}]]

local encoded_json = [[{
    "root": "root level",
    "test": {
        "nested": true,
        "type": "object"
    },
    "test2": [
        "nested",
        "array"
    ],
    "test3": {
        "nested1": {
            "level": 2,
            "type": "nested object"
        },
        "nested2": {
            "level": 2,
            "type": "nested object"
        }
    }
}]]

test["encode"] = function ()
    local result = hjson.encode(data, { sort_keys = true })
    test.assert(result == encoded)
end

test["encode_to_json"] = function ()
    local result = hjson.encode_to_json(data, { sort_keys = true })
    test.assert(result == encoded_json)
end

test["decode"] = function ()
    local result = hjson.decode(encoded)
    test.assert(eli_util.equals(result, data, true))
end

test["decode json"] = function ()
    local result = hjson.decode(encoded_json)
    test.assert(eli_util.equals(result, data, true))
end

if not TEST then
    test.summary()
end
