local hjson = require"hjson"
local encode_to_hjson = hjson.encode
local encode_to_json = hjson.encode_to_json

local is_tty = require "is_tty".is_stdout_tty()
local util = require"eli.util"

local RESET_COLOR = string.char(27) .. "[0m"

local Logger = {}
Logger.__index = Logger

function Logger:new(options)
    local logger = {}
    if options == nil then
        options = {}
    end
    if options.format == nil then
        options.format = "auto"
    end
    if options.format == "auto" then
        options.format = is_tty and "standard" or "json"
    end
    if options.colorful == nil then
        options.colorful = is_tty
    end

    if options.level == nil then
        options.level = "info"
    end

    if options.includeFields == nil then
        options.includeFields = true
    end

    logger.__type = "ELI_LOGGER"
    logger.options = options

    setmetatable(logger, self)
    self.__index = self
    return logger
end

local function get_log_color(level)
    if level == "success" then
        return string.char(27) .. "[32m"
    elseif level == "debug" then
        return string.char(27) .. "[30;1m"
    elseif level == "trace" then
        return string.char(27) .. "[30;1m"
    elseif level == "info" then
        return string.char(27) .. "[36m"
    elseif level == "warn" then
        return string.char(27) .. "[33m"
    elseif level == "error" then
        return string.char(27) .. "[31m"
    else
        return RESET_COLOR
    end
end

local _levelValueMap = {
    ["error"] = 2,
    ["warn"] = 1,
    ["success"] = 0,
    ["info"] = 0,
    ["debug"] = -1,
    ["trace"] = -2,
}

local function _level_value(lvl)
    if type(lvl) ~= 'string' then return 0 end
    local _lvl = _levelValueMap[lvl]
    if (type(_lvl) == nil) then return 0 end 
    return _lvl
end

local function log_txt(data, colorful, color, noTime, includeFields)
    local module = ""
    if data.module ~= nil and data.module ~= "" then
        module = "(" .. tostring(data.module) .. ") "
    end

    local time = not noTime and os.date("%H:%M:%S") or ""

    if data.msg:sub(#data.msg, #data.msg) == '\n' then
        data.msg = data.msg:sub(1, #data.msg - 1)
    end

    if includeFields then 

        if not util.is_array(includeFields) then
            includeFields = util.filter_table(util.keys(data), function(k,v) return v ~= 'msg' and v ~= 'module' and v ~= 'level' end)
        end

        local _fields = {}
        local _any = false
        for i,v in ipairs(includeFields) do 
            _any = true
            _fields[v] = data[v]
        end
        local _addition = _any and ('\n' .. encode_to_hjson(_fields)) or ''
        data.msg = data.msg .. _addition
    end

    if colorful then
        print(color .. time .. " [" .. string.upper(data.level) .. "] " .. module .. data.msg .. RESET_COLOR)
    else
        print(time .. " [" .. string.upper(data.level) .. "] " .. module .. data.msg)
    end
end

local function log_json(data)
    data.timestamp = os.time(os.date("!*t"))
    print(encode_to_json(data, {indent = false, skipkeys = true}))
end

local function wrap_msg(msg)
    if type(msg) ~= 'table' then
        return {msg = msg, level = "info"}
    end
    return msg
end

function Logger:log(msg, lvl, options)
    local noTime = type(options) == "table" and options.noTime or false

    msg = wrap_msg(msg)
    if lvl ~= nil then
        msg.level = lvl
    end
    if _level_value(self.options.level) > _level_value(lvl) then 
        return
    end

    if self.options.format == "json" then
        log_json(msg)
    else
        local color = get_log_color(msg.level)
        log_txt(msg, self.options.colorful, color, self.options.noTime, self.options.includeFields)
    end
end

function Logger:success(msg, options)
    self:log(msg, "success", options)
end

function Logger:debug(msg, options)
    self:log(msg, "debug", options)
end

function Logger:trace(msg, options)
    self:log(msg, "trace", options)
end

function Logger:info(msg, options)
    self:log(msg, "info", options)
end

function Logger:warn(msg, options)
    self:log(msg, "warn", options)
end

function Logger:error(msg, options)
    self:log(msg, "error", options)
end

return Logger
