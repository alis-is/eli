  
local _test = TEST or require 'u-test'
local _ok, _eliBigint = pcall(require, "eli.bigint")

if not _ok then 
    _test["eli.bigint available"] = function ()
        _test.assert(false, "eli.bigint not available")
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

_test["add"] = function ()
	-- add 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("123456789012345678901234567890")
	local _c = _eliBigint.new("246913578024691357802469135780")
	_test.assert(_a + _b == _c)	

	-- add bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = 110
	_c = _eliBigint.new("123456789012345678901234568000")
	_test.assert(_a + _b == _c)

	-- add bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "110"
	_c = _eliBigint.new("123456789012345678901234568000")
	_test.assert(_a + _b == _c)
end

_test["add_abs"] = function ()
	-- add 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("123456789012345678901234567890") * -1
	local _c = _eliBigint.new("246913578024691357802469135780")
	_test.assert(bigint.add_abs(_a, _b) == _c)

	-- add bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = -110
	_c = _eliBigint.new("123456789012345678901234568000")
	_test.assert(bigint.add_abs(_a, _b) == _c)

	-- add bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "-110"
	_c = _eliBigint.new("123456789012345678901234568000")
	_test.assert(bigint.add_abs(_a, _b) == _c)
end

_test["sub"] = function ()
	-- sub 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("123456789012345678901234567890")
	local _c = _eliBigint.new("0")
	_test.assert(_a - _b == _c)	

	-- sub bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = 110
	_c = _eliBigint.new("123456789012345678901234567780")
	_test.assert(_a - _b == _c)

	-- sub bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "110"
	_c = _eliBigint.new("123456789012345678901234567780")
	_test.assert(_a - _b == _c)
end

_test["sub_abs"] = function ()
	-- sub 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("123456789012345678901234567890") * -1
	local _c = _eliBigint.new("0")
	_test.assert(bigint.sub_abs(_a, _b) == _c)

	-- sub bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = -110
	_c = _eliBigint.new("123456789012345678901234567780")
	_test.assert(bigint.sub_abs(_a, _b) == _c)

	-- sub bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "-110"
	_c = _eliBigint.new("123456789012345678901234567780")
	_test.assert(bigint.sub_abs(_a, _b) == _c)
end

_test["mul"] = function ()
	-- mul 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("4")
	local _c = _eliBigint.new("493827156049382715604938271560")
	_test.assert(_a * _b == _c)

	-- mul bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = 4
	_c = _eliBigint.new("493827156049382715604938271560")
	_test.assert(_a * _b == _c)

	-- mul bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "4"
	_c = _eliBigint.new("493827156049382715604938271560")
	_test.assert(_a * _b == _c)
end

_test["div"] = function ()
	-- div 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("4")
	local _c = _eliBigint.new("30864197253086419725308641972")
	_test.assert(_a / _b == _c)

	-- div bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = 4
	_c = _eliBigint.new("30864197253086419725308641972")
	_test.assert(_a / _b == _c)

	-- div bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "4"
	_c = _eliBigint.new("30864197253086419725308641972")
	_test.assert(_a / _b == _c)
end

_test["mod"] = function ()
	-- mod 2 bigints
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("4")
	local _c = _eliBigint.new("2")
	_test.assert(_a % _b == _c)

	-- mod bigint and number
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = 4
	_c = _eliBigint.new("2")
	_test.assert(_a % _b == _c)

	-- mod bigint and string
	_a = _eliBigint.new("123456789012345678901234567890")
	_b = "4"
	_c = _eliBigint.new("2")
	_test.assert(_a % _b == _c)
end

_test["pow"] = function ()
	-- pow 2 bigints
	local _a = _eliBigint.new("2")
	local _b = _eliBigint.new("4")
	local _c = _eliBigint.new("16")
	_test.assert(_a ^ _b == _c)

	-- pow bigint and number
	_a = _eliBigint.new("2")
	_b = 4
	_c = _eliBigint.new("16")
	_test.assert(_a ^ _b == _c)

	-- pow bigint and string
	_a = _eliBigint.new("2")
	_b = "4"
	_c = _eliBigint.new("16")
	_test.assert(_a ^ _b == _c)
end

_test["neg"] = function ()
	-- unm bigint
	local _a = _eliBigint.new("123456789012345678901234567890")
	local _b = _eliBigint.new("-123456789012345678901234567890")
	_test.assert(-_a == _b)
end


if not TEST then 
    _test.summary()
end