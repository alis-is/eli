local _hash = require "lmbed_hash"
local _util = require "eli.util"

---@class HashGenerator
---#DES 'HashGenerator.ctx'
---@field ctx userdata

---#DES 'hash.Sha256'
---@class Sha256: HashGenerator
---@deprecated
local Sha256 = {}
Sha256.__index = Sha256

---@deprecated
function Sha256:new()
    local sha256 = {}

    setmetatable(sha256, self)
    self.__index = self
    sha256.ctx = _hash.sha256init()
    return sha256
end

---#DES 'hash.Sha256:update'
---
---@param self Sha512
---@param bytes string
---@deprecated
function Sha256:update(bytes) self.ctx:update(bytes) end

---#DES 'hash.Sha256:finish'
---
---@param self Sha512
---@param hex boolean?
---@return string
---@deprecated
function Sha256:finish(hex) return self.ctx:finish(hex) end

---#DES 'hash.Sha512'
---@deprecated
---@class Sha512: HashGenerator
local Sha512 = {}
Sha512.__index = Sha512

---@deprecated
function Sha512:new()
    local sha512 = {}

    setmetatable(sha512, self)
    self.__index = self
    sha512.ctx = _hash.sha512init()
    return sha512
end

---#DES 'hash.Sha512:update'
---
---@param self Sha512
---@param bytes string: test
---@deprecated
function Sha512:update(bytes) self.ctx:update(bytes) end

---#DES 'hash.Sha512:finish'
---
---@param self Sha512
---@param hex boolean?
---@return string
---@deprecated
function Sha512:finish(hex) return self.ctx:finish(hex) end

---#DES 'hash.hex_equals'
---
---Compares 2 hashes represented as hex strings
---@param hash1 string
---@param hash2 string
---@return boolean
---@deprecated
local function _hex_equals(hash1, hash2)
    return _hash.equals(hash1, hash2, true)
end

return _util.generate_safe_functions({
    Sha256 = Sha256,
    Sha512 = Sha512,
    ---#DES hash.sha256sum
    ---
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param data string
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param hex boolean?
    ---@return string
    sha256sum = _hash.sha256sum,
    ---#DES hash.sha512sum
    ---
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param data string
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param hex boolean?
    ---@return string
    sha512sum = _hash.sha512sum,
    ---#DES 'hash.equals'
    ---
    ---Compares two strings (if hex true - compares as hex strings)
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param hash1 string
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param hash2 string
    ---@diagnostic disable-next-line: undefined-doc-param
    ---@param hex boolean?
    ---@return boolean
    equals = _hash.equals,
    hex_equals = _hex_equals
})
