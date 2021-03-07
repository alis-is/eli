local _zlib = require "zlib"
local _util = require "eli.util"

local function _extract(source, destination, options)
    local _sf = io.open(source)
    assert(_sf, "lz: Failed to open source file " .. tostring(source) .. "!")

    if type(options) ~= "table" then
        options = {}
    end
    local _open_file = type(options.open_file) == "function" and options.open_file or function(path, mode)
            return io.open(path, mode)
        end
    local _write = type(options.write) == "function" and options.write or function(file, data)
            return file:write(data)
        end
    local _close_file = type(options.close_file) == "function" and options.close_file or function(file)
            return file:close()
        end

    local _df = _open_file(destination, "w")
    assert(_df, "lz: Failed to open destination file " .. tostring(source) .. "!")

    local _chunkSize = type(options.chunkSize) == "number" and options.chunkSize or 2 ^ 13 -- 8K

    local _inflate = _zlib.inflate()
    local _shift = 0
    while true do
        local _data = _sf:read(_chunkSize)
        if not _data then
            break
        end
        local _inflated, eof, bytes_in, _ = _inflate(_data)
        if type(_inflated) == "string" then
            _write(_df, _inflated)
        end
        if eof then -- we got end of gzip stream we return to bytes_in pos in case there are multiple stream embedded
            _sf:seek("set", _shift + bytes_in)
            _shift = _shift + bytes_in
            _inflate = _zlib.inflate()
        end
    end
    _sf:close()
    _close_file(_df)
end

-- decodes entries stream (requires gz stream to be complete)
local function _extract_from_string(data)
    if type(data) ~= "string" then
        error("lz: Unsupported compressed data type: " .. type(data) .. "!")
    end
    local shift = 1
    local result = ""
    while (shift < #data) do
        local inflate = _zlib.inflate()
        local inflated, eof, bytes_in, _ = inflate(data:sub(shift))
        assert(eof, "lz: Compressed stream is not complete!")
        shift = shift + bytes_in
        result = result .. inflated -- merge streams for cases when input is multi stream
    end
    return result
end

local function _extract_string(source, options)
    local _result = ""
    local _options =
        _util.merge_tables(
        type(options) == "table" and options or {},
        {
            open_file = function()
                return _result
            end,
            write = function(_, data)
                _result = _result .. data
            end,
            close_file = function()
            end
        },
        true
    )

    _extract(source, nil, _options)
    return _result
end

return _util.generate_safe_functions({
    extract = _extract,
    extract_string = _extract_string,
    extract_from_string = _extract_from_string
})
