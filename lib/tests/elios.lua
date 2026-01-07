local test = TEST or require"u-test"
local ok, eli_os = pcall(require, "eli.os")

if not ok then
	test["eli.os available"] = function ()
		test.assert(false, "eli.os not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.os available"] = function ()
	test.assert(true)
end

if not eli_os.EOS then
	if not TEST then
		test.summary()
		print"EOS not detected, only basic tests executed..."
		os.exit()
	else
		print"EOS not detected, only basic tests executed..."
		return
	end
end

test["sleep"] = function ()
	local reference_point = os.date"%S"
	eli_os.sleep(5, "s")
	local after_sleep = os.date"%S"
	local diff = after_sleep - reference_point
	if diff < 0 then diff = diff + 60 end
	test.assert(diff > 3 and diff < 7)
end

test["chdir & cwd"] = function ()
	local cwd = eli_os.cwd()
	eli_os.chdir"tmp"
	local new_cwd = eli_os.cwd()
	test.assert(cwd ~= new_cwd)
	eli_os.chdir(cwd)
	new_cwd = eli_os.cwd()
	test.assert(cwd == new_cwd)
end

if not TEST then
	test.summary()
end
