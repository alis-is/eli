local mbed_hash = require"lmbed_hash"
local util = require"eli.util"

---@class HashGenerator
---@field update fun(self: HashGenerator, data: string)
---@field finish fun(self: HashGenerator, hex: boolean): string

local hash = {
	---#DES 'hash.sha256_sum'
	---
	--- Calculates sha256 hash of the data
	--- @param data string
	--- @param hex boolean? (default false)	- if true, returns the hash in hex format
	sha256_sum = mbed_hash.sha256sum,
	---#DES 'hash.sha512_sum'
	---
	--- Calculates sha512 hash of the data
	--- @param data string
	--- @param hex boolean? (default false)	- if true, returns the hash in hex format
	sha512_sum = mbed_hash.sha512sum,
	---#DES 'hash.sha256_init'
	---
	--- Initializes sha256 hash
	--- @return HashGenerator
	sha256_init = mbed_hash.sha256init,
	---#DES 'hash.sha512_init'
	---
	--- Initializes sha512 hash
	--- @return HashGenerator
	sha512_init = mbed_hash.sha512init,
	---#DES 'hash.equals'
	---
	--- Compares two hashes
	--- @param hash1 string
	--- @param hash2 string
	--- @param hex boolean? (default false)	- if true, compares the hashes in hex format
	--- @return boolean
	equals = mbed_hash.equals,
}

-- // TODO: remove deprecated functions in next version

---@deprecated
function hash.sha256sum(data, hex)
	print"Deprecation warning: use hash.sha256_sum instead"
	return mbed_hash.sha256sum(data, hex)
end

---@deprecated
function hash.sha512sum(data, hex)
	print"Deprecation warning: use hash.sha512_sum instead"
	return mbed_hash.sha512sum(data, hex)
end

---@deprecated
function hash.sha256init()
	print"Deprecation warning: use hash.sha256_init instead"
	return mbed_hash.sha256init()
end

---@deprecated
function hash.sha512init()
	print"Deprecation warning: use hash.sha512_init instead"
	return mbed_hash.sha512init()
end

return util.generate_safe_functions(hash)
