local hash = require "lmbed_hash"
local _util = require"eli.util"
local _generate_safe_functions = _util.generate_safe_functions

local Sha256 = {}
Sha256.__index = Sha256

function Sha256:new()
    local sha256 = {}

    setmetatable(sha256, self)
    self.__index = self
    sha256.ctx = hash.sha256_init()
    return sha256
end

function Sha256:update(bytes)
    hash.sha256_update(self.ctx, bytes)
end

function Sha256:finish(hex)
    return hash.sha256_finish(self.ctx, hex)
end

local Sha512 = {}
Sha512.__index = Sha512

function Sha512:new()
    local sha512 = {}

    setmetatable(sha512, self)
    self.__index = self
    sha512.ctx = hash.sha512_init()
    return sha512
end

function Sha512:update(bytes)
    hash.sha512_update(self.ctx, bytes)
end

function Sha512:finish(hex)
    return hash.sha512_finish(self.ctx, hex)
end

return _generate_safe_functions(
    {
        Sha256 = Sha256,
        Sha512 = Sha512,
        sha256sum = hash.sha256sum,
        sha512sum = hash.sha512sum
    }
)
