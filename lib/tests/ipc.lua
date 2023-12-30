local test = TEST or require"u-test"
local ok, eliIpc = pcall(require, "eli.ipc")
local ok, eliProc = pcall(require, "eli.proc")

if not ok then
	test["eli.ipc available"] = function ()
		test.assert(false, "eli.ipc not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.ipc available"] = function ()
	test.assert(true)
end

test["ipc (in process)"] = function ()
	local serverBuffer = ""
	local dataReceived = false
	local thread = coroutine.create(function ()
		local server, err = eliIpc.listen("/tmp/test.sock", {
			data = function (socket, msg)
				serverBuffer = serverBuffer .. msg
				dataReceived = true
				socket:write"pong"
			end,
		}, {
			timeout = 500,
		})
		coroutine.yield(server, err)
	end)
	coroutine.resume(thread)

	local client, err = eliIpc.connect"/tmp/test.sock"
	test.assert(client, err)
	client:write"ping"

	local counter = 0
	while counter < 10 and not dataReceived do
		counter = counter + 1
		coroutine.resume(thread)
	end

	local data = client:read{ timeout = 1000 }
	test.assert(data == "pong")
	test.assert(serverBuffer == "ping")
end

test["ipc (cross process - server)"] = function ()
	local serverBuffer = ""
	local dataReceived = false
	local thread = coroutine.create(function ()
		local server, err = eliIpc.listen("/tmp/test.sock", {
			data = function (socket, msg)
				serverBuffer = serverBuffer .. msg
				dataReceived = true
				socket:write"pong"
			end,
		}, {
			timeout = 500,
		})
		coroutine.yield(server, err)
	end)
	coroutine.resume(thread)

	os.execute(arg[-1] .. " ./assets/ipc-client.lua")
	local counter = 0
	while counter < 10 and not dataReceived do
		counter = counter + 1
		coroutine.resume(thread)
	end

	test.assert(serverBuffer == "ping")
end

test["ipc (cross process - client)"] = function ()
	eliProc.spawn(arg[-1], { "./assets/ipc-server.lua" })
	os.sleep(1)
	local client, err = eliIpc.connect"/tmp/test.sock"
	test.assert(client, err)
	client:write"ping"

	local data = client:read{ timeout = 1000 }
	test.assert(data == "pong")
end

if not TEST then
	test.summary()
end
