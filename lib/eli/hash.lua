local _hash = require "lmbed_hash"
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
    sha256.ctx = _hash.sha256_init()
    return sha256
end

---#DES 'hash.Sha256:update'
---
---@param self Sha512
---@param bytes string
function Sha256:update(bytes) _hash.sha256_update(self.ctx, bytes) end

---#DES 'hash.Sha256:finish'
---
---@param self Sha512
---@param hex boolean?
---@return string
function Sha256:finish(hex) return _hash.sha256_finish(self.ctx, hex) end

---#DES 'hash.Sha512'
---@class Sha512: HashGenerator
local Sha512 = {}
Sha512.__index = Sha512

function Sha512:new()
    local sha512 = {}

    setmetatable(sha512, self)
    self.__index = self
    sha512.ctx = _hash.sha512_init()
    return sha512
end

---#DES 'hash.Sha512:update'
---
---@param self Sha512
---@param bytes string
function Sha512:update(bytes) _hash.sha512_update(self.ctx, bytes) end

---#DES 'hash.Sha512:finish'
---
---@param self Sha512
---@param hex boolean?
---@return string
function Sha512:finish(hex) return _hash.sha512_finish(self.ctx, hex) end

---#DES 'hash.hex_equals'
---
---Compares 2 hashes represented as hex strings
---@param hash1 string
---@param hash2 string
---@return boolean
local function _hex_equals(hash1, hash2)
    return _hash.equals(hash1, hash2, true)
end

return _util.generate_safe_functions({
    Sha256 = Sha256,
    Sha512 = Sha512,
    ---#DES hash.sha256sum
    ---
    ---@param data string
    ---@param hex boolean?
    ---@return string
    sha256sum = _hash.sha256sum,
    ---#DES hash.sha512sum
    ---
    ---@param data string
    ---@param hex boolean?
    ---@return string
    sha512sum = _hash.sha512sum,
    ---#DES 'hash.equals'
    ---
    ---Compares two strings (if hex true - compares as hex strings)
    ---@param hash1 string
    ---@param hash2 string
    ---@param hex boolean?
    ---@return boolean
    equals = _hash.equals,
    hex_equals = _hex_equals
})
