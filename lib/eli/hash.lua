local mbed_hash = require"lmbed_hash"

---@class HashGenerator
---@field update fun(self: HashGenerator, data: string): string?, string?
---@field finish fun(self: HashGenerator, hex: boolean): string?, string?

local hash = {
	---#DES 'hash.sha256_sum'
	---
	--- Calculates sha256 hash of the data
	--- @param data string?
	--- @param hex boolean|string? (default false)	- if true, returns the hash in hex format
	sha256_sum = mbed_hash.sha256_sum,
	---#DES 'hash.sha512_sum'
	---
	--- Calculates sha512 hash of the data
	--- @param data string?
	--- @param hex boolean|string? (default false)	- if true, returns the hash in hex format
	sha512_sum = mbed_hash.sha512_sum,
	---#DES 'hash.sha256_init'
	---
	--- Initializes sha256 hash
	--- @return HashGenerator
	sha256_init = mbed_hash.sha256_init,
	---#DES 'hash.sha512_init'
	---
	--- Initializes sha512 hash
	--- @return HashGenerator
	sha512_init = mbed_hash.sha512_init,
	---#DES 'hash.equals'
	---
	--- Compares two hashes
	--- @param hash1 string
	--- @param hash2 string
	--- @param hex boolean? (default false)	- if true, compares the hashes in hex format
	--- @return boolean
	equals = mbed_hash.equals,
}

return hash
