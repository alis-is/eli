local test = TEST or require"u-test"

local ok, worker = pcall(require, "eli.worker")
local eli_os = ok and require"eli.os" or nil

local function wait_until_idle()
	for _ = 1, 500 do
		if worker.active_count() == 0 then return end
		eli_os.sleep(1)
	end
end

if not ok then
	test["eli.worker available"] = function ()
		test.assert(false, "eli.worker not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.worker available"] = function ()
	test.assert(type(worker.spawn) == "function")
	test.assert(type(worker.channel) == "function")
	test.assert(type(worker.mutex) == "function")
	test.assert(type(worker.active_count) == "function")
end

local function join_of(w)
	local r = table.pack(w:join())
	return r
end

test["plan example pipeline"] = function ()
	local jobs = worker.channel(8)
	local w = worker.spawn {
		environment = "lua",
		args = { jobs },
		fn = function (jobs)
			local total = 0
			while true do
				local job, job_ok = jobs:receive()
				if not job_ok then break end
				total = total + job.value
			end
			return total
		end,
	}
	test.assert(jobs:send{ value = 21 })
	test.assert(jobs:send{ value = 21 })
	jobs:close()
	local r = join_of(w)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == 42)
end

test["argument arity and trailing nils"] = function ()
	local w = worker.spawn {
		environment = "lua",
		args = table.pack(1, nil, 3),
		fn = function (...)
			return select("#", ...), ...
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == 3)
	test.assert(r[3] == 1)
	test.assert(r[4] == nil)
	test.assert(r[5] == 3)
end

test["sequence args"] = function ()
	local w = worker.spawn {
		environment = "lua",
		args = { "a", "b" },
		fn = function (a, b) return a .. b end,
	}
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == "ab")
end

test["transfer value types"] = function ()
	local w = worker.spawn {
		environment = "lua",
		args = {
			nil, true, false, 42, 2 ^ 53, "a\0b\255",
		},
		fn = function (a, b, c, d, e, f)
			return a, b, c, d, e, f,
			       math.type(d), math.type(e)
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == nil)
	test.assert(r[3] == true)
	test.assert(r[4] == false)
	test.assert(r[5] == 42)
	test.assert(r[6] == 2 ^ 53)
	test.assert(r[7] == "a\0b\255")
	test.assert(r[8] == "integer")
	test.assert(r[9] == "float")
end

test["cyclic tables and aliases"] = function ()
	local shared = { name = "shared" }
	local root = { a = shared, b = shared }
	root.self = root
	local w = worker.spawn {
		environment = "lua",
		args = { root },
		fn = function (r)
			return r.self == r, r.a == r.b
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == true)
	test.assert(r[3] == true)
end

test["cycles in results"] = function ()
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			local t = {}
			t.self = t
			t.list = { t, t }
			return t
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2].self == r[2])
	test.assert(r[2].list[1] == r[2])
	test.assert(r[2].list[2] == r[2])
end

test["deeply nested tables transfer"] = function ()
	local root = {}
	local cursor = root
	for _ = 1, 150 do
		cursor.child = {}
		cursor = cursor.child
	end
	local w = worker.spawn {
		environment = "lua",
		args = { root },
		fn = function (root)
			local depth = 0
			local cursor = root
			while cursor.child do
				cursor = cursor.child
				depth = depth + 1
			end
			local result = {}
			local result_cursor = result
			for _ = 1, 150 do
				result_cursor.child = {}
				result_cursor = result_cursor.child
			end
			return depth, result
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == 150)
	local depth = 0
	local cursor = r[3]
	while cursor.child do
		cursor = cursor.child
		depth = depth + 1
	end
	test.assert(depth == 150)
end

test["deep table with a userdata leaf transfers"] = function ()
	local leaf = worker.channel(0)
	local root = { leaf = leaf }
	for _ = 1, 199 do
		root = { child = root }
	end
	local w = worker.spawn {
		environment = "lua",
		args = { root, leaf },
		fn = function (root, direct)
			local depth = 0
			local cursor = root
			while cursor.child do
				cursor = cursor.child
				depth = depth + 1
			end
			return depth, cursor.leaf == direct
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == 199 and r[3] == true)
	leaf:close()
end

test["overly deep transfer fails without crashing"] = function ()
	local root = {}
	local cursor = root
	for _ = 1, 300 do
		cursor.child = {}
		cursor = cursor.child
	end
	local ok, err = pcall(worker.spawn, {
		environment = "lua",
		args = { root },
		fn = function () return 1 end,
	})
	test.assert(ok == false and tostring(err):find("deep", 1, true))
end

test["deep table chain closing back to root"] = function ()
	local root = {}
	local cursor = root
	for _ = 1, 199 do
		cursor.child = {}
		cursor = cursor.child
	end
	cursor.root = root
	local w = worker.spawn {
		environment = "lua",
		args = { root },
		fn = function (root)
			local depth = 0
			local cursor = root
			while cursor.child do
				cursor = cursor.child
				depth = depth + 1
			end
			return depth, cursor.root == root
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == 199 and r[3] == true)
end

test["function environment binds to destination globals"] = function ()
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			return function () return WORKER_TEST_GLOBAL end
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	WORKER_TEST_GLOBAL = 99
	test.assert(r[2]() == 99)
	WORKER_TEST_GLOBAL = nil
end

test["reject captured locals"] = function ()
	local captured = 1
	local ok, err = pcall(worker.spawn, {
		environment = "lua",
		fn = function () return captured end,
	})
	test.assert(ok == false and type(err) == "string")
	test.assert(tostring(err):find("captured", 1, true))
end

test["reject custom _ENV"] = function ()
	local f = load("return marker", "chunk", "t", { marker = 5 })
	local ok, err = pcall(worker.spawn, { environment = "lua", fn = f })
	test.assert(ok == false and type(err) == "string")
	test.assert(tostring(err):find("_ENV", 1, true))
end

test["reject C functions"] = function ()
	local ok, err = pcall(worker.spawn, { environment = "lua", fn = print })
	test.assert(ok == false and type(err) == "string")
	test.assert(tostring(err):find("C function", 1, true))
end

test["reject coroutines and userdata"] = function ()
	local ok, err = pcall(worker.spawn, {
		environment = "lua",
		args = { coroutine.create(function () end) },
		fn = function () return 1 end,
	})
	test.assert(ok == false and type(err) == "string")
	test.assert(tostring(err):find("thread", 1, true))

	ok, err = pcall(worker.spawn, {
		environment = "lua",
		args = { io.stdout },
		fn = function () return 1 end,
	})
	test.assert(ok == false and type(err) == "string")
	test.assert(tostring(err):find("adapter", 1, true))
end

test["reject tables with metatables"] = function ()
	local ok, err = pcall(worker.spawn, {
		environment = "lua",
		args = { setmetatable({}, { __index = {} }) },
		fn = function () return 1 end,
	})
	test.assert(ok == false and type(err) == "string")
	test.assert(tostring(err):find("metatable", 1, true))
end

test["environment: independent globals"] = function ()
	_G.WORKER_PARENT_MARKER = "parent"
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			_G.WORKER_PARENT_MARKER = "worker"
			return WORKER_PARENT_MARKER
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == "worker")
	test.assert(_G.WORKER_PARENT_MARKER == "parent")
	_G.WORKER_PARENT_MARKER = nil
end

test["environment: independent module state"] = function ()
	local module = require"eli.util"
	module.__worker_probe = "main"
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			local m = require"eli.util"
			m.__worker_probe = "worker"
			return m.__worker_probe
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == "worker")
	test.assert(module.__worker_probe == "main")
	module.__worker_probe = nil
end

test["environment: eli copies metadata"] = function ()
	local w = worker.spawn {
		environment = "eli",
		fn = function ()
			return type(path), type(util), type(env), ELI_VERSION,
			       arg ~= nil
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == "table", "eli convenience globals missing")
	test.assert(r[3] == "table")
	test.assert(r[4] == "table")
	test.assert(type(r[5]) == "string")
	test.assert(r[6] == true)
end

test["environment: eli keeps the os.exit guard"] = function ()
	local w = worker.spawn {
		environment = "eli",
		fn = function ()
			local original_os =
			   require"eli.elify".get_overriden_values().os
			if type(original_os) ~= "table" then
				return "no override captured"
			end
			return pcall(original_os.exit, 0)
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == false or r[2] == "no override captured")
end

test["environment: empty"] = function ()
	local w = worker.spawn {
		environment = "empty",
		fn = function () return _G == _ENV, print == nil end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == true)
	test.assert(r[3] == true)
end

test["environment: table"] = function ()
	local w = worker.spawn {
		environment = { value = 5, helper = function () return 7 end },
		fn = function () return value, helper(), _G.value end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == 5)
	test.assert(r[3] == 7)
	test.assert(r[4] == 5)
end

test["environment: table preserves root aliases"] = function ()
	local environment = { value = 5 }
	environment.self = environment
	environment.nested = { environment }
	local w = worker.spawn {
		environment = environment,
		fn = function ()
			return self == _G, nested[1] == _G, value
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == true and r[3] == true and r[4] == 5)
end

test["os.exit fails with worker error"] = function ()
	local w = worker.spawn {
		environment = "lua",
		fn = function () os.exit(0) end,
	}
	local r = join_of(w)
	test.assert(r[1] == false)
	test.assert(type(r[2]) == "string")
	test.assert(r[2]:find("os.exit", 1, true))
end

test["worker traceback on error"] = function ()
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			local function explode() error("worker boom") end
			explode()
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == false)
	test.assert(type(r[2]) == "string")
	test.assert(r[2]:find("worker boom", 1, true))
end

test["join timeout, repeated joins and polling"] = function ()
	local gate = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { gate },
		fn = function (gate)
			local value = gate:receive()
			return value * 2
		end,
	}
	local r = table.pack(w:join(0))
	test.assert(r[1] == false and r[2] == "timeout")
	-- poll again with a timeout
	local ok2, err2 = w:join(30)
	test.assert(ok2 == false and err2 == "timeout")
	test.assert(gate:send(21))
	local r2 = join_of(w)
	test.assert(r2[1] == true and r2[2] == 42)
	local r3 = join_of(w)
	test.assert(r3[1] == true and r3[2] == 42)
end

test["dropped worker handle is safe"] = function ()
	local gate = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { gate },
		fn = function (gate) return gate:receive() end,
	}
	w = nil
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(gate:send"still alive")
	-- no join available; wait until the detached worker has finished
	wait_until_idle()
	test.assert(worker.active_count() == 0)
end

test["finalizing a handle during join decode is safe"] = function ()
	local fixture = require"eli.worker.test"
	local w = worker.spawn {
		environment = "lua",
		fn = function ()
			require"eli.worker"
			return require"eli.worker.test".box(7)
		end,
	}
	-- The hook runs while join is decoding the results; finalizing the handle
	-- there used to free the packet still being read.
	fixture.set_import_hook(function ()
		fixture.set_import_hook(nil)
		getmetatable(w).__gc(w)
	end)
	local r = join_of(w)
	fixture.set_import_hook(nil)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(fixture.value(r[2]) == 7)
end

test["invalid timeouts are rejected"] = function ()
	local ch = worker.channel(1)
	local w = worker.spawn { fn = function () return true end }
	for _, value in ipairs { -1, 0 / 0, math.huge, -math.huge, 2 ^ 63 } do
		local received, receive_error = pcall(ch.try_receive, ch, value)
		local sent, send_error = pcall(ch.try_send, ch, true, value)
		local joined, join_error = pcall(w.join, w, value)
		test.assert(not received and tostring(receive_error):find("timeout", 1, true))
		test.assert(not sent and tostring(send_error):find("timeout", 1, true))
		test.assert(not joined and tostring(join_error):find("timeout", 1, true))
	end
	test.assert(w:join())
	ch:close()
end

test["finalizing an in-progress constructor is rejected"] = function ()
	for _, raise in ipairs { false, true } do
		local finalized
		local args = setmetatable({}, { __index = function (_, key)
			test.assert(key == "n")
			local _, handle = debug.getlocal(2, 5)
			test.assert(type(handle) == "userdata")
			finalized = handle
			getmetatable(handle).__gc(handle)
			getmetatable(handle).__gc(handle)
			collectgarbage"collect"
			if raise then error("constructor callback failed") end
			return 0
		end })
		local spawned, err = pcall(worker.spawn, {
			fn = function () return true end,
			args = args,
		})
		test.assert(finalized ~= nil, "constructor callback did not run")
		test.assert(not spawned and tostring(err):find(
			raise and "constructor callback failed" or "finalized", 1, true), tostring(err))
		local joined, join_error = pcall(finalized.join, finalized)
		test.assert(not joined and tostring(join_error):find("finalized", 1, true))
	end
end

test["joining an in-progress constructor is rejected"] = function ()
	local join_error
	local args = setmetatable({}, { __index = function (_, key)
		test.assert(key == "n")
		local _, handle = debug.getlocal(2, 5)
		test.assert(type(handle) == "userdata")
		local joined, err = pcall(handle.join, handle)
		join_error = err
		test.assert(not joined, "constructor join must not wait")
		return 0
	end })
	local spawned, handle = pcall(worker.spawn, {
		fn = function () return 1 end,
		args = args,
	})
	test.assert(spawned, handle)
	test.assert(tostring(join_error):find("not started", 1, true), tostring(join_error))
	local r = join_of(handle)
	test.assert(r[1] == true, tostring(r[2]))
	test.assert(r[2] == 1)
end

test["spawn validation errors"] = function ()
	local ok1, err1 = pcall(worker.spawn, {})
	test.assert(not ok1 and tostring(err1):find("fn", 1, true))
	local ok2 = pcall(worker.spawn, { fn = function () end, environment = "nope" })
	test.assert(not ok2)
	local ok3 = pcall(worker.spawn, { fn = function () end, args = "nope" })
	test.assert(not ok3)
	local ok4 = pcall(worker.spawn, { fn = function () end, environment = 3 })
	test.assert(not ok4)
	local ok5, err5 = pcall(worker.spawn, {
		environment = "lua",
		fn = function () return 1 end,
	}, function () return 2 end)
	test.assert(not ok5 and tostring(err5):find("single options table", 1, true))
end

-- ------------------------------------------------------------------ channels

test["unbuffered rendezvous"] = function ()
	local ch = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { ch },
		fn = function (ch)
			local value, got = ch:receive()
			return value, got
		end,
	}
	test.assert(ch:send(7))
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == 7 and r[3] == true)
end

test["buffered fifo and close semantics"] = function ()
	local ch = worker.channel(3)
	test.assert(ch:send(1))
	test.assert(ch:send(2))
	test.assert(ch:send(3))
	local ok, err = ch:try_send(4)
	test.assert(ok == false and err == "timeout")
	ch:close()
	local a = ch:receive()
	local b = ch:receive()
	local c = ch:receive()
	local d, okd, why = ch:receive()
	test.assert(a == 1 and b == 2 and c == 3)
	test.assert(d == nil and okd == false and why == "closed")
	local sent, send_err = ch:try_send(5)
	test.assert(sent == false and send_err == "closed")
	ch:close() -- idempotent
end

test["closed channel does not deliver blocked sends"] = function ()
	local ch = worker.channel(1)
	test.assert(ch:send"first")
	local w = worker.spawn {
		environment = "lua",
		args = { ch },
		fn = function (ch)
			local ok, err = ch:send"blocked"
			return ok, err
		end,
	}
	eli_os.sleep(50)
	ch:close()
	local value, got = ch:receive()
	test.assert(value == "first" and got == true)
	local v2, got2, why = ch:receive()
	test.assert(v2 == nil and got2 == false and why == "closed")
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == false and r[3] == "closed")
end

test["nil messages are values"] = function ()
	local ch = worker.channel(1)
	test.assert(ch:send(nil))
	local value, got = ch:receive()
	test.assert(value == nil and got == true)
end

test["try_receive distinguishes timeout from closed"] = function ()
	local ch = worker.channel(0)
	local value, got, why = ch:try_receive(10)
	test.assert(value == nil and got == false and why == "timeout")
	ch:close()
	local value2, got2, why2 = ch:try_receive(10)
	test.assert(value2 == nil and got2 == false and why2 == "closed")
	local value3, got3, why3 = ch:try_receive()
	test.assert(value3 == nil and got3 == false and why3 == "closed")
end

test["timed out send is not delivered later"] = function ()
	local ch = worker.channel(1)
	test.assert(ch:send(1))
	local ok, why = ch:try_send(2, 20)
	test.assert(ok == false and why == "timeout")
	local value = ch:receive()
	test.assert(value == 1)
	local nope = ch:try_receive(0)
	test.assert(nope == nil)
end

test["multiple producers through one channel"] = function ()
	local results = worker.channel(16)
	local workers = {}
	for i = 1, 4 do
		workers[i] = worker.spawn {
			environment = "lua",
			args = { results, i },
			fn = function (results, id)
				for n = 1, 10 do
					results:send(id * 100 + n)
				end
			end,
		}
	end
	local total = 0
	for _ = 1, 40 do
		local value = results:receive()
		if value == nil then
			test.assert(false, "channel closed too early")
			return
		end
		total = total + (value % 100)
	end
	test.assert(total == 220)
	results:close()
	for _, w in ipairs(workers) do
		local r = join_of(w)
		test.assert(r[1] == true)
	end
end

test["multiple waiting consumers receive distinct jobs"] = function ()
	local jobs = worker.channel(0)
	local ready = worker.channel(2)
	local results = worker.channel(2)
	local workers = {}
	for id = 1, 2 do
		workers[id] = worker.spawn {
			environment = "lua",
			args = { jobs, ready, results, id },
			fn = function (jobs, ready, results, id)
				ready:send(id)
				local job, received = jobs:receive()
				if received then results:send { id = id, job = job } end
			end,
		}
	end
	ready:receive()
	ready:receive()
	test.assert(jobs:send"first")
	test.assert(jobs:send"second")
	local first = results:receive()
	local second = results:receive()
	test.assert(first.id ~= second.id)
	test.assert(first.job ~= second.job)
	jobs:close()
	ready:close()
	results:close()
	for _, w in ipairs(workers) do
		test.assert(join_of(w)[1] == true)
	end
end

test["channels through arguments and messages"] = function ()
	local pipe = worker.channel(0)
	local payload = worker.channel(1)
	local w = worker.spawn {
		environment = "lua",
		args = { pipe, payload },
		fn = function (pipe, payload)
			local target = pipe:receive()
			target:send("hello from worker")
		end,
	}
	test.assert(pipe:send(payload))
	local value = payload:receive()
	test.assert(value == "hello from worker")
	local r = join_of(w)
	test.assert(r[1] == true)
end

test["channel identity is preserved in a transfer"] = function ()
	local ch = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { { a = ch, b = ch } },
		fn = function (t) return t.a == t.b end,
	}
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == true)
end

test["finalizing a channel during send is rejected"] = function ()
	local ch = worker.channel(1)
	-- call 1: pcall, 2: the protected function, 3: send, 4: encode
	local count = 0
	debug.sethook(function ()
		count = count + 1
		if count == 4 then
			debug.sethook()
			getmetatable(ch).__gc(ch)
		end
	end, "c")
	local ok, err = pcall(function () return ch:send("hello") end)
	debug.sethook()
	test.assert(count == 4, "hook did not observe the encode call")
	test.assert(ok == false and tostring(err):find("finalized", 1, true),
		tostring(err))
end

test["unreachable channel cycles are reclaimed"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	collectgarbage"collect"
	local before = fixture.channel_count()
	local a = worker.channel(1)
	local b = worker.channel(1)
	a:send(b)
	b:send(a)
	a:close()
	b:close()
	a = nil
	b = nil
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(fixture.channel_count() == before)
end

test["self-referential channel is reclaimed"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	collectgarbage"collect"
	local before = fixture.channel_count()
	local ch = worker.channel(1)
	ch:send(ch)
	ch:close()
	ch = nil
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(fixture.channel_count() == before)
end

test["to-be-closed channel releases at scope exit"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	local before = fixture.channel_count()
	do
		local ch <close> = worker.channel(1)
		test.assert(fixture.channel_count() == before + 1)
	end
	test.assert(fixture.channel_count() == before)
end

test["rooted channel cycle remains usable"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	collectgarbage"collect"
	local before = fixture.channel_count()
	local a = worker.channel(1)
	local b = worker.channel(1)
	a:send(b)
	b:send(a)
	b = nil
	collectgarbage"collect"
	test.assert(fixture.channel_count() == before + 2)
	local received = a:receive()
	test.assert(received ~= nil)
	received:close()
	a:close()
	a = nil
	received = nil
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(fixture.channel_count() == before)
end

test["bulk channel transfer releases all references"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	collectgarbage"collect"
	local before = fixture.channel_count()
	local hub = worker.channel(1)
	local channels = {}
	for i = 1, 256 do channels[i] = worker.channel(1) end
	test.assert(hub:send(channels))
	local received = hub:receive()
	hub:close()
	test.assert(type(received) == "table" and #received == 256)
	hub = nil
	channels = nil
	received = nil
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(fixture.channel_count() == before)
end

-- --------------------------------------------------------------------- locks

test["mutex lock, try_lock and unlock"] = function ()
	local m = worker.mutex()
	test.assert(type(m) == "userdata")
	test.assert(m:lock())
	test.assert(m:try_lock() == false)
	local relocked, relock_error = pcall(m.lock, m)
	test.assert(relocked == false)
	test.assert(tostring(relock_error):find("locked", 1, true))
	test.assert(m:unlock())
	local unlocked, unlock_error = pcall(m.unlock, m)
	test.assert(unlocked == false)
	test.assert(tostring(unlock_error):find("locked", 1, true))
	test.assert(m:try_lock())
	test.assert(m:unlock())
end

test["mutex excludes another thread"] = function ()
	local m = worker.mutex()
	local holding = worker.channel(0)
	local release = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { m, holding, release },
		fn = function (m, holding, release)
			assert(m:lock())
			holding:send(true)
			release:receive()
			assert(m:unlock())
			local got = m:try_lock()
			if got then m:unlock() end
			return got
		end,
	}
	test.assert(holding:receive() == true)
	test.assert(m:try_lock() == false)
	test.assert(release:send(true))
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == true)
	test.assert(m:try_lock())
	test.assert(m:unlock())
end

test["blocked lock waits for release"] = function ()
	local m = worker.mutex()
	local holding = worker.channel(0)
	local release = worker.channel(0)
	local holder = worker.spawn {
		environment = "lua",
		args = { m, holding, release },
		fn = function (m, holding, release)
			assert(m:lock())
			holding:send(true)
			release:receive()
			assert(m:unlock())
			return true
		end,
	}
	test.assert(holding:receive() == true)
	local waiter = worker.spawn {
		environment = "lua",
		args = { m },
		fn = function (m)
			assert(m:lock())
			assert(m:unlock())
			return true
		end,
	}
	eli_os.sleep(20)
	local pending = table.pack(waiter:join(0))
	test.assert(pending[1] == false and pending[2] == "timeout")
	test.assert(release:send(true))
	test.assert(join_of(holder)[1] == true)
	test.assert(join_of(waiter)[1] == true)
end

test["mutex unlock requires the owning thread"] = function ()
	local m = worker.mutex()
	test.assert(m:lock())
	local w = worker.spawn {
		environment = "lua",
		args = { m },
		fn = function (m)
			local unlocked, err = pcall(m.unlock, m)
			return unlocked, tostring(err)
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == false and r[3]:find("locked", 1, true), tostring(r[3]))
	test.assert(m:unlock())
end

test["mutexes pass through channels"] = function ()
	local out = worker.channel(0)
	local m = worker.mutex()
	local w = worker.spawn {
		environment = "lua",
		args = { out },
		fn = function (out)
			local m = out:receive()
			local locked = m:try_lock()
			if locked then m:unlock() end
			out:send(m)
			return locked
		end,
	}
	test.assert(out:send(m))
	local back = out:receive()
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == true)
	-- the worker imported the same native mutex
	test.assert(m:try_lock())
	test.assert(back:try_lock() == false)
	test.assert(m:unlock())
	test.assert(back:try_lock())
	test.assert(back:unlock())
	out:close()
end

test["mutex identity is preserved in a transfer"] = function ()
	local m = worker.mutex()
	local w = worker.spawn {
		environment = "lua",
		args = { { a = m, b = m } },
		fn = function (t) return t.a == t.b, t.a:try_lock() end,
	}
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == true and r[3] == true)
end

test["mutexes created in workers reach the main state"] = function ()
	local out = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { out },
		fn = function (out)
			out:send { mutex = require"eli.worker".mutex() }
			return true
		end,
	}
	local received = out:receive()
	test.assert(received.mutex:try_lock())
	test.assert(received.mutex:unlock())
	local r = join_of(w)
	test.assert(r[1] == true)
	out:close()
end

test["finalized mutexes are reclaimed"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	collectgarbage"collect"
	local before = fixture.mutex_count()
	do
		local m = worker.mutex()
		test.assert(fixture.mutex_count() == before + 1)
		test.assert(m:lock())
		test.assert(m:unlock())
	end
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(fixture.mutex_count() == before)
end

test["mutex box tracks its own acquisition"] = function ()
	local hub = worker.channel(1)
	local m = worker.mutex()
	test.assert(hub:send(m))
	local box = hub:receive()
	test.assert(type(box) == "userdata" and box ~= m)
	test.assert(m:lock())
	local unlocked, unlock_error = pcall(box.unlock, box)
	test.assert(unlocked == false and tostring(unlock_error):find("locked", 1, true))
	test.assert(box:try_lock() == false)
	test.assert(m:unlock())
	test.assert(box:try_lock())
	test.assert(box:unlock())
	hub:close()
end

test["worker exit releases its held mutex"] = function ()
	local m = worker.mutex()
	local held = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { m, held },
		fn = function (m, held)
			assert(m:lock())
			held:send(true)
			return true
		end,
	}
	test.assert(held:receive() == true)
	local r = join_of(w)
	test.assert(r[1] == true)
	-- the worker state teardown unlocked the box it still held
	test.assert(m:try_lock())
	test.assert(m:unlock())
end

test["to-be-closed mutex unlocks at scope exit"] = function ()
	local m = worker.mutex()
	local locked = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { m, locked },
		fn = function (m, locked)
			local scoped <close> = m
			assert(scoped:lock())
			locked:send(true)
			return true
		end,
	}
	test.assert(locked:receive() == true)
	local r = join_of(w)
	test.assert(r[1] == true)
	-- the worker's __close released the lock on scope exit
	test.assert(m:try_lock())
	test.assert(m:unlock())
end

test["to-be-closed mutex unlocks on error"] = function ()
	local m = worker.mutex()
	local w = worker.spawn {
		environment = "lua",
		args = { m },
		fn = function (m)
			local scoped <close> = m
			assert(scoped:lock())
			error("boom")
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == false and tostring(r[2]):find("boom", 1, true))
	test.assert(m:try_lock())
	test.assert(m:unlock())
end

test["bulk mutex transfer releases all references"] = function ()
	local fixture = require"eli.worker.test"
	collectgarbage"collect"
	collectgarbage"collect"
	local before = fixture.mutex_count()
	local hub = worker.channel(1)
	local mutexes = {}
	for i = 1, 64 do mutexes[i] = worker.mutex() end
	test.assert(hub:send(mutexes))
	local received = hub:receive()
	hub:close()
	test.assert(type(received) == "table" and #received == 64)
	hub = nil
	mutexes = nil
	received = nil
	collectgarbage"collect"
	collectgarbage"collect"
	test.assert(fixture.mutex_count() == before)
end

-- ------------------------------------------------------------------- adapter

test["adapter fixture round trip"] = function ()
	local fixture = require"eli.worker.test"
	local box = fixture.box(41)
	local w = worker.spawn {
		environment = "lua",
		args = { box },
		fn = function (box)
			return require"eli.worker" and box
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(fixture.value(r[2]) == 41)
end

test["adapter identity within a transfer"] = function ()
	local fixture = require"eli.worker.test"
	local box = fixture.box(5)
	local w = worker.spawn {
		environment = "lua",
		args = { { x = box, y = box } },
		fn = function (t) return t.x == t.y, t.x end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == true)
	test.assert(fixture.value(r[3]) == 5)
end

test["adapter import failure releases the packet and preserves the channel"] = function ()
	local fixture = require"eli.worker.test"
	local ch = worker.channel(2)
	test.assert(ch:send(fixture.box(1)))
	test.assert(ch:send(fixture.box(2)))
	fixture.set_import_hook(function () error"adapter import aborted" end)
	local ok, err = pcall(ch.receive, ch)
	fixture.set_import_hook(nil)
	test.assert(ok == false and tostring(err):find("adapter import aborted", 1, true))
	local box, received = ch:receive()
	test.assert(received == true and fixture.value(box) == 2)
	ch:close()
end

test["workers use TLS while the main state serves IPC"] = function ()
	if package.config:sub(1, 1) ~= "/" then return end
	local proc = require"eli.proc"
	local ipc = require"eli.ipc"
	local python = proc.spawn("python3", { "-c", "import ssl" }, { wait = true })
	if not python or python.exit_code ~= 0 then return end
	local openssl = proc.spawn("openssl", { "version" }, { wait = true })
	if not openssl or openssl.exit_code ~= 0 then return end

	local tls_server = assert(proc.spawn("python3", { "assets/tls-ipc-server.py" }))
	local cleanup <close> = setmetatable({}, { __close = function ()
		pcall(function ()
			if not tls_server:exited() then tls_server:kill() end
			tls_server:wait()
		end)
	end })
	local port = tonumber(tls_server:get_stdout():read"l")
	test.assert(port, "TLS fixture did not report a port")
	local endpoint = os.tmpname()
	os.remove(endpoint)
	endpoint = endpoint .. ".sock"
	local received = {}
	local stop = false
	local listener = coroutine.create(function ()
		ipc.listen(endpoint, {
			data = function (_, message) received[message] = true end,
		}, {
			timeout = 50,
			is_stop_requested = function () return stop end,
		})
	end)
	local resumed, server = coroutine.resume(listener)
	test.assert(resumed and server, tostring(server))

	local workers = {}
	for id = 1, 2 do
		workers[id] = worker.spawn {
			environment = "lua",
			args = { port, endpoint, id },
			fn = function (port, endpoint, id)
				local socket = require"socket"
				local ipc = require"eli.ipc"
				local connection <close> = assert(socket.connect("127.0.0.1", port, "tls", {
					verify_peer = false,
					use_bundled_root_certificates = false,
					connect_timeout = 2000,
					read_timeout = 2000,
					write_timeout = 2000,
				}))
				connection:write(tostring(id))
				local reply = connection:read(16)
				local client = assert(ipc.connect(endpoint))
				client:write("tls-" .. id)
				client:close()
				return reply
			end,
		}
	end
	for _ = 1, 100 do
		if received["tls-1"] and received["tls-2"] then break end
		local ok, err = coroutine.resume(listener)
		test.assert(ok, tostring(err))
	end
	stop = true
	local ok, err = coroutine.resume(listener)
	test.assert(ok, tostring(err))
	for id, w in ipairs(workers) do
		local result = join_of(w)
		test.assert(result[1] == true and result[2] == "ok:" .. id, tostring(result[2]))
	end
	test.assert(received["tls-1"] and received["tls-2"])
	test.assert(tls_server:wait() == 0)
end

-- -------------------------------------------------------------------- locale

test["locale guard while workers are active"] = function ()
	local gate = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { gate },
		fn = function (g) return g:receive() end,
	}
	local previous = os.setlocale(nil)
	test.assert(type(previous) == "string" or previous == nil)
	local ok, err = pcall(os.setlocale, "C")
	test.assert(ok == false)
	test.assert(tostring(err):find("locale", 1, true))
	test.assert(gate:send(1))
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(os.setlocale(nil)) -- query passes through while idle
	os.setlocale(previous)
end

test["locale query forwards many arguments"] = function ()
	local args = {}
	for i = 1, 5000 do
		args[i] = i
	end
	local ok, result = pcall(os.setlocale, nil, "all", table.unpack(args))
	test.assert(ok == true, tostring(result))
	test.assert(type(result) == "string" or result == nil)
end

test["spawning from inside os.setlocale is rejected"] = function ()
	local count = 0
	local spawned, spawn_error
	debug.sethook(function ()
		count = count + 1
		if count == 2 then
			debug.sethook()
			spawned, spawn_error = worker.spawn {
				environment = "lua",
				fn = function () return 1 end,
			}
		end
	end, "c")
	local result = os.setlocale("C")
	debug.sethook()
	test.assert(count == 2, "hook did not observe the guarded call")
	test.assert(result ~= nil)
	test.assert(spawned == nil and
		tostring(spawn_error):find("setlocale", 1, true),
		tostring(spawn_error))
	test.assert(worker.active_count() == 0)
end

test["active worker count"] = function ()
	wait_until_idle()
	test.assert(worker.active_count() == 0)
	local gate = worker.channel(0)
	local w = worker.spawn {
		environment = "lua",
		args = { gate },
		fn = function (g)
			g:receive()
			return true
		end,
	}
	test.assert(worker.active_count() == 1)
	test.assert(gate:send(true))
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(worker.active_count() == 0)
end

-- ------------------------------------------------------- shared process state

test["shared environment and os.getenv routing"] = function ()
	local eli_env = require"eli.env"
	eli_env.set_env("ELI_WORKER_TEST_ENV", "from-main")
	local w = worker.spawn {
		environment = "eli",
		fn = function ()
			local observed = os.getenv("ELI_WORKER_TEST_ENV")
			env.set_env("ELI_WORKER_TEST_ENV_2", "from-worker")
			return observed
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true and r[2] == "from-main", tostring(r[2]))
	test.assert(os.getenv("ELI_WORKER_TEST_ENV_2") == "from-worker")
	eli_env.set_env("ELI_WORKER_TEST_ENV", nil)
	eli_env.set_env("ELI_WORKER_TEST_ENV_2", nil)
end

test["concurrent popen close and descriptor reuse"] = function ()
	if require"eli.path".default_sep() ~= "/" then return end
	local workers = {}
	for i = 1, 4 do
		workers[i] = worker.spawn {
			environment = "lua",
			fn = function ()
				for _ = 1, 200 do
					local f = assert(io.popen("printf shell; exit 9"))
					assert(f:read"a" == "shell")
					local ok, kind, code = f:close()
					assert(ok == nil and kind == "exit" and code == 9)
				end
			end,
		}
	end
	local failure
	for _, w in ipairs(workers) do
		local ok, err = w:join(30000)
		if not ok then failure = tostring(err) end
	end
	assert(failure == nil, failure)
end

test["shell launches during environment growth"] = function ()
	if require"eli.path".default_sep() ~= "/" then return end
	local gate = worker.channel(0)
	local mutator = worker.spawn {
		environment = "lua", args = { gate },
		fn = function (gate)
			local env = os
			gate:receive()
			for i = 1, 2000 do
				assert(env.set_env("ELI_SHELL_RACE_" .. i, string.rep("x", i % 128)))
			end
			for i = 1, 2000 do assert(env.set_env("ELI_SHELL_RACE_" .. i, nil)) end
		end,
	}
	local function launch()
		assert(os.execute() == true)
		for _ = 1, 30 do
			local ok, kind, code = os.execute("exit 7")
			assert(ok == nil and kind == "exit" and code == 7)
			local f = assert(io.popen("printf shell; exit 9"))
			assert(io.type(f) == "file" and f:read"a" == "shell")
			ok, kind, code = f:close()
			assert(ok == nil and kind == "exit" and code == 9)
			assert(io.type(f) == "closed file")
		end
		local f = assert(io.popen("read value; test \"$value\" = shell", "w"))
		assert(f:write("shell\n"))
		assert(f:close())
		assert(not pcall(io.popen, "exit 0", "rw"))
	end
	local launcher = worker.spawn { environment = "lua", fn = launch }
	assert(gate:send(true))
	launch() -- both main and worker standard libraries must be guarded
	assert(launcher:join(10000))
	assert(mutator:join(10000))
	gate:close()
	local success, kind, code = os.execute("kill -TERM $$")
	assert(success == nil and kind == "signal" and code == 15)
end

test["shell waits release the environment lock"] = function ()
	if require"eli.path".default_sep() ~= "/" then return end
	local env = os
	for _, use_popen in ipairs { false, true } do
		local ready, release = os.tmpname(), os.tmpname()
		os.remove(ready)
		os.remove(release)
		local w = worker.spawn {
			environment = "lua", args = { ready, release, use_popen },
			fn = function (ready, release, use_popen)
				local command = "touch '" .. ready .. "'; while [ ! -f '" .. release ..
					"' ]; do sleep 0.01; done"
				if use_popen then return assert(io.popen(command)):close() end
				return os.execute(command)
			end,
		}
		local observed = false
		for _ = 1, 500 do
			local f = io.open(ready)
			if f then f:close(); observed = true; break end
			eli_os.sleep(10)
		end
		-- The subprocess cannot finish until this thread acquires the env lock.
		-- Run the suite under its normal watchdog to catch a lock held by wait.
		assert(env.set_env("ELI_SHELL_WAIT", "unlocked"))
		assert(io.open(release, "w")):close()
		local joined, success, kind, code = w:join(5000)
		os.remove(ready)
		os.remove(release)
		env.set_env("ELI_SHELL_WAIT", nil)
		assert(observed and joined and success == true and kind == "exit" and code == 0)
	end
end

test["Windows shell guards launch under the environment lock only"] = function ()
	if require"eli.path".default_sep() ~= "\\" then return end
	local env = os
	test.assert(os.execute() == true)
	local ok, kind, code = os.execute("exit /b 7")
	test.assert(ok == nil and kind == "exit" and code == 7)
	local pipe = assert(io.popen("echo shell & exit /b 9"))
	local output = pipe:read"a"
	test.assert(type(output) == "string" and output:find("shell", 1, true))
	ok, kind, code = pipe:close()
	test.assert(ok == nil and kind == "exit" and code == 9)

	local ready = os.tmpname()
	os.remove(ready)
	local w = worker.spawn {
		environment = "lua", args = { ready },
		fn = function (ready)
			return os.execute('echo ready>"' .. ready .. '" & ping -n 3 127.0.0.1 >nul')
		end,
	}
	local observed = false
	for _ = 1, 500 do
		local f = io.open(ready)
		if f then f:close(); observed = true; break end
		eli_os.sleep(10)
	end
	test.assert(observed)
	test.assert(env.set_env("ELI_WINDOWS_SHELL_WAIT", "unlocked"))
	local pending = table.pack(w:join(0))
	test.assert(pending[1] == false and pending[2] == "timeout")
	local result = table.pack(w:join(10000))
	env.set_env("ELI_WINDOWS_SHELL_WAIT", nil)
	os.remove(ready)
	test.assert(result[1] == true and result[2] == true and result[3] == "exit" and result[4] == 0)
end

test["spawn PATH matches inherited environment"] = function ()
	if require"eli.path".default_sep() ~= "/" then return end
	local env, fs, proc = os, require"eli.fs", require"eli.proc"
	local root = os.tmpname()
	os.remove(root)
	local paths = { root .. "/a", root .. "/b" }
	for _, dir in ipairs(paths) do
		assert(fs.mkdirp(dir))
		local f = assert(io.open(dir .. "/eli-path-probe", "w"))
		f:write("#!/bin/sh\n[ \"$PATH\" = '" .. dir .. "' ]\n")
		f:close()
		assert(os.execute("/bin/chmod +x '" .. dir .. "/eli-path-probe'"))
	end
	local previous = os.getenv"PATH"
	assert(env.set_env("PATH", paths[1]))
	local stop = worker.channel(1)
	local w = worker.spawn {
		environment = "lua", args = { paths, stop },
		fn = function (paths, stop)
			local env = os
			repeat
				for _, path in ipairs(paths) do assert(env.set_env("PATH", path)) end
			until stop:try_receive(0)
		end,
	}
	local success, err = pcall(function ()
		for _ = 1, 200 do
			local result = assert(proc.spawn("eli-path-probe", {}, { wait = true }))
			assert(result.exit_code == 0, "candidate PATH differs from inherited PATH")
		end
	end)
	stop:send(true)
	local joined, join_error = w:join(5000)
	env.set_env("PATH", previous)
	stop:close()
	for _, dir in ipairs(paths) do
		os.remove(dir .. "/eli-path-probe")
		os.remove(dir)
	end
	os.remove(root)
	assert(joined, tostring(join_error))
	assert(success, tostring(err))
end

test["shared cwd"] = function ()
	local path = require"eli.path"
	if path.default_sep() ~= "/" then
		return
	end
	local eli_os = require"eli.os"
	local original = eli_os.cwd()
	local w = worker.spawn {
		environment = "eli",
		fn = function ()
			local before = os.cwd()
			os.chdir("/tmp")
			return before
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(eli_os.cwd() == "/tmp")
	eli_os.chdir(original)
end

test["subprocess from worker"] = function ()
	local w = worker.spawn {
		environment = "eli",
		fn = function ()
			local qemu = os.getenv"QEMU" or ""
			local bin = qemu ~= "" and qemu or INTERPRETER
			local args = qemu ~= "" and { INTERPRETER, "-e", "io.write('sub')" }
				or { "-e", "io.write('sub')" }
			local result = proc.spawn(bin, args, { wait = true })
			return result.exit_code, result.stdout_stream:read"a"
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == 0, tostring(r[3]))
	test.assert(r[3] == "sub")
end

test["signal ownership stays in the main state"] = function ()
	local os_signal = require"eli.os.extra".signal
	local is_unix = require"eli.path".default_sep() == "/"
	local w = worker.spawn {
		environment = "lua",
		args = { is_unix },
		fn = function (is_unix_like)
			local sig = require"eli.os.extra".signal
			local raised = true
			if is_unix_like then
				raised = sig.raise(0)
			end
			return pcall(sig.handle, sig.SIGTERM, function () end),
			       pcall(sig.poll, 100), pcall(sig.reset, sig.SIGTERM),
			       raised, sig.SIGTERM
		end,
	}
	local r = join_of(w)
	test.assert(r[1] == true)
	test.assert(r[2] == false and r[3] == false and r[4] == false)
	test.assert(r[5] == true)
	test.assert(r[6] == os_signal.SIGTERM)
end

test["subprocess from worker can receive SIGTERM"] = function ()
	if require"eli.path".default_sep() ~= "/" then return end
	local w = worker.spawn {
		environment = "eli",
		fn = function ()
			local script = 'local s=require"eli.os.extra".signal; io.write("ready"); io.flush(); s.raise(s.SIGTERM); io.write("survived")'
			local qemu = os.getenv"QEMU" or ""
			local bin = qemu ~= "" and qemu or INTERPRETER
			local args = qemu ~= "" and { INTERPRETER, "-e", script }
				or { "-e", script }
			local result = proc.spawn(bin, args, { wait = true })
			return result.stdout_stream:read"a"
		end,
	}
	local ok, output = w:join(5000)
	test.assert(ok, tostring(output))
	test.assert(output == "ready", "child inherited the worker's blocked SIGTERM")
end

test["concurrent independent file operations"] = function ()
	local first = os.tmpname()
	local second = os.tmpname()
	local w1 = worker.spawn {
		environment = "lua",
		args = { first },
		fn = function (p)
			local f = assert(io.open(p, "w"))
			f:write("one")
			f:close()
			return io.open(p):read"a"
		end,
	}
	local w2 = worker.spawn {
		environment = "lua",
		args = { second },
		fn = function (p)
			local f = assert(io.open(p, "w"))
			f:write("two")
			f:close()
			return io.open(p):read"a"
		end,
	}
	local r1 = join_of(w1)
	local r2 = join_of(w2)
	test.assert(r1[1] == true and r1[2] == "one")
	test.assert(r2[1] == true and r2[2] == "two")
	os.remove(first)
	os.remove(second)
end

test["closing one worker does not break another"] = function ()
	local gate = worker.channel(0)
	local w1 = worker.spawn {
		environment = "lua",
		args = { gate },
		fn = function (g)
			local path = os.tmpname()
			local f = assert(io.open(path, "w"))
			g:receive()
			f:write("alive")
			f:close()
			os.remove(path)
			return true
		end,
	}
	local w2 = worker.spawn {
		environment = "lua",
		fn = function () return true end,
	}
	local r2 = join_of(w2)
	test.assert(r2[1] == true)
	w2 = nil
	collectgarbage"collect"
	test.assert(gate:send(true))
	local r1 = join_of(w1)
	test.assert(r1[1] == true and r1[2] == true)
end

if not TEST then
	test.summary()
end
