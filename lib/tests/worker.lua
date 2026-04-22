local test = TEST or require"u-test"
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

test["eli.worker available"] = function ()
	test.assert(worker.EWORKER)
end

test["worker copies args and results"] = function ()
	local input = {
		answer = 41,
		items = { 1, 2, 3 },
	}
	local task, err = worker.spawn([[
		local a, payload = ...
		payload.answer = payload.answer + 1
		payload.items[4] = a
		return payload.answer, payload
	]], 4, input)

	test.assert(task, err)

	local ok, answer, payload = task:join()
	test.assert(ok, answer)
	test.equal(answer, 42)
	test.equal(payload.answer, 42)
	test.equal(payload.items[1], 1)
	test.equal(payload.items[4], 4)
	test.equal(input.answer, 41)
	test.equal(#input.items, 3)
end

test["worker channels exchange messages"] = function ()
	local requests, err = worker.channel()
	test.assert(requests, err)
	local responses, response_err = worker.channel()
	test.assert(responses, response_err)

	local task, spawn_err = worker.spawn([[
		local req, res = ...
		local ok, message = req:recv()
		assert(ok, message)
		res:send(message .. ":pong")
		return message
	]], requests, responses)

	test.assert(task, spawn_err)

	local ok_send, send_err = requests:send"ping"
	test.assert(ok_send, send_err)

	local ok_recv, response = responses:recv()
	test.assert(ok_recv, response)
	test.equal(response, "ping:pong")

	local ok_join, original = task:join()
	test.assert(ok_join, original)
	test.equal(original, "ping")
end

test["worker rejects unsupported values"] = function ()
	local task, err = worker.spawn("return ...", function () end)
	test.is_nil(task)
	test.assert(type(err) == "string" and err:find("worker only supports", 1, true) ~= nil, err)
end

if not TEST then
	test.summary()
end
