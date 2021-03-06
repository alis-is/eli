local lz = require "lz"

-- decodes entries stream (requires gz stream to be complete)
local function _extract_string(data)
    if type(data) ~= "string" then
        error("lz: Unsupported compressed data type: ".. type(data) .. "!")
    end
    local shift = 0
    local result = ""
    while (shift ~= #data) do
        local inflate = lz.inflate()
        local inflated, eof, bytes_in, _ = inflate(data:sub(0))
        assert(eof, "lz: Compressed stream is not complete!")
        shift = shift + bytes_in
        result = result .. inflated -- merge streams for cases when input is multi stream
    end
    return result
end

local function _extract(source, destination, options)
    local _sf = io.open(source)
    local _df = io.open(destination, "w")
    assert(_sf, "lz: Failed to open source file " .. tostring(source) .. "!")
    assert(_df, "lz: Failed to open destination file " .. tostring(source) .. "!")

    if type(options) ~= "table" then
        options = {}
    end

    if type(options.chunkSize) ~= "number" then
        options.chunkSize = 4096
    end

    local inflate = lz.inflate()
    local shift = 0
    while true do
        local _data = _sf:read(options.chunkSize)
        if not _data then
            break
        end
        local inflated, eof, bytes_in, _ = inflate(options.chunkSize)
        if eof then -- we got end of gzip stream we return to bytes_in pos in case there are multiple stream embedded
            _sf:seek("set", shift + bytes_in)
            shift = shift + bytes_in
            inflate = lz.inflate()
            _df:write(inflated)
        end
    end
    _sf:close()
    _df:close()
end

return {
    extract = _extract,
    extract_string = _extract_string
}