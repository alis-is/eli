  
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

    _test.assert(_eliHash.hex_equals(_expected, _result), "hashes do not match")
end

_test["sha512sum"] = function ()
    local _data = "test text\n"
    local _expected = "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local _result = _eliHash.sha512sum(_data, true)

    _test.assert(_eliHash.hex_equals(_expected, _result), "hashes do not match")
end

_test["Sha256"] = function ()
    local _sha256 = _eliHash.sha256init()
    local _data = "test text\n"
    local _expected = "c2a4f4903509957d138e216a6d2c0d7867235c61088c02ca5cf38f2332407b00"
    _sha256:update(_data)
    local _result = _sha256:finish(true)
    _test.assert(_eliHash.hex_equals(_expected, _result), "hashes do not match")
end

_test["Sha512"] = function ()
    local _sha512 = _eliHash.sha512init()
    local _data = "test text\n"
    local _expected = "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    _sha512:update(_data)
    local _result = _sha512:finish(true)
    _test.assert(_eliHash.hex_equals(_expected, _result), "hashes do not match")
end

_test["equals"] = function ()
    local _data = "test text\n"
    local _data2 = "test text\n"
    local _data3 = "test text"
    local _result = _eliHash.sha256sum(_data)
    local _result2 = _eliHash.sha256sum(_data2)
    local _result3 = _eliHash.sha256sum(_data3)
    _test.assert(_eliHash.equals(_result, _result2), "hashes do not match")
    _test.assert(not _eliHash.equals(_result, _result3), "hashes match and should not")
end

_test["hex_equals"] = function ()
    local _hash1 = "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local _hash2 = "0xae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local _hash3 = "0Xae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local _hash4 = string.upper(_hash2)
    local _hash5 = "0xAE9CD6D303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    _test.assert(_eliHash.hex_equals(_hash1, _hash2), "hashes do not match")
    _test.assert(_eliHash.hex_equals(_hash1, _hash3), "hashes do not match")
    _test.assert(_eliHash.hex_equals(_hash1, _hash4), "hashes do not match")
    _test.assert(_eliHash.hex_equals(_hash1, _hash5), "hashes do not match")
    local _hash6 = "0xAE9CD6D303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc9"
    local _hash7 = "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb6"
    _test.assert(not _eliHash.hex_equals(_hash1, _hash6), "hashes match and should not")
    _test.assert(not _eliHash.hex_equals(_hash1, _hash7), "hashes match and should not")
end


if not TEST then 
    _test.summary()
end
