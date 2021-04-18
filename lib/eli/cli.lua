local _util = require("eli.util")

---@class CliArg
---#DES 'CliArg.type'
---@field type "option"|"parameter"
---#DES 'CliArg.value'
---@field value string|boolean
---#DES 'CliArg.id'
---@field id string
---#DES 'CliArg.arg'
---
---the cli argument this CliArg was created from
---@field arg string

---#DES cli.parse_args
---
---Parses array of arguments
---@param args string[]
---@return CliArg[]
local function _parse_args(args)
    if not _util.is_array(args) then
        args = arg
    end
    local _argList = {}

    for i = 1, #args, 1 do
        local _arg = args[i]
        if type(_arg) == "string" then
            local _cliOption = _arg:match "^-[-]?([^=]*)"
            if _cliOption then -- option
                local _value = _arg:match("^[^=]*=(.*)") or true
                table.insert(_argList, {type = "option", value = _value, id = _cliOption, arg = _arg})
            else -- command or parameter
                table.insert(_argList, {type = "parameter", value = _arg, id = _arg, arg = _arg})
            end
        elseif type(_arg) == 'table' then -- passthrough pre processed args
            table.insert(_argList, _arg)
        end
    end
    return _argList
end

return {
    parse_args = _parse_args
}
