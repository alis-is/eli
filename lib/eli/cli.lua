local util = require"eli.util"

local cli = {}

---@class CliArg
---@field type "option"|"parameter"
---@field value string|boolean
---@field id string
---@field arg string

---#DES cli.parse_args
---
---Parses array of arguments
---@param args string[]|nil
---@return CliArg[]
function cli.parse_args(args)
    if not util.is_array(args) then
        args = arg
    end
    local arg_list = {}
    if args == nil then return arg_list end
    for i = 1, #args, 1 do
        local arg = args[i]
        if type(arg) == "string" then
            local cli_option = arg:match"^-[-]?([^=]*)"
            if cli_option then -- option
                local _value = arg:match"^[^=]*=(.*)" or true
                table.insert(arg_list, { type = "option", value = _value, id = cli_option, arg = arg })
            else -- command or parameter
                table.insert(arg_list, { type = "parameter", value = arg, id = arg, arg = arg })
            end
        elseif type(arg) == "table" then -- passthrough pre processed args
            table.insert(arg_list, arg)
        end
    end
    return arg_list
end

return cli
