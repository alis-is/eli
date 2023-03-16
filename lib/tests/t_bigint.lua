local _test = TEST or require"u-test"
local _ok, _bigint = pcall(require, "bigint")

if not _ok then
	_test["bigint available"] = function ()
		_test.assert(false, "bigint not available")
	end
	if not TEST then
		_test.summary()
		os.exit()
	else
		return
	end
end

_test["eli.bigint available"] = function ()
	_test.assert(true)
end

_test["bigint.new"] = function ()
	-- bigint from float number (5.3 -> 5)
	local _a = _bigint.new(5.3)
	local _b = _bigint.new("5")
	_test.assert(_a == _b)

	-- bigint from string "5.3" (should fail)
	local success, _c = pcall(function() return _bigint.new("5.3") end)
	_test.assert(not success)

	-- bigint from integer number (5 -> 5)
	local _d = _bigint.new(5)
	_test.assert(_d == _b)

	-- bigint from string "5" (5 -> 5)
	local _e = _bigint.new("5")
	_test.assert(_e == _b)

	-- bigint from bigint 5 (5 -> 5)
	local _f = _bigint.new(_b)
	_test.assert(_f == _b)

	-- init with no param (0)
	local _g = _bigint.new()
	_test.assert(_g == _bigint.new("0"))
end

_test["bigint.add"] = function ()
	-- add 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"123456789012345678901234567890"
	local _c = _bigint.new"246913578024691357802469135780"
	_test.assert(_a + _b == _c)

	-- add bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = 110
	_c = _bigint.new"123456789012345678901234568000"
	_test.assert(_a + _b == _c)

	-- add bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "110"
	_c = _bigint.new"123456789012345678901234568000"
	_test.assert(_a + _b == _c)
end

_test["bigint.add_abs"] = function ()
	-- add 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"123456789012345678901234567890" * -1
	local _c = _bigint.new"246913578024691357802469135780"
	_test.assert(_bigint.add_abs(_a, _b) == _c)

	-- add bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = -110
	_c = _bigint.new"123456789012345678901234568000"
	_test.assert(_bigint.add_abs(_a, _b) == _c)

	-- add bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "-110"
	_c = _bigint.new"123456789012345678901234568000"
	_test.assert(_bigint.add_abs(_a, _b) == _c)
end

_test["bigint.sub"] = function ()
	-- sub 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"123456789012345678901234567890"
	local _c = _bigint.new"0"
	_test.assert(_a - _b == _c)

	-- sub bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = 110
	_c = _bigint.new"123456789012345678901234567780"
	_test.assert(_a - _b == _c)

	-- sub bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "110"
	_c = _bigint.new"123456789012345678901234567780"
	_test.assert(_a - _b == _c)
end

_test["bigint.sub_abs"] = function ()
	-- sub 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"123456789012345678901234567890" * -1
	local _c = _bigint.new"0"
	_test.assert(_bigint.sub_abs(_a, _b) == _c)

	-- sub bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = -110
	_c = _bigint.new"123456789012345678901234567780"
	_test.assert(_bigint.sub_abs(_a, _b) == _c)

	-- sub bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "-110"
	_c = _bigint.new"123456789012345678901234567780"
	_test.assert(_bigint.sub_abs(_a, _b) == _c)
end

_test["bigint.mul"] = function ()
	-- mul 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"4"
	local _c = _bigint.new"493827156049382715604938271560"
	_test.assert(_a * _b == _c)

	-- mul bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = 4
	_c = _bigint.new"493827156049382715604938271560"
	_test.assert(_a * _b == _c)

	-- mul bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "4"
	_c = _bigint.new"493827156049382715604938271560"
	_test.assert(_a * _b == _c)
end

_test["bigint.div"] = function ()
	-- div 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"4"
	local _c = _bigint.new"30864197253086419725308641972"
	_test.assert(_a / _b == _c)

	-- div bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = 4
	_c = _bigint.new"30864197253086419725308641972"
	_test.assert(_a / _b == _c)

	-- div bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "4"
	_c = _bigint.new"30864197253086419725308641972"
	_test.assert(_a / _b == _c)
end

_test["bigint.mod"] = function ()
	-- mod 2 bigints
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"4"
	local _c = _bigint.new"2"
	_test.assert(_a % _b == _c)

	-- mod bigint and number
	_a = _bigint.new"123456789012345678901234567890"
	_b = 4
	_c = _bigint.new"2"
	_test.assert(_a % _b == _c)

	-- mod bigint and string
	_a = _bigint.new"123456789012345678901234567890"
	_b = "4"
	_c = _bigint.new"2"
	_test.assert(_a % _b == _c)
end

_test["bigint.pow"] = function ()
	-- pow 2 bigints
	local _a = _bigint.new"2"
	local _b = _bigint.new"4"
	local _c = _bigint.new"16"
	_test.assert(_a ^ _b == _c)

	-- pow bigint and number
	_a = _bigint.new"2"
	_b = 4
	_c = _bigint.new"16"
	_test.assert(_a ^ _b == _c)

	-- pow bigint and string
	_a = _bigint.new"2"
	_b = "4"
	_c = _bigint.new"16"
	_test.assert(_a ^ _b == _c)
end

_test["bigint.neg"] = function ()
	-- unm bigint
	local _a = _bigint.new"123456789012345678901234567890"
	local _b = _bigint.new"-123456789012345678901234567890"
	_test.assert(-_a == _b)
end


if not TEST then
	_test.summary()
end
