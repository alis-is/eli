local test = TEST or require"u-test"
local okIpc, eliIpc = pcall(require, "eli.ipc")
local okProc, eliProc = pcall(require, "eli.proc")

if not okIpc or not okProc then
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

test["ipc listener timeout and deterministic shutdown"] = function ()
	local core = require"ipc.core"
	local original = core.listen
	local servers = {}
	core.listen = function (...)
		local server, err = original(...)
		servers[#servers + 1] = server
		return server, err
	end
	local ok, err = pcall(function ()
		local polls = 0
		local started = os.time()
		test.assert(eliIpc.listen("/tmp/eli-ipc-stop.sock", {}, {
			timeout = 1100,
			is_stop_requested = function ()
				polls = polls + 1
				return polls > 1
			end,
		}))
		test.assert(os.time() - started >= 1, "listener ignored its poll timeout")
		test.assert(not servers[1]:process_events{}, "stopped listener is still open")

		local thread = coroutine.create(function ()
			eliIpc.listen("/tmp/eli-ipc-stop.sock", {})
		end)
		test.assert(coroutine.resume(thread))
		test.assert(coroutine.close(thread))
		test.assert(not servers[2]:process_events{}, "cancelled listener is still open")

		local completed = pcall(eliIpc.listen, "/tmp/eli-ipc-stop.sock", {}, {
			is_stop_requested = function () error"stop predicate failed" end,
		})
		test.assert(not completed)
		test.assert(not servers[3]:process_events{}, "failed listener is still open")
	end)
	core.listen = original
	for _, server in ipairs(servers) do server:close(true) end
	test.assert(ok, err)
end

test["ipc listener automatic close releases clients"] = function ()
	local core = require"ipc.core"
	local original = core.listen
	local server
	core.listen = function (...)
		server = original(...)
		return server
	end
	local accepted
	local client, connect_error
	local ok, err = pcall(function ()
		local thread = coroutine.create(function ()
			eliIpc.listen("/tmp/eli-ipc-autoclose.sock", {
				accept = function (socket) accepted = socket end,
			}, { timeout = 100 })
		end)
		test.assert(coroutine.resume(thread))
		client, connect_error = eliIpc.connect"/tmp/eli-ipc-autoclose.sock"
		test.assert(client, connect_error)
		test.assert(coroutine.resume(thread))
		test.assert(coroutine.close(thread))
	end)
	core.listen = original
	test.assert(ok, err)
	test.assert(accepted ~= nil, "server did not accept the client")
	test.assert(not accepted:write"x", "automatic close left the accepted client open")
	client:close()
end

test["ipc manually closed client releases its slot"] = function ()
	local accepted_a, accepted_b
	local got, got_socket
	local thread = coroutine.create(function ()
		local server, err = eliIpc.listen("/tmp/eli-ipc-slot.sock", {
			accept = function (socket)
				if accepted_a == nil then
					accepted_a = socket
				else
					accepted_b = socket
				end
			end,
			data = function (socket, msg)
				got = msg
				got_socket = socket
			end,
		}, { timeout = 100, max_clients = 1 })
		coroutine.yield(server, err)
	end)
	local _, server = coroutine.resume(thread)
	test.assert(server, "ipc server unavailable")
	local client_a = eliIpc.connect"/tmp/eli-ipc-slot.sock"
	test.assert(client_a, "client A connect failed")
	coroutine.resume(thread)
	test.assert(accepted_a, "client A was not accepted")
	accepted_a:close()
	local client_b = eliIpc.connect"/tmp/eli-ipc-slot.sock"
	test.assert(client_b, "client B connect failed")
	coroutine.resume(thread)
	test.assert(accepted_b, "closed client did not release its slot")
	client_b:write"hello"
	local tries = 0
	while not got and tries < 20 do
		tries = tries + 1
		coroutine.resume(thread)
	end
	server:close(true)
	client_a:close()
	client_b:close()
	test.assert(got == "hello", "client B data was not delivered")
	test.assert(got_socket == accepted_b, "data was delivered to the wrong socket")
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
	local _, server = coroutine.resume(thread)

	local client, err = eliIpc.connect"/tmp/test.sock"
	test.assert(client, err)
	client:write"ping"

	local counter = 0
	while counter < 10 and not dataReceived do
		counter = counter + 1
		coroutine.resume(thread)
	end

	server:close(true)
	local data = client:read{ timeout = 1000 }
	test.assert(data == "pong")
	test.assert(serverBuffer == "ping")
end

test["ipc broken peer releases the descriptor"] = function ()
	if path.default_sep() ~= "/" then return end
	local fs = require"eli.fs"
	local probe = fs.read_dir("/proc/self/fd")
	if type(probe) ~= "table" or #probe == 0 then return end

	local thread = coroutine.create(function ()
		local server, err = eliIpc.listen("/tmp/test.sock", {
			data = function () end,
		}, {
			timeout = 500,
		})
		coroutine.yield(server, err)
	end)
	local _, server = coroutine.resume(thread)
	test.assert(server, "ipc server unavailable")
	local client, err = eliIpc.connect"/tmp/test.sock"
	test.assert(client, err)
	coroutine.resume(thread)
	server:close(true)

	local function fd_count()
		collectgarbage"collect"
		local count = 0
		for _ in ipairs(fs.read_dir("/proc/self/fd")) do
			count = count + 1
		end
		return count
	end

	local before = fd_count()
	local payload = string.rep("x", 4096)
	local write_failed = false
	for _ = 1, 64 do
		if not client:write(payload) then
			write_failed = true
			break
		end
	end
	test.assert(write_failed, "write to a closed peer did not fail")
	local after = fd_count()
	client:close()
	test.assert(after == before - 1,
		("broken peer leaked the descriptor (%d -> %d)"):format(before, after))
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

	local _, server = coroutine.resume(thread)
	_cmd = (os.getenv"QEMU" or "") .. " " .. arg[-1] .. " " .. path.combine("assets", "ipc-client.lua")
	os.execute(_cmd)

	local counter = 0
	while counter < 10 and not dataReceived do
		counter = counter + 1
		coroutine.resume(thread)
	end

	server:close(true)
	test.assert(serverBuffer == "ping")
end

test["ipc (cross process - client)"] = function ()
	local bin = arg[-1]
	local args = { path.combine("assets", "ipc-server.lua") }
	if os.getenv"QEMU" or "" ~= "" then
		bin = os.getenv"QEMU" or ""
		args = { arg[-1], path.combine("assets", "ipc-server.lua") }
	end
	eliProc.spawn(bin, args)
	os.sleep(1, "s")
	local client, err = eliIpc.connect"/tmp/test.sock"
	test.assert(client, err)
	client:write"ping"

	local data = client:read{ timeout = 1000 }
	test.assert(data == "pong")
end

if not TEST then
	test.summary()
end
