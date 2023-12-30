local test = TEST or require"u-test"
local ok, signal = pcall(require, "os.signal")
local ok, eliProc = pcall(require, "eli.proc")

if not ok then
	test["os.signal available"] = function ()
		test.assert(false, "os.signal not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["os.signal available"] = function ()
	test.assert(true)
end

test["raise"] = function ()
	local catched = false

	signal.handle(signal.SIGTERM, function ()
		catched = true
	end)
	signal.raise(signal.SIGTERM)

	signal.reset(signal.SIGTERM)

	test.assert(catched, "signal not catched")
end

test["reset"] = function ()
	local ok, code = os.execute((os.getenv"QEMU" or "") ..
		" " .. arg[-1] .. " " .. path.combine("assets", "signal-reset.lua"))
	test.assert(not ok and code ~= 0, "signal catched")
end

test["out of process signal"] = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch.lua") }
	end
	local p = eliProc.spawn(bin, args, { stdio = "inherit" })
	os.sleep(1)
	p:kill(signal.SIGINT)

	local code = p:wait()
	test.assert(code == 0, "signal not catched")
end

if not TEST then
	test.summary()
end
