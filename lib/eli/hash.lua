local hash = require "lmbed_hash"
local _util = require "eli.util"

---@class HashGenerator
---#DES 'HashGenerator.ctx'
---@field ctx userdata

---#DES 'hash.Sha256'
---@class Sha256: HashGenerator
local Sha256 = {}
Sha256.__index = Sha256

function Sha256:new()
    local sha256 = {}

    setmetatable(sha256, self)
    self.__index = self
    sha256.ctx = hash.sha256_init()
    return sha256
end

---#DES 'hash.Sha256:update'
---
---@param self Sha512
---@param bytes string
function Sha256:update(bytes) hash.sha256_update(self.ctx, bytes) end

---#DES 'hash.Sha256:finish'
---
---@param self Sha512
---@param hex boolean
---@return string
function Sha256:finish(hex) return hash.sha256_finish(self.ctx, hex) end

---#DES 'hash.Sha512'
---@class Sha512: HashGenerator
local Sha512 = {}
Sha512.__index = Sha512

function Sha512:new()
    local sha512 = {}

    setmetatable(sha512, self)
    self.__index = self
    sha512.ctx = hash.sha512_init()
    return sha512
end

---#DES 'hash.Sha512:update'
---
---@param self Sha512
---@param bytes string
function Sha512:update(bytes) hash.sha512_update(self.ctx, bytes) end

---#DES 'hash.Sha512:finish'
---
---@param self Sha512
---@param hex boolean
---@return string
function Sha512:finish(hex) return hash.sha512_finish(self.ctx, hex) end

return _util.generate_safe_functions({
    Sha256 = Sha256,
    Sha512 = Sha512,
    ---#DES hash.sha256sum
    ---
    ---@param data string
    ---@param hex boolean
    ---@return string
    sha256sum = hash.sha256sum,
    ---#DES hash.sha512sum
    ---
    ---@param data string
    ---@param hex boolean
    ---@return string
    sha512sum = hash.sha512sum
})
