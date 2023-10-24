local test = TEST or require"u-test"
local ok, eliNet = pcall(require, "eli.net")

-- https://postman-echo.com/ ?
local HTTPBIN_URL = os.getenv"HTTPBIN_URL" or "https://httpbin.org/"
local TIMEOUT = 180 * 1000
-- // TODO: find better way to test net
local RETRIES = 3

if not ok then
	test["eli.net available"] = function ()
		test.assert(false, "eli.net not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.net available"] = function ()
	test.assert(true)
end

local RestClient = eliNet.RestClient
test["download_string"] = function ()
	local ok, s = eliNet.safe_download_string"https://raw.githubusercontent.com/alis-is/eli/main/LICENSE"
	test.assert(ok and s:match"Copyright %(c%) %d%d%d%d alis%.is", "copyright not found")
end

test["download (progress)"] = function ()
	local _print = io.write
	local _printed = ""
	local function new_print(msg)
		_printed = _printed .. msg
	end
	io.write = new_print
	local _, _ = eliNet.safe_download_string("http://speedtest.ftp.otenet.gr/files/test1Mb.db",
		{
			followRedirects = true,
			showDefaultProgress = 5,
			bufferCapacity = 1024 * 100,
		})
	io.write = _print -- restore
	test.assert(_printed:match"(%d+)%%", "no progress detected")
	_printed = ""
	io.write = new_print
	local _, _ = eliNet.safe_download_string("http://speedtest.ftp.otenet.gr/files/test1Mb.db",
		{
			followRedirects = true,
			showDefaultProgress = true,
			bufferCapacity = 1024 * 100,
		})
	io.write = _print -- restore
	test.assert(_printed:match"(%d+)%%", "no progress detected")
end

test["download_file"] = function ()
	local ok, error = eliNet.safe_download_file("https://raw.githubusercontent.com/alis-is/eli/main/LICENSE",
		"tmp/LICENSE")
	test.assert(ok, error)
	local ok, file = pcall(io.open, "tmp/LICENSE", "r")
	test.assert(ok, file)
	local ok, s = pcall(file.read, file, "a")
	test.assert(ok, s)
	test.assert(s:match"Copyright %(c%) %d%d%d%d alis%.is", "copyright not found")
end

test["download_timeout"] = function ()
	local ok, _ = eliNet.safe_download_string("https://raw.githubusercontent.com:81/alis-is/eli/main/LICENSE",
		{ timeout = 1 })
	test.assert(not ok, "should fail")
end

test["RestClient get"] = function ()
	local client = RestClient:new"https://raw.githubusercontent.com/"
	local ok, response = client:safe_get("alis-is/eli/main/LICENSE", { followRedirects = true })
	test.assert(ok, "request failed - " .. tostring(response))
	test.assert(response.raw:match"Copyright %(c%) %d%d%d%d alis%.is", "copyright not found")

	client = RestClient:new(HTTPBIN_URL, { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_get("get", { params = { test = "aaa", test2 = "bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	local _data = response.data
	test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

	client = RestClient:new(HTTPBIN_URL .. "get", { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_get{ params = { "test=aaa", "test2=bbb" } }
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	local data = response.data
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")
end

test["RestClient post"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { timeout = TIMEOUT })
	local ok, response
	for _ = 1, RETRIES do
		ok, response = client:safe_post({ test = "data", test2 = { other = "data2" } }, "post",
			{ params = { test = "aaa", test2 = "bbb", timeout = 10000 } })
		if ok then break end
	end
	print(ok, response)
	test.assert(ok, "request failed  - " .. tostring(response))
	local data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")

	client = RestClient:new(HTTPBIN_URL .. "post", { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_post({ test = "data", test2 = { other = "data2" } },
			{ params = { "test=aaa", "test2=bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")
end

test["RestClient put"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { timeout = TIMEOUT })
	local ok, response
	for _ = 1, RETRIES do
		ok, response = client:safe_put({ test = "data", test2 = { other = "data2" } }, "put",
			{ params = { test = "aaa", test2 = "bbb" }, timeout = TIMEOUT })
		if ok then break end
	end
	test.assert(ok, "request failed - " .. tostring(response))
	local data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")

	client = RestClient:new(HTTPBIN_URL .. "put", { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_put({ test = "data", test2 = { other = "data2" } },
			{ params = { "test=aaa", "test2=bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed - " .. tostring(response))
	data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")

	client = RestClient:new(HTTPBIN_URL .. "put", { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_put(io.open"assets/put.txt", { params = { "test=aaa", "test2=bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	data = response.data
	test.assert(data.data == "simple", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")
end

test["RestClient patch"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { timeout = TIMEOUT })
	local ok, response
	for _ = 1, RETRIES do
		ok, response = client:safe_patch({ test = "data", test2 = { other = "data2" } }, "patch",
			{ params = { test = "aaa", test2 = "bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	local data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")

	client = RestClient:new(HTTPBIN_URL .. "patch", { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_patch({ test = "data", test2 = { other = "data2" } },
			{ params = { "test=aaa", "test2=bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")
end

test["RestClient delete"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { timeout = TIMEOUT })
	local ok, response
	for _ = 1, RETRIES do
		ok, response = client:safe_delete("delete", { params = { test = "aaa", test2 = "bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	local data = response.data
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")

	client = RestClient:new(HTTPBIN_URL .. "delete", { timeout = TIMEOUT })
	for _ = 1, RETRIES do
		ok, response = client:safe_delete{ params = { "test=aaa", "test2=bbb" } }
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	data = response.data
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")
end

test["RestClient conf"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { headers = { ["Content-Type"] = "text/plain" }, timeout = TIMEOUT })
	local ok, response
	for _ = 1, RETRIES do
		ok, response = client:safe_post({ test = "data", test2 = { other = "data2" } }, "post",
			{ params = { test = "aaa", test2 = "bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	local data = response.data
	test.assert(data.json == nil, "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")

	client:conf{ headers = { ["Content-Type"] = "application/json" } }
	for _ = 1, RETRIES do
		ok, response = client:safe_post({ test = "data", test2 = { other = "data2" } }, "post",
			{ params = { "test=aaa", "test2=bbb" } })
		if ok then break end
	end
	test.assert(ok, "request failed  - " .. tostring(response))
	data = response.data
	test.assert(data.json.test == "data" and data.json.test2.other == "data2", "Failed to verify result")
	test.assert(data.args.test == "aaa" and data.args.test2 == "bbb", "Failed to verify result")
end

test["RestClient get_url and res"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { contentType = "text/plain", timeout = TIMEOUT })
	test.assert(tostring(client:get_url()) == HTTPBIN_URL)
	client = client:res"test"
	test.assert(tostring(client:get_url()) == HTTPBIN_URL .. "test")
	client = client:res"test2/test3"
	test.assert(tostring(client:get_url()) == HTTPBIN_URL .. "test/test2/test3")
end

test["RestClient res (advanced)"] = function ()
	local client = RestClient:new(HTTPBIN_URL, { contentType = "text/plain", timeout = TIMEOUT })
	test.assert(tostring(client:get_url()) == HTTPBIN_URL)
	local arrayClients = client:res{ "test", "test2/test3" }
	test.assert(tostring(arrayClients[1]:get_url()) == HTTPBIN_URL .. "test")
	test.assert(tostring(arrayClients[2]:get_url()) == HTTPBIN_URL .. "test2/test3")
	local _objectClientsTemplate = {
		test = "test",
		test2 = { "test3", "test4" },
		test3 = {
			__root = "test5",
			test1 = "test1",
			test2 = "test2",
		},
	}
	local objectClients = client:res(_objectClientsTemplate)
	test.assert(tostring(objectClients.test:get_url()) == HTTPBIN_URL .. "test")
	test.assert(tostring(objectClients.test2[1]:get_url()) == HTTPBIN_URL .. "test2/test3")
	test.assert(tostring(objectClients.test2[2]:get_url()) == HTTPBIN_URL .. "test2/test4")
	test.assert(tostring(objectClients.test3:get_url()) == HTTPBIN_URL .. "test5")
	test.assert(tostring(objectClients.test3.test1:get_url()) == HTTPBIN_URL .. "test5/test1")
	test.assert(tostring(objectClients.test3.test2:get_url()) == HTTPBIN_URL .. "test5/test2")

	local notOverrideClientsTemplate = { test = { __root = "t", get = "test" } }
	local notOverrideClients = client:res(notOverrideClientsTemplate)
	test.assert(type(notOverrideClients.test.get) ~= "function")
	test.assert(tostring(notOverrideClients.test:get_url()) == HTTPBIN_URL .. "t")

	local overrideClientsTemplate = { test = { __root = "t", get = "test" } }
	local notOverrideClients = client:res(overrideClientsTemplate, { allowRestclientPropertyOverride = true })
	test.assert(type(notOverrideClients.test.get) ~= "function")
	test.assert(tostring(notOverrideClients.test:get_url()) == HTTPBIN_URL .. "t")
end

if not TEST then
	test.summary()
end
