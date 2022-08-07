local _test = TEST or require "u-test"
local _ok, _hjson = pcall(require, "hjson")
local _ok2, _elitUtil = pcall(require, "eli.util")

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

local _encodedJson = [[{
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

_test["encode"] = function()
	local _result = _hjson.encode(_data, { sortKeys = true })
	_test.assert(_result == _encoded)
end

_test["encode_to_json"] = function()
	local _result = _hjson.encode_to_json(_data, { sortKeys = true })
	_test.assert(_result == _encodedJson)
end

_test["decode"] = function()
	local _result = _hjson.decode(_encoded)
	_test.assert(_elitUtil.equals(_result, _data, true))
end

_test["decode json"] = function()
	local _result = _hjson.decode(_encodedJson)
	_test.assert(_elitUtil.equals(_result, _data, true))
end

if not TEST then
    _test.summary()
end
