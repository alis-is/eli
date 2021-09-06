local hjson = require"hjson"
local encode_to_hjson = hjson.encode
local encode_to_json = hjson.encode_to_json

local is_tty = require "is_tty".is_stdout_tty()
local _util = require"eli.util"
local _exTable = require"eli.extensions.table"

local RESET_COLOR = string.char(27) .. "[0m"

---@alias LogLevel '"trace"'|'"debug"'|'"info"'|'"success"'|'"warn"'|'"error"'
---@alias LogLevelInt '-2'|'-1'|'0'|'0'|'1'|'2'

---@class LogMessage
---@field level LogLevel
---@field msg string
---@field module nil|string


---@class EliLoggerOptions
---@field format '"auto"'|'"standard"'|'"json"'
---@field colorful boolean
---@field level LogLevel
---@field includeFields boolean
---@field noTime boolean

---#DES 'Logger'
---@class Logger
---@field options EliLoggerOptions
---@field __type '"ELI_LOGGER"'
local Logger = {}
Logger.__index = Logger

---#DES 'Logger:new'
---
---@param self Logger
---@param options EliLoggerOptions
---@return Logger
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

    if options.noTime == nil then
        options.noTime = false
    end

    logger.options = options

    setmetatable(logger, self)
    self.__type = "ELI_LOGGER"
    self.__index = self
    return logger
end

---#DES 'Logger.__tostring'
---
---@return string
function Logger.__tostring()
    return "ELI_LOGGER"
end

---returns color based on log level
---@param level LogLevel
---@return string
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

---returns integer equivalent of log level
---@param level LogLevel
---@return LogLevelInt
local function _level_value(level)
    if type(level) ~= 'string' then return 0 end
    local _lvl = _levelValueMap[level]
    if (type(_lvl) == nil) then return 0 end
    return _lvl
end

---prints log
---comment
---@param data LogMessage
---@param colorful boolean
---@param color string
---@param noTime boolean
---@param includeFields boolean
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

        if not _util.is_array(includeFields) then
            includeFields = _exTable.filter(_exTable.keys(data), function(_,v)
                return v ~= 'msg' and v ~= 'module' and v ~= 'level'
            end)
        end

        local _fields = {}
        local _any = false
        for _,v in ipairs(includeFields) do
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

---prints log in json format
---@param data table
local function log_json(data)
    data.timestamp = os.time()
    print(encode_to_json(data, {indent = false, skipkeys = true}))
end

local function wrap_msg(msg)
    if type(msg) ~= 'table' then
        return {msg = msg, level = "info"}
    end
    return msg
end

---#DES 'Logger:log'
---
---Logs message with specified level
---@param self Logger
---@param msg LogMessage
---@param level LogLevel
function Logger:log(msg, level)
    msg = wrap_msg(msg)
    if level ~= nil then
        msg.level = level
    end
    if _level_value(self.options.level) > _level_value(level) then
        return
    end

    if self.options.format == "json" then
        log_json(msg)
    else
        local color = get_log_color(msg.level)
        log_txt(msg, self.options.colorful, color, self.options.noTime, self.options.includeFields)
    end
end

---#DES 'Logger:success'
---
---@param self Logger
---@param msg LogMessage
function Logger:success(msg)
    self:log(msg, "success")
end

---#DES 'Logger:debug'
---
---@param self Logger
---@param msg LogMessage
function Logger:debug(msg)
    self:log(msg, "debug")
end

---#DES 'Logger:trace'
---
---@param self Logger
---@param msg LogMessage
function Logger:trace(msg)
    self:log(msg, "trace")
end

---#DES 'Logger:info'
---
---@param self Logger
---@param msg LogMessage
function Logger:info(msg)
    self:log(msg, "info")
end

---#DES 'Logger:warn'
---
---@param self Logger
---@param msg LogMessage
function Logger:warn(msg)
    self:log(msg, "warn")
end

---#DES 'Logger:error'
---
---@param self Logger
---@param msg LogMessage
function Logger:error(msg)
    self:log(msg, "error")
end

return Logger
