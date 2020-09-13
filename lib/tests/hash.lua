  
local _test = TEST or require 'u-test'
local _ok, _eliHash = pcall(require, "eli.hash")

if not _ok then 
    _test["eli.hash available"] = function ()
        _test.assert(false, "eli.hash not available")
    end
    if not TEST then 
        _test.summary()
        os.exit()
    else 
        return 
    end
end

_test["eli.hash available"] = function ()
    _test.assert(true)
end

_test["sha256sum"] = function ()
    local _data = "test text\n"
    local _expected = "c2a4f4903509957d138e216a6d2c0d7867235c61088c02ca5cf38f2332407b00"
    local _result = _eliHash.sha256sum(_data, true)

    _test.assert(_expected == _result, "hashes do not match")
end

_test["sha512sum"] = function ()
    local _data = "test text\n"
    local _expected = "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local _result = _eliHash.sha512sum(_data, true)

    _test.assert(_expected == _result, "hashes do not match")
end

_test["Sha256"] = function ()
    local _sha256 = _eliHash.Sha256:new()
    local _data = "test text\n"
    local _expected = "c2a4f4903509957d138e216a6d2c0d7867235c61088c02ca5cf38f2332407b00"
    _sha256:update(_data)
    local _result = _sha256:finish(true)
    _test.assert(_expected == _result, "hashes do not match")
end

_test["Sha512"] = function ()
    local _sha512 = _eliHash.Sha512:new()
    local _data = "test text\n"
    local _expected = "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    _sha512:update(_data)
    local _result = _sha512:finish(true)
    _test.assert(_expected == _result, "hashes do not match")
end


if not TEST then 
    _test.summary()
end