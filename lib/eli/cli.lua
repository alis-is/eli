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
        args = _G.arg
    end
    local parsed_args = {}
    if args == nil then return parsed_args end
    for i = 1, #args, 1 do
        local current = args[i]
        if type(current) == "string" then
            local cli_option, cli_value = current:match"^%-%-?([^=]+)=?(.*)"
            if cli_option then
                local value = cli_value ~= "" and cli_value or true
                table.insert(parsed_args, {
                    type = "option",
                    id = cli_option,
                    value = value,
                    arg = current,
                })
            else
                table.insert(parsed_args, {
                    type = "parameter",
                    id = current,
                    value = current,
                    arg = current,
                })
            end
        elseif type(current) == "table" then -- passthrough pre processed args
            table.insert(parsed_args, current)
        end
    end
    return parsed_args
end

return cli
