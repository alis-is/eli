local zlib = require"zlib"
local util = require"eli.util"

local lz = {}

---@class LzExtractOptions
---@field chunk_size integer?
---@field open_file (fun(path: string, mode: string): file* | any)?
---@field write (fun(file: file* | any, data: string))?
---@field close_file (fun(file: file* | any))?

---#DES 'lz.extract'
---
---Extracts z compressed stream from source into destination
---@param source string
---@param destination string?
---@param options LzExtractOptions?
function lz.extract(source, destination, options)
	local _sf <close> = io.open(source, "rb")
	assert(_sf, "lz: Failed to open source file " .. tostring(source) .. "!")

	if type(options) ~= "table" then options = {} end
	local _open_file = type(options.open_file) == "function" and
	   options.open_file or
	   function (path, mode)
		   return io.open(path, mode)
	   end
	local write = type(options.write) == "function" and options.write or
	   function (file, data) return file:write(data) end
	local close_file = type(options.close_file) == "function" and
	   options.close_file or
	   function (file) return file:close() end

	local destination_file = _open_file(destination, "wb")
	assert(destination_file,
		"lz: Failed to open destination file " .. tostring(source) .. "!")

	-- // TODO: remove in the next version
	if options.chunkSize ~= nil and options.chunk_size == nil then
		options.chunk_size = options.chunkSizep
		print"Deprecation warning: use chunk_size instead of chunkSize"
	end

	local chunk_size =
	   type(options.chunk_size) == "number" and options.chunk_size or 2 ^ 13 -- 8K

	local inflate = zlib.inflate()
	local shift = 0
	while true do
		local data = _sf:read(chunk_size)
		if not data then break end
		local inflated, is_eof, bytes_in, _ = inflate(data)
		if type(inflated) == "string" then write(destination_file, inflated) end
		if is_eof then -- we got end of gzip stream we return to bytes_in pos in case there are multiple stream embedded
			_sf:seek("set", shift + bytes_in)
			shift = shift + bytes_in
			inflate = zlib.inflate()
		end
	end
	close_file(destination_file)
end

---#DES 'lz.extract_from_string'
---
---Extracts z compressed stream from binary like string variable
---@param data string
---@return string
function lz.extract_from_string(data)
	if type(data) ~= "string" then
		error("lz: Unsupported compressed data type: " .. type(data) .. "!")
	end
	local shift = 1
	local result = ""
	while (shift < #data) do
		local inflate = zlib.inflate()
		local inflated, is_eof, bytes_in, _ = inflate(data:sub(shift))
		assert(is_eof, "lz: Compressed stream is not complete!")
		shift = shift + bytes_in
		result = result .. inflated -- merge streams for cases when input is multi stream
	end
	return result
end

---#DES lz.extract_string
---
--- extracts string from z compressed archive from path source
---@param source string
---@param extract_options LzExtractOptions?
---@return string
function lz.extract_string(source, extract_options)
	local result = ""
	local options = util.merge_tables(type(extract_options) == "table" and extract_options or
		{}, {
			open_file = function () return result end,
			write = function (_, data) result = result .. data end,
			close_file = function () end,
		}, true)

	lz.extract(source, nil, options)
	return result
end

---@class LzCompressOptions
---@field level number? 0 - 9
---@field window_size integer? 9 - 15

---#DES lz.extract_string
---
--- extracts string from z compressed archive from path source
---@param data string
---@param options LzCompressOptions?
---@return string
function lz.compress_string(data, options)
	if type(data) ~= "string" then
		error("lz: Unsupported data type: " .. type(data) .. "!")
	end
	if type(options) ~= "table" then
		options = {}
	end
	local level = type(options.level) == "number" and options.level or 6
	if level > 9 then level = 9 end
	if level < 0 then level = 0 end

	if options.windowSize ~= nil and options.window_size == nil then
		options.window_size = options.windowSize
		print"Deprecation warning: use window_size instead of windowSize"
	end

	local window_size = options.window_size
	if type(window_size) == "number" then
		if window_size < 9 then window_size = 9 end
		if window_size > 15 then window_size = 15 end
	end
	local deflate = zlib.deflate(level, window_size)
	return deflate(data, "finish")
end

return util.generate_safe_functions(lz)
