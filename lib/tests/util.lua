local test = TEST or require"u-test"
local ok, eli_util = pcall(require, "eli.util")

if not ok then
	test["eli.util available"] = function ()
		test.assert(false, "eli.util not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.util available"] = function ()
	test.assert(true)
end

test["is_array (array)"] = function ()
	local source = { "a", "c", "b" }
	test.assert(eli_util.is_array(source))
end

test["is_array (array packed)"] = function ()
	local source = table.pack("a", "c", "b")
	test.assert(eli_util.is_array(source))
end

test["is_array (not array)"] = function ()
	local source = { a = "a", c = "c", b = "b" }
	test.assert(not eli_util.is_array(source))
end

test["merge_arrays"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_arrays(t1, t2)
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		test.assert(result[k + #t1] == v)
	end
end

test["merge_arrays - combine"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_arrays(t1, t2, { merge_strategy = "combine" })
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		test.assert(result[k + #t1] == v)
	end
end

test["merge_arrays - prefer-1"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_arrays(t1, t2, { merge_strategy = "prefer-t1" })
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		test.assert(result[k + #t1] == nil)
	end
end

test["merge_arrays - prefer-2"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_arrays(t1, t2, { merge_strategy = "prefer-t2" })
	for k, v in pairs(t2) do
		test.assert(result[k] == v)
	end
end

test["merge_arrays - overlay"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_arrays(t1, t2, { merge_strategy = "overlay" })
	for k, v in pairs(t2) do
		test.assert(result[k] == v)
	end
end

test["merge_arrays (not arrays)"] = function ()
	local t1 = { a = "a", c = "c", b = "b" }
	local t2 = { d = "d", f = "f", e = "e" }
	local result, err = eli_util.merge_arrays(t1, t2)
	test.assert(not result and err:find"t1")
	local result, err = eli_util.merge_arrays({ 1, 2, 3 }, t2)
	test.assert(not result and err:find"t2")
end

test["merge_tables (dictionaries - unique keys)"] = function ()
	local t1 = { a = "a", c = "c", b = "b" }
	local t2 = { d = "d", f = "f", e = "e" }
	local result = eli_util.merge_tables(t1, t2)
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		test.assert(result[k] == v)
	end
end

test["merge_tables (dictionaries - no overwrite)"] = function ()
	local t1 = { a = "a", c = "c", b = "b" }
	local t2 = { d = "d", f = "f", e = "e", c = "a" }
	local result = eli_util.merge_tables(t1, t2)
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		if k ~= "c" then
			test.assert(result[k] == v)
		end
	end
end

test["merge_tables (dictionaries - overwrite)"] = function ()
	local t1 = { a = "a", c = "c", b = "b" }
	local t2 = { d = "d", f = "f", e = "e", c = "a" }
	local result = eli_util.merge_tables(t1, t2, true)
	for k, v in pairs(t1) do
		if (k ~= "c") then
			test.assert(result[k] == v)
		end
	end
	for k, v in pairs(t2) do
		test.assert(result[k] == v)
	end
end

test["merge_tables (array)"] = function ()
	local t1 = { "a", "c", "b" }
	local t2 = { "d", "f", "e" }
	local result = eli_util.merge_tables(t1, t2)
	test.assert(#result == 6)

	local matched = 0
	for i, v in ipairs(result) do
		for i2, v2 in ipairs(t1) do
			if v == v2 then
				matched = matched + 1
			end
		end
	end
	for i, v in ipairs(result) do
		for i2, v2 in ipairs(t2) do
			if v == v2 then
				matched = matched + 1
			end
		end
	end
	test.assert(matched == 6)
end

test["merge_tables (array) - combine"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_tables(t1, t2, { array_merge_strategy = "combine" })
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		test.assert(result[k + #t1] == v)
	end
end

test["merge_tables (array) - prefer-1"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_tables(t1, t2, { array_merge_strategy = "prefer-t1" })
	for k, v in pairs(t1) do
		test.assert(result[k] == v)
	end
	for k, v in pairs(t2) do
		test.assert(result[k + #t1] == nil)
	end
end

test["merge_tables (array) - prefer-2"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_tables(t1, t2, { array_merge_strategy = "prefer-t2" })
	for k, v in pairs(t2) do
		test.assert(result[k] == v)
	end
end

test["merge_tables (array) - overlay"] = function ()
	local t1 = { 1, "2", true }
	local t2 = { 3, "4", false }
	local result = eli_util.merge_tables(t1, t2, { array_merge_strategy = "overlay" })
	for k, v in pairs(t2) do
		test.assert(result[k] == v)
	end
end

test["global_log_factory (GLOBAL_LOGGER == nil)"] = function ()
	local debug = eli_util.global_log_factory("test/util", "debug")
	test.assert(pcall(debug, "test"))
end

test["global_log_factory (GLOBAL_LOGGER == 'ELI_LOGGER')"] = function ()
	local called = false
	GLOBAL_LOGGER = {
		log = function (logger, msg, lvl)
			called = true
			test.assert(logger.__type == "ELI_LOGGER")
			test.assert(lvl == "debug")
		end,
		__type = "ELI_LOGGER",
	}
	setmetatable(GLOBAL_LOGGER, GLOBAL_LOGGER)
	local debug = eli_util.global_log_factory("test/util", "debug")
	test.assert(pcall(debug, "test"))
	test.assert(called)
end

test["clone - primitive"] = function ()
	local n = 5
	local s = "stringToClone"
	local nil_value = nil
	local fn = function () end

	test.assert(n == eli_util.clone(n))
	test.assert(s == eli_util.clone(s))
	test.assert(nil_value == eli_util.clone(nil_value))
	test.assert(fn == eli_util.clone(fn))
end

test["equals - primitive"] = function ()
	local function _validate(v1, v2)
		return eli_util.equals(v1, v2) == (v1 == v2)
	end
	test.assert(_validate("aaa", "aaa"))
	test.assert(_validate("aaa", "bbb"))
	test.assert(_validate(2, 2))
	test.assert(_validate(2, 3))
	test.assert(_validate(2, 2))
	test.assert(_validate(nil, 3))
	test.assert(_validate(nil, nil))
	test.assert(_validate(true, false))
	test.assert(_validate(true, true))
	test.assert(_validate(true, true))
end

test["clone & equals - shallow"] = function ()
	local t = {
		n = 5,
		s = "stringToClone",
		nil_value = nil,
		fn = function () end,
	}
	local clone = eli_util.clone(t)
	test.assert(clone ~= t)
	test.assert(eli_util.equals(t, clone, 1))
end

test["clone & equals - deep"] = function ()
	local t = {
		n = 5,
		s = "stringToClone",
		nil_value = nil,
		fn = function () end,
		t = {
			n = 5,
			s = "stringToClone",
			nil_value = nil,
			fn = function () end,
		},
	}
	local clone = eli_util.clone(t, true)
	test.assert(clone ~= t)
	test.assert(not eli_util.equals(t, clone, 1))
	test.assert(eli_util.equals(t, clone, true))
end

if not TEST then
	test.summary()
end
