local test = TEST or require"u-test"
local path = require"eli.path"
local ok, worker = pcall(require, "eli.worker")

if not ok then
	test["eli.worker available"] = function ()
		test.assert(false, "eli.worker not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	end
	return
end

local worker_file = path.combine("assets", "worker-file.lua")

test["eli.worker available"] = function ()
	test.assert(worker.EWORKER)
end

test["worker spawns function jobs with context"] = function ()
	local input = {
		answer = 41,
		items = { 1, 2, 3 },
	}
	local task, err = worker.spawn(function (context)
		context.answer = context.answer + 1
		context.items[4] = context.answer
		return context.answer, context
	end, input)

	test.assert(task, err)

	local ok_join, answer, payload = task:join()
	test.assert(ok_join, answer)
	test.equal(answer, 42)
	test.equal(payload.answer, 42)
	test.equal(payload.items[1], 1)
	test.equal(payload.items[4], 42)
	test.equal(input.answer, 41)
	test.equal(#input.items, 3)
end

test["worker spawns file jobs"] = function ()
	local ok_wait, payload = worker.run(worker_file, {
		answer = 10,
		label = "file",
	})

	test.assert(ok_wait, payload)
	test.equal(payload.answer, 11)
	test.equal(payload.label, "file:done")
end

test["worker channels exchange messages"] = function ()
	local requests, err = worker.channel()
	test.assert(requests, err)
	local responses, response_err = worker.channel()
	test.assert(responses, response_err)

	local task, spawn_err = worker.spawn(function (context)
		local ok_recv, message = context.requests:recv()
		assert(ok_recv, message)
		context.responses:send(message .. ":pong")
		return message
	end, {
		requests = requests,
		responses = responses,
	})

	test.assert(task, spawn_err)

	local ok_send, send_err = requests:send"ping"
	test.assert(ok_send, send_err)

	local ok_recv, response = responses:recv()
	test.assert(ok_recv, response)
	test.equal(response, "ping:pong")

	local ok_join, original = task:wait()
	test.assert(ok_join, original)
	test.equal(original, "ping")
end

test["worker wait supports multiple tasks"] = function ()
	local gate, gate_err = worker.channel()
	test.assert(gate, gate_err)

	local blocked, blocked_err = worker.spawn(function (context)
		local ok_recv, message = context:recv()
		assert(ok_recv, message)
		return message
	end, gate)
	test.assert(blocked, blocked_err)

	local fast, fast_err = worker.spawn(function (context)
		return context.answer
	end, {
		answer = 173,
	})
	test.assert(fast, fast_err)

	local index, ok_wait, result = worker.wait({ blocked, fast })
	test.equal(index, 2)
	test.assert(ok_wait, result)
	test.equal(result, 173)

	local ok_send, send_err = gate:send"released"
	test.assert(ok_send, send_err)
	local ok_join, slow_result = blocked:wait()
	test.assert(ok_join, slow_result)
	test.equal(slow_result, "released")
end

test["worker rejects unsupported values"] = function ()
	local task, err = worker.spawn(function (context)
		return context
	end, function () end)
	test.is_nil(task)
	test.assert(type(err) == "string" and err:find("worker only supports", 1, true) ~= nil, err)
end

test["worker rejects closures with upvalues"] = function ()
	local suffix = ":captured"
	local task, err = worker.spawn(function (context)
		return context .. suffix
	end, "value")

	test.is_nil(task)
	test.equal(err, "worker functions cannot capture upvalues")
end

if not TEST then
	test.summary()
end
