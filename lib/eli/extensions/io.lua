local ok, stream_extra = pcall(require, "eli.stream.extra")

if not ok then
    return {}
end

local eio = {}

---#DES 'io.open_fstream'
---
---@param filename string
---@param mode?    openmode
---@return EliReadableStream | EliWritableStream | EliRWStream | nil
---@return string? errmsg
function eio.open_fstream(filename, mode)
    if not ok then
        return nil, "eli.stream is not available"
    end

    return stream_extra.open_fstream(filename, mode)
end

function eio.globalize()
    io.open_fstream = eio.open_fstream
end

return eio
