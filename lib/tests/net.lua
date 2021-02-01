local _test = TEST or require 'u-test'
local _ok, _eliNet = pcall(require, "eli.net")
local _sha256sum = require "lmbed_hash".sha256sum
local _hjson = require"hjson"

if not _ok then 
    _test["eli.net available"] = function ()
        _test.assert(false, "eli.net not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.net available"] = function ()
    _test.assert(true)
end

local RestClient = _eliNet.RestClient
_test["download_string"] = function ()
    local _expected = "d11ca745153a3d9c54a79840e2dc7abd7bde7ff33fb0723517282abeea23e393"
    local _ok, _s = _eliNet.safe_download_string("https://raw.githubusercontent.com/cryon-io/eli/master/LICENSE")
    local _result = _sha256sum(_s, true)
    _test.assert(_expected == _result, "hashes do not match")
end

_test["download_file"] = function ()
    local _expected = "d11ca745153a3d9c54a79840e2dc7abd7bde7ff33fb0723517282abeea23e393"
    local _ok, _error = _eliNet.safe_download_file("https://raw.githubusercontent.com/cryon-io/eli/master/LICENSE", "tmp/LICENSE")
    _test.assert(_ok, _error)
    local _ok, _file = pcall(io.open, "tmp/LICENSE", "r")
    _test.assert(_ok, _file)
    local _ok, _s = pcall(_file.read, _file, "a")
    _test.assert(_ok, _s)
    local _result = _sha256sum(_s, true)
    _test.assert(_expected == _result, "hashes do not match")
end

_test["download_timeout"] = function ()
    local _ok, _s = _eliNet.safe_download_string("https://raw.githubusercontent.com:81/cryon-io/eli/master/LICENSE", {timeout = 1})
    _test.assert(not _ok, "should fail")
end

_test["RestClient get"] = function ()
    local _expected = "d11ca745153a3d9c54a79840e2dc7abd7bde7ff33fb0723517282abeea23e393"
    local _client = RestClient:new("https://raw.githubusercontent.com/")
    local _ok, _response = _client:safe_get("cryon-io/eli/master/LICENSE")
    _test.assert(_ok, "request failed")
    local _result = _sha256sum(_response.data, true)
    _test.assert(_expected == _result, "hashes do not match")

    _client = RestClient:new("https://httpbin.org/")
    _ok, _response = _client:safe_get("get", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _hjson.parse(_response.data)
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/get")
    _ok, _response = _client:safe_get({ params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _hjson.parse(_response.data)
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient post"] = function ()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_post({ test = "data", test2 = { other = "data2" } }, "post", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _hjson.parse(_response.data)
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/post")
    _ok, _response = _client:safe_post({ test = "data", test2 = { other = "data2" } }, { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _hjson.parse(_response.data)
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient put"] = function ()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_put({ test = "data", test2 = { other = "data2" } }, "put", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _hjson.parse(_response.data)
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/put")
    _ok, _response = _client:safe_put({ test = "data", test2 = { other = "data2" } }, { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _hjson.parse(_response.data)
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient patch"] = function ()
    local _client = RestClient:new("https://httpbin.org/")
    local _ok, _response = _client:safe_patch({ test = "data", test2 = { other = "data2" } }, "patch", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _hjson.parse(_response.data)
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/patch")
    _ok, _response = _client:safe_patch({ test = "data", test2 = { other = "data2" } }, { params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _hjson.parse(_response.data)
    _test.assert(_data.json.test == "data" and _data.json.test2.other == "data2", "Failed to verify result")
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient delete"] = function ()
    _client = RestClient:new("https://httpbin.org/")
    _ok, _response = _client:safe_delete("delete", { params = { test = "aaa", test2 = "bbb" } })
    _test.assert(_ok, "request failed")
    local _data = _hjson.parse(_response.data)
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")

    _client = RestClient:new("https://httpbin.org/delete")
    _ok, _response = _client:safe_delete({ params = { "test=aaa", "test2=bbb" } })
    _test.assert(_ok, "request failed")
    _data = _hjson.parse(_response.data)
    _test.assert(_data.args.test == "aaa" and _data.args.test2 == "bbb", "Failed to verify result")
end

_test["RestClient conf"] = function ()

end

_test["RestClient get_url"] = function ()

end

if not TEST then
    _test.summary()
end