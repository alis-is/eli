local test = TEST or require"u-test"
local worker = require"eli.worker"

test["worker teardown continues after unload hook failure"] = function ()
	local completed = worker.channel(1)
	local w = worker.spawn {
		environment = "lua",
		args = { completed },
		fn = function (completed)
			____UNLOAD_MODULE = {
				function () error("unload hook failure") end,
				function () completed:send("completed") end,
			}
		end,
	}
	local ok, err = w:join(1000)
	test.assert(ok == true, tostring(err))
	local value, received = completed:try_receive(1000)
	test.assert(received == true and value == "completed")
end

test["worker teardown handles failing global lookup"] = function ()
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			setmetatable(_G, {
				__index = function (_, key)
					if key == "____UNLOAD_MODULE" then
						error("unload table lookup failure")
					end
				end,
			})
		end,
	}
	local ok, err = w:join(1000)
	test.assert(ok == true, tostring(err))
end

if not TEST then
	test.summary()
end
