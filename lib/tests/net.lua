local _test = TEST or require 'u-test'
local _ok, _eliNet = pcall(require, "eli.net")

if not _ok then
    _test["eli.net available"] = function()
        _test.assert(false, "eli.net not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.net available"] = function()
    _test.assert(true)
end

local RestClient = _eliNet.RestClient
_test["download_string"] = function()
    local _ok, _s = _eliNet.safe_download_string("https://raw.githubusercontent.com/alis-is/eli/master/LICENSE")
    _test.assert(_ok and _s:match("Copyright %(c%) %d%d%d%d alis%.is"), "copyright not found")
end

_test["download (progress)"] = function()
    local _print = print
    local _printed = ""
    local function new_print(msg)
        _printed = _printed .. msg
    end
    print = new_print
    local _, _ = _eliNet.safe_download_string("https://raw.githubusercontent.com/alis-is/eli/master/LICENSE", { showDefaultProgress = 5 })
    print = _print -- restore
    _test.assert(_printed:match("5%") and _printed:match("15%"), "no progress detected")
    print = new_print
    local _, _ = _eliNet.safe_download_string("https://raw.githubusercontent.com/alis-is/eli/master/LICENSE", { showDefaultProgress = true })
    print = _print -- restore
    _test.assert(_printed:match("10%") and _printed:match("20%"), "no progress detected")
end

_test["download_file"] = function()
    local _ok, _error = _eliNet.safe_download_file("https://raw.githubusercontent.com/alis-is/eli/master/LICENSE",
        "tmp/LICENSE")
    _test.assert(_ok, _error)
    local _ok, _file = pcall(io.open, "tmp/LICENSE", "r")
    _test.assert(_ok, _file)
    local _ok, _s = pcall(_file.read, _file, "a")
    _test.assert(_ok, _s)
    _test.assert(_s:match("Copyright %(c%) %d%d%d%d alis%.is"), "copyright not found")
end

_test["download_timeout"] = function()
    local _ok, _s = _eliNet.safe_download_string("https://raw.githubusercontent.com:81/alis-is/eli/master/LICENSE",
        { timeout = 1 })
    _test.assert(not _ok, "should fail")
end

_test["RestClient get"] = function()
    local _client = RestClient:new("https://raw.githubusercontent.com/")
    local _ok, _response = _client:safe_get("alis-is/eli/master/LICENSE")
    _test.assert(_ok, "request failed")
    _test.assert(_response.raw:match("Copyright %(c%) %d%d%d%d alis%.is"), "copyright not found")

    _client = RestClient:new("https://httpbin.org/")
    _ok, _response = _client:safe_get("get", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _response.data
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/get")
    _ok, _response = _client:safe_get({ params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient post"] = function()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_post({ test = "data", test2 = { other = "data2" } }, "post",
        { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/post")
    _ok, _response = _client:safe_post({ test = "data", test2 = { other = "data2" } },
        { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient put"] = function()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_put({ test = "data", test2 = { other = "data2" } }, "put",
        { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/put")
    _ok, _response = _client:safe_put({ test = "data", test2 = { other = "data2" } },
        { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/put")
    _ok, _response = _client:safe_put(io.open("assets/put.txt"), { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.data == "simple", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient patch"] = function()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_patch({ test = "data", test2 = { other = "data2" } }, "patch",
        { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/patch")
    _ok, _response = _client:safe_patch({ test = "data", test2 = { other = "data2" } },
        { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient delete"] = function()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_delete("delete", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _response.data
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/delete")
    _ok, _response = _client:safe_delete({ params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient conf"] = function()
    local _client = RestClient:new("https://httpbin.org/", { contentType = "text/plain" })
    local _ok, _response = _client:safe_post({ test = "data", test2 = { other = "data2" } }, "post",
        { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _response.data
    _test.assert(_data.json == nil, "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client:conf({ contentType = 'application/json' })
    _ok, _response = _client:safe_post({ test = "data", test2 = { other = "data2" } }, "post",
        { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _response.data
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient get_url and res"] = function()
    local _client = RestClient:new("https://httpbin.org/", { contentType = "text/plain" })
    _test.assert(_client:get_url() == "https://httpbin.org/")
    _client = _client:res("test")
    _test.assert(_client:get_url() == "https://httpbin.org/test")
    _client = _client:res("test2/test3")
    _test.assert(_client:get_url() == "https://httpbin.org/test/test2/test3")
end

_test["RestClient res (advanced)"] = function()
    local _client = RestClient:new("https://httpbin.org/", { contentType = "text/plain" })
    _test.assert(_client:get_url() == "https://httpbin.org/")
    local _arrayClients = _client:res({ "test", "test2/test3" })
    _test.assert(_arrayClients[1]:get_url() == "https://httpbin.org/test")
    _test.assert(_arrayClients[2]:get_url() == "https://httpbin.org/test2/test3")
    local _objectClientsTemplate = {
        test = "test",
        test2 = { "test3", "test4" },
        test3 = {
            __root = "test5",
            test1 = "test1",
            test2 = "test2"
        }
    }
    local _objectClients = _client:res(_objectClientsTemplate)
    _test.assert(_objectClients.test:get_url() == "https://httpbin.org/test")
    _test.assert(_objectClients.test2[1]:get_url() == "https://httpbin.org/test2/test3")
    _test.assert(_objectClients.test2[2]:get_url() == "https://httpbin.org/test2/test4")
    _test.assert(_objectClients.test3:get_url() == "https://httpbin.org/test5")
    _test.assert(_objectClients.test3.test1:get_url() == "https://httpbin.org/test5/test1")
    _test.assert(_objectClients.test3.test2:get_url() == "https://httpbin.org/test5/test2")

    local _notOverrideClientsTemplate = { test = { __root = "t", get = "test" } }
    local _notOverrideClients = _client:res(_notOverrideClientsTemplate)
    _test.assert(type(_notOverrideClients.test.get) ~= "function")
    _test.assert(_notOverrideClients.test:get_url() == "https://httpbin.org/t")

    local _overrideClientsTemplate = { test = { __root = "t", get = "test" } }
    local _notOverrideClients = _client:res(_overrideClientsTemplate, { allowRestclientPropertyOverride = true })
    _test.assert(type(_notOverrideClients.test.get) ~= "function")
    _test.assert(_notOverrideClients.test:get_url() == "https://httpbin.org/t")
end

if not TEST then
    _test.summary()
end
