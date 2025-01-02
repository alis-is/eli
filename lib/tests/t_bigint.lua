local test = TEST or require"u-test"
local ok, bigint = pcall(require, "bigint")

if not ok then
	test["bigint available"] = function ()
		test.assert(false, "bigint not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["bigint available"] = function ()
	test.assert(true)
end

test["bigint.new"] = function ()
	-- bigint from float number (5.3 -> 5)
	local a = bigint.new(5.3)
	local b = bigint.new"5"
	test.assert(a == b)

	-- bigint from string "5.3" (should fail)
	local success, c = pcall(function () return bigint.new"5.3" end)
	test.assert(not success)

	-- bigint from integer number (5 -> 5)
	local d = bigint.new(5)
	test.assert(d == b)

	-- bigint from string "5" (5 -> 5)
	local e = bigint.new"5"
	test.assert(e == b)

	-- bigint from bigint 5 (5 -> 5)
	local f = bigint.new(b)
	test.assert(f == b)

	-- init with no param (0)
	local g = bigint.new()
	test.assert(g == bigint.new"0")
end

test["bigint.add"] = function ()
	-- add 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"123456789012345678901234567890"
	local c = bigint.new"246913578024691357802469135780"
	test.assert(a + b == c)

	-- add bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = 110
	c = bigint.new"123456789012345678901234568000"
	test.assert(a + b == c)

	-- add bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "110"
	c = bigint.new"123456789012345678901234568000"
	test.assert(a + b == c)
end

test["bigint.add_abs"] = function ()
	-- add 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"123456789012345678901234567890" * -1
	local c = bigint.new"246913578024691357802469135780"
	test.assert(bigint.add_abs(a, b) == c)

	-- add bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = -110
	c = bigint.new"123456789012345678901234568000"
	test.assert(bigint.add_abs(a, b) == c)

	-- add bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "-110"
	c = bigint.new"123456789012345678901234568000"
	test.assert(bigint.add_abs(a, b) == c)
end

test["bigint.sub"] = function ()
	-- sub 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"123456789012345678901234567890"
	local c = bigint.new"0"
	test.assert(a - b == c)

	-- sub bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = 110
	c = bigint.new"123456789012345678901234567780"
	test.assert(a - b == c)

	-- sub bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "110"
	c = bigint.new"123456789012345678901234567780"
	test.assert(a - b == c)
end

test["bigint.sub_abs"] = function ()
	-- sub 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"123456789012345678901234567890" * -1
	local c = bigint.new"0"
	test.assert(bigint.sub_abs(a, b) == c)

	-- sub bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = -110
	c = bigint.new"123456789012345678901234567780"
	test.assert(bigint.sub_abs(a, b) == c)

	-- sub bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "-110"
	c = bigint.new"123456789012345678901234567780"
	test.assert(bigint.sub_abs(a, b) == c)
end

test["bigint.mul"] = function ()
	-- mul 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"4"
	local c = bigint.new"493827156049382715604938271560"
	test.assert(a * b == c)

	-- mul bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = 4
	c = bigint.new"493827156049382715604938271560"
	test.assert(a * b == c)

	-- mul bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "4"
	c = bigint.new"493827156049382715604938271560"
	test.assert(a * b == c)
end

test["bigint.div"] = function ()
	-- div 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"4"
	local c = bigint.new"30864197253086419725308641972"
	test.assert(a / b == c)

	-- div bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = 4
	c = bigint.new"30864197253086419725308641972"
	test.assert(a / b == c)

	-- div bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "4"
	c = bigint.new"30864197253086419725308641972"
	test.assert(a / b == c)
end

test["bigint.mod"] = function ()
	-- mod 2 bigints
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"4"
	local c = bigint.new"2"
	test.assert(a % b == c)

	-- mod bigint and number
	a = bigint.new"123456789012345678901234567890"
	b = 4
	c = bigint.new"2"
	test.assert(a % b == c)

	-- mod bigint and string
	a = bigint.new"123456789012345678901234567890"
	b = "4"
	c = bigint.new"2"
	test.assert(a % b == c)
end

test["bigint.pow"] = function ()
	-- pow 2 bigints
	local a = bigint.new"2"
	local b = bigint.new"4"
	local c = bigint.new"16"
	test.assert(a ^ b == c)

	-- pow bigint and number
	a = bigint.new"2"
	b = 4
	c = bigint.new"16"
	test.assert(a ^ b == c)

	-- pow bigint and string
	a = bigint.new"2"
	b = "4"
	c = bigint.new"16"
	test.assert(a ^ b == c)
end

test["bigint.neg"] = function ()
	-- unm bigint
	local a = bigint.new"123456789012345678901234567890"
	local b = bigint.new"-123456789012345678901234567890"
	test.assert(-a == b)
end


if not TEST then
	test.summary()
end
