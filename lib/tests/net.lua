local _test = TEST or require 'u-test'
local _ok, _eliNet = pcall(require, "eli.net")
local _sha256sum = require "lmbed_hash".sha256sum

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

_test["download_string"] = function ()
    local _expected = "cee96dc092845bea85c7eabe0734bc7c704984bdaade73334bd0e2113c7bd6d5"
    local _ok, _s = _eliNet.safe_download_string("https://raw.githubusercontent.com/cryon-io/eli/master/LICENSE")
    local _result = _sha256sum(_s, true)
    _test.assert(_expected == _result, "hashes do not match")
end

_test["download_file"] = function ()
    local _expected = "cee96dc092845bea85c7eabe0734bc7c704984bdaade73334bd0e2113c7bd6d5"
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
    _eliNet.safe_set_tls_timeout(1)
    local _ok, _s = _eliNet.safe_download_string("https://raw.githubusercontent.com/cryon-io/eli/master/LICENSE")
    _eliNet.safe_set_tls_timeout(0)
    _test.assert(not _ok, "should fail")
end

if not TEST then
    _test.summary()
end