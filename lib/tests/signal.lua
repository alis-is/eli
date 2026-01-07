local test = TEST or require"u-test"
local ok, signal = pcall(require, "os.signal")
local ok, eliProc = pcall(require, "eli.proc")

local isWindows = package.config:sub(1, 1) == "\\"

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

test["os.signal available"]       = function ()
	test.assert(true)
end

test["raise"]                     = function ()
	local catched = false

	signal.handle(signal.SIGTERM, function ()
		catched = true
	end)
	signal.raise(signal.SIGTERM)

	while not catched do
		os.sleep(1, "ms")
	end

	signal.reset(signal.SIGTERM)

	test.assert(catched, "signal not catched")
end

test["reset"]                     = function ()
	local ok, code = os.execute((os.getenv"QEMU" or "") ..
		" " .. arg[-1] .. " " .. path.combine("assets", "signal-reset.lua"))
	test.assert(not ok and code ~= 0, "signal catched")
end

test["out of process signal"]     = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch.lua") }
	end
	local p = eliProc.spawn(bin, args, { stdio = "inherit" })
	os.sleep(1, "s")
	p:kill(isWindows and signal.SIGBREAK or signal.SIGTERM)

	local code = p:wait()
	test.assert(code == 0, "signal not catched")
end

test["kill process"]              = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch.lua") }
	end
	local p = eliProc.spawn(bin, args, { stdio = "inherit" })
	os.sleep(1, "s")
	p:kill(signal.SIGKILL)

	local code = p:wait()
	test.assert(code ~= 0, "signal not catched")
end

test["process group"]             = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch.lua") }
	end
	local p = eliProc.spawn(bin, args, { stdio = "inherit", create_process_group = true })

	local g = p:get_group()
	assert(g, "process group not created")
	local p2 = eliProc.spawn(bin, args, { stdio = "inherit", process_group = g })
	os.sleep(3, "s")
	g:kill(signal.SIGINT)

	local code = p:wait()
	local code2 = p2:wait()
	test.assert(code == 0 and code2 == 0, "signal not catched")
end

test["windows ctrl events group"] = function ()
	if not isWindows then
		return
	end
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch-win.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch-win.lua") }
	end

	local p = eliProc.spawn(bin, args, { stdio = "inherit" })
	os.sleep(1, "s")

	p:kill(signal.SIGBREAK)

	local code = p:wait()
	test.assert(code == 0, "signal not catched")
end

test["kill group"]                = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch.lua") }
	end
	local p = eliProc.spawn(bin, args, { stdio = "inherit", create_process_group = true })
	local g = p:get_group()
	assert(g, "process group not created")
	local p2 = eliProc.spawn(bin, args, { stdio = "inherit", process_group = g })
	os.sleep(1, "s")
	g:kill(signal.SIGKILL)

	local code = p:wait()
	local code2 = p2:wait()
	test.assert(code ~= 0 and code2 ~= 0, "signal not catched")
end

test["process by pid"]            = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "signal-catch.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "signal-catch.lua") }
	end
	local p = eliProc.spawn(bin, args, { stdio = "inherit", create_process_group = true })

	local pid = p:get_pid()
	local pref = eliProc.get_by_pid(pid, { is_separate_process_group = true })

	local g = pref:get_group()
	assert(g, "process group not created")
	os.sleep(1, "s")
	g:kill(signal.SIGINT)

	local code = p:wait()
	test.assert(code == 0, "signal not catched")
end

if not TEST then
	test.summary()
end
