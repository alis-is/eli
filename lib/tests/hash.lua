local test = TEST or require"u-test"
local ok, hash = pcall(require, "eli.hash")

if not ok then
    test["eli.hash available"] = function ()
        test.assert(false, "eli.hash not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.hash available"] = function ()
    test.assert(true)
end

test["sha256_sum"] = function ()
    local data = "test text\n"
    local expected = "c2a4f4903509957d138e216a6d2c0d7867235c61088c02ca5cf38f2332407b00"
    local result = hash.sha256_sum(data, true)

    test.assert(hash.equals(expected, result, true), "hashes do not match")
end

test["sha512_sum"] = function ()
    local data = "test text\n"
    local expected =
    "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local result = hash.sha512_sum(data, true)

    test.assert(hash.equals(expected, result, true), "hashes do not match")
end

test["Sha256"] = function ()
    local sha256 = hash.sha256_init()
    local data = "test text\n"
    local expected = "c2a4f4903509957d138e216a6d2c0d7867235c61088c02ca5cf38f2332407b00"
    sha256:update(data)
    local result = sha256:finish(true)
    test.assert(hash.equals(expected, result, true), "hashes do not match")
end

test["Sha512"] = function ()
    local sha512 = hash.sha512_init()
    local data = "test text\n"
    local expected =
    "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    sha512:update(data)
    local result = sha512:finish(true)
    test.assert(hash.equals(expected, result, true), "hashes do not match")
end

test["equals"] = function ()
    local data = "test text\n"
    local data2 = "test text\n"
    local data3 = "test text"
    local result = hash.sha256_sum(data)
    local result2 = hash.sha256_sum(data2)
    local result3 = hash.sha256_sum(data3)
    test.assert(hash.equals(result, result2), "hashes do not match")
    test.assert(not hash.equals(result, result3), "hashes match and should not")
end

test["equals (hex = true)"] = function ()
    local hash1 =
    "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local hash2 =
    "0xae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local hash3 =
    "0Xae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    local hash4 = string.upper(hash2)
    local hash5 =
    "0xAE9CD6D303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb5"
    test.assert(hash.equals(hash1, hash2, true), "hashes do not match")
    test.assert(hash.equals(hash1, hash3, true), "hashes do not match")
    test.assert(hash.equals(hash1, hash4, true), "hashes do not match")
    test.assert(hash.equals(hash1, hash5, true), "hashes do not match")
    local hash6 =
    "0xAE9CD6D303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc9"
    local hash7 =
    "ae9cd6d303a5836d8a6d82b468a8f968ab557243d8b16601394d29e81e6766c609fe810ee9c3988ae15b98b9cbf3a602f6905e78466b968f3a6b8201edc94cb6"
    test.assert(not hash.equals(hash1, hash6, true), "hashes match and should not")
    test.assert(not hash.equals(hash1, hash7, true), "hashes match and should not")
end


if not TEST then
    test.summary()
end
