local _test = TEST or require "u-test"
local _ok, _hjson = pcall(require, "hjson")

if not _ok then
    _test["hjson available"] = function()
        _test.assert(false, "hjson not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["hjson available"] = function()
    _test.assert(true)
end

local _data = {
	test = {
		nested = true,
		type = "object"
	},
	root = "root level",
	test2 = { "nested", "array" },
	test3 = {
		nested1 = {
			type = "nested object",
			level = 2
		},
		nested2 = {
			type = "nested object",
			level = 2
		}
	}
}

local _encoded = [[{
    test3: {
        nested1: {
            type: nested object
            level: 2
        }
        nested2: {
            type: nested object
            level: 2
        }
    }
    test: {
        nested: true
        type: object
    }
    test2: [
        nested
        array
    ]
    root: root level
}]]

local _encodedJson = [[{
    "test3": {
        "nested1": {
            "type": "nested object",
            "level": 2
        },
        "nested2": {
            "type": "nested object",
            "level": 2
        }
    },
    "test": {
        "nested": true,
        "type": "object"
    },
    "test2": [
        "nested",
        "array"
    ],
    "root": "root level"
}]]

_test["encode"] = function()
	local _result = _hjson.encode(_data)
	_test.assert(_result == _encoded)
end

_test["encode_to_json"] = function()
	local _result = _hjson.encode_to_json(_data)
	_test.assert(_result == _encodedJson)
end

_test["decode"] = function()
	local _result = _hjson.decode(_encoded)
	_test.assert(_result == _data)
end

_test["decode json"] = function()
	local _result = _hjson.decode(_encodedJson)
	_test.assert(_result == _data)
end

if not TEST then
    _test.summary()
end
