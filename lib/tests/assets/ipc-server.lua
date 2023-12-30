local ok, eliIpc = pcall(require, "eli.ipc")

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

while not dataReceived do
	coroutine.resume(thread)
end
