local _string = require"eli.extensions.string"

local global = {}

---#DES 'printf'
---
---Prints string with interpolation in C printf way in case of string varargs
---interpolating with table varargs if any ${varName} applicable
---@param format string
---@param ... any
function global.printf(format, ...)
    local _args = table.pack(...)
    for i, v in ipairs(_args) do
        if type(v) == 'table' and not util.is_array(_args[1]) then
            -- interpolate
            local _interpolationTable = table.remove(_args, i)
            format = _string.interpolate(format, _interpolationTable)
        end
    end
    return io.write(string.format(format, ...))
end

return global