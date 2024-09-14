local ok, stream_extra = pcall(require, "eli.stream.extra")

if not ok then
    return {
        globalize = function ()
            return
        end,
    }
end

---@class file*
---@field as_stream fun(self: file*): EliReadableStream | EliWritableStream | EliRWStream

---#DES 'io.file_as_stream'
---
---@param file file*
---@return EliReadableStream | EliWritableStream | EliRWStream
local function file_as_stream(file)
    if not ok then
        error"eli.stream is not available"
    end
    return stream_extra.file_as_stream(file)
end

---#DES 'io.stream_as_filestream'
---
---@param stream EliReadableStream | EliWritableStream | EliRWStream
---@return file*
local function stream_as_filestream(stream)
    if not ok then
        error"eli.stream is not available"
    end

    return stream_extra.stream_as_filestream(stream)
end

return {
    file_as_stream = file_as_stream,
    stream_as_filestream = stream_as_filestream,
    globalize = function ()
        stream_extra.extend_file_metatable()
    end,
}
