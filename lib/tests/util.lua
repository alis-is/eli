local _test = TEST or require"u-test"
local _ok, _eliUtil = pcall(require, "eli.util")

if not _ok then
	_test["eli.util available"] = function ()
		_test.assert(false, "eli.util not available")
	end
	if not TEST then
		_test.summary()
		os.exit()
	else
		return
	end
end

_test["eli.util available"] = function ()
	_test.assert(true)
end

_test["is_array (array)"] = function ()
	local _source = { "a", "c", "b" }
	_test.assert(_eliUtil.is_array(_source))
end

_test["is_array (array packed)"] = function ()
	local _source = table.pack("a", "c", "b")
	_test.assert(_eliUtil.is_array(_source))
end

_test["is_array (not array)"] = function ()
	local _source = { a = "a", c = "c", b = "b" }
	_test.assert(not _eliUtil.is_array(_source))
end

_test["merge_arrays"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_arrays(_t1, _t2)
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k + #_t1] == v)
	end
end

_test["merge_arrays - combine"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_arrays(_t1, _t2, { arrayMergeStrategy = "combine" })
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k + #_t1] == v)
	end
end

_test["merge_arrays - prefer-1"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_arrays(_t1, _t2, { arrayMergeStrategy = "prefer-t1" })
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k + #_t1] == nil)
	end
end

_test["merge_arrays - prefer-2"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_arrays(_t1, _t2, { arrayMergeStrategy = "prefer-t2" })
	for k, v in pairs(_t2) do
		_test.assert(_result[k] == v)
	end
end

_test["merge_arrays - overlay"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_arrays(_t1, _t2, { arrayMergeStrategy = "overlay" })
	for k, v in pairs(_t2) do
		_test.assert(_result[k] == v)
	end
end

_test["merge_arrays (not arrays)"] = function ()
	local _t1 = { a = "a", c = "c", b = "b" }
	local _t2 = { d = "d", f = "f", e = "e" }
	local _result, _error = _eliUtil.merge_arrays(_t1, _t2)
	_test.assert(not _result and _error:find"t1")
	local _result, _error = _eliUtil.merge_arrays({ 1, 2, 3 }, _t2)
	_test.assert(not _result and _error:find"t2")
end

_test["merge_tables (dictionaries - unique keys)"] = function ()
	local _t1 = { a = "a", c = "c", b = "b" }
	local _t2 = { d = "d", f = "f", e = "e" }
	local _result = _eliUtil.merge_tables(_t1, _t2)
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k] == v)
	end
end

_test["merge_tables (dictionaries - no overwrite)"] = function ()
	local _t1 = { a = "a", c = "c", b = "b" }
	local _t2 = { d = "d", f = "f", e = "e", c = "a" }
	local _result = _eliUtil.merge_tables(_t1, _t2)
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		if k ~= "c" then
			_test.assert(_result[k] == v)
		end
	end
end

_test["merge_tables (dictionaries - overwrite)"] = function ()
	local _t1 = { a = "a", c = "c", b = "b" }
	local _t2 = { d = "d", f = "f", e = "e", c = "a" }
	local _result = _eliUtil.merge_tables(_t1, _t2, true)
	for k, v in pairs(_t1) do
		if (k ~= "c") then
			_test.assert(_result[k] == v)
		end
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k] == v)
	end
end

_test["merge_tables (array)"] = function ()
	local _t1 = { "a", "c", "b" }
	local _t2 = { "d", "f", "e" }
	local _result = _eliUtil.merge_tables(_t1, _t2)
	_test.assert(#_result == 6)

	local _matched = 0
	for i, v in ipairs(_result) do
		for i2, v2 in ipairs(_t1) do
			if v == v2 then
				_matched = _matched + 1
			end
		end
	end
	for i, v in ipairs(_result) do
		for i2, v2 in ipairs(_t2) do
			if v == v2 then
				_matched = _matched + 1
			end
		end
	end
	_test.assert(_matched == 6)
end

_test["merge_tables (array) - combine"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_tables(_t1, _t2, { arrayMergeStrategy = "combine" })
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k + #_t1] == v)
	end
end

_test["merge_tables (array) - prefer-1"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_tables(_t1, _t2, { arrayMergeStrategy = "prefer-t1" })
	for k, v in pairs(_t1) do
		_test.assert(_result[k] == v)
	end
	for k, v in pairs(_t2) do
		_test.assert(_result[k + #_t1] == nil)
	end
end

_test["merge_tables (array) - prefer-2"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_tables(_t1, _t2, { arrayMergeStrategy = "prefer-t2" })
	for k, v in pairs(_t2) do
		_test.assert(_result[k] == v)
	end
end

_test["merge_tables (array) - overlay"] = function ()
	local _t1 = { 1, "2", true }
	local _t2 = { 3, "4", false }
	local _result = _eliUtil.merge_tables(_t1, _t2, { arrayMergeStrategy = "overlay" })
	for k, v in pairs(_t2) do
		_test.assert(_result[k] == v)
	end
end

_test["global_log_factory (GLOBAL_LOGGER == nil)"] = function ()
	local _debug = _eliUtil.global_log_factory("test/util", "debug")
	_test.assert(pcall(_debug, "test"))
end

_test["global_log_factory (GLOBAL_LOGGER == 'ELI_LOGGER')"] = function ()
	local _called = false
	GLOBAL_LOGGER = {
		log = function (logger, msg, lvl)
			_called = true
			_test.assert(logger.__type == "ELI_LOGGER")
			_test.assert(lvl == "debug")
		end,
		__type = "ELI_LOGGER",
	}
	setmetatable(GLOBAL_LOGGER, GLOBAL_LOGGER)
	local _debug = _eliUtil.global_log_factory("test/util", "debug")
	_test.assert(pcall(_debug, "test"))
	_test.assert(_called)
end

_test["clone - primitive"] = function ()
	local _n = 5
	local _s = "stringToClone"
	local _nil = nil
	local _fn = function () end

	_test.assert(_n == _eliUtil.clone(_n))
	_test.assert(_s == _eliUtil.clone(_s))
	_test.assert(_nil == _eliUtil.clone(_nil))
	_test.assert(_fn == _eliUtil.clone(_fn))
end

_test["equals - primitive"] = function ()
	local function _validate(v1, v2)
		return _eliUtil.equals(v1, v2) == (v1 == v2)
	end
	_test.assert(_validate("aaa", "aaa"))
	_test.assert(_validate("aaa", "bbb"))
	_test.assert(_validate(2, 2))
	_test.assert(_validate(2, 3))
	_test.assert(_validate(2, 2))
	_test.assert(_validate(nil, 3))
	_test.assert(_validate(nil, nil))
	_test.assert(_validate(true, false))
	_test.assert(_validate(true, true))
	_test.assert(_validate(true, true))
end

_test["clone & equals - shallow"] = function ()
	local _t = {
		_n = 5,
		_s = "stringToClone",
		_nil = nil,
		_fn = function () end,
	}
	local _clone = _eliUtil.clone(_t)
	_test.assert(_clone ~= _t)
	_test.assert(_eliUtil.equals(_t, _clone, 1))
end

_test["clone & equals - deep"] = function ()
	local _debug = _eliUtil.global_log_factory("test/util", "debug")
	local _t = {
		_n = 5,
		_s = "stringToClone",
		_nil = nil,
		_fn = function () end,
		_t = {
			_n = 5,
			_s = "stringToClone",
			_nil = nil,
			_fn = function () end,
		},
	}
	local _clone = _eliUtil.clone(_t, true)
	_test.assert(_clone ~= _t)
	_test.assert(not _eliUtil.equals(_t, _clone, 1))
	_test.assert(_eliUtil.equals(_t, _clone, true))
end

if not TEST then
	_test.summary()
end
