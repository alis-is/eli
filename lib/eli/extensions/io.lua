local ok, stream_extra = pcall(require, "eli.stream.extra")

if not ok then
    return {}
end

---#DES 'io.open_fstream'
---
---@param filename string
---@param mode?    openmode
---@return EliReadableStream | EliWritableStream | EliRWStream | nil
---@return string? errmsg
local function open_fstream(filename, mode)
    if not ok then
        error"eli.stream is not available"
    end

    return stream_extra.open_fstream(filename, mode)
end

return {
    open_fstream = open_fstream,
}
