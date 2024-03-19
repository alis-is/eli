local hjson = require"hjson"
local encode_to_hjson = hjson.encode
local encode_to_json = hjson.encode_to_json

local is_tty = require"is_tty".is_stdout_tty()
local exTable = require"eli.extensions.table"
local util = require"eli.util"

local RESET_COLOR = string.char(27) .. "[0m"

---@alias LogLevel '"trace"'|'"debug"'|'"info"'|'"success"'|'"warn"'|'"error"'
---@alias LogLevelInt -2|-1|0|0|1|2

---@class LogMessage
---@field level LogLevel
---@field msg string
---@field module nil|string

---@class LoggerOptions
---@field format '"auto"'|'"standard"'|'"json"'
---@field colorful boolean?
---@field level LogLevel
---@field includeFields boolean?
---@field noTime boolean?

---#DES 'Logger'
---@class Logger
---@field options LoggerOptions
---@field __type '"ELI_LOGGER"'
local Logger = {}
Logger.__index = Logger

---#DES 'Logger:new'
---
---@param self Logger
---@param options LoggerOptions?
---@return Logger
function Logger:new(options)
	local logger = {}
	if type(options) ~= "table" then
		options = {
			format = "auto",
			level = "info",
		}
	end

	options = util.merge_tables(options, {
		format = is_tty and "standard" or "json",
		colorful = is_tty,
		level = "info",
		includeFields = true,
		noTime = false,
	})

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

local colorMap = {
	["success"] = string.char(27) .. "[32m",
	["debug"] = string.char(27) .. "[30;1m",
	["trace"] = string.char(27) .. "[30;1m",
	["info"] = string.char(27) .. "[36m",
	["warn"] = string.char(27) .. "[33m",
	["warning"] = string.char(27) .. "[33m",
	["error"] = string.char(27) .. "[31m",
}

---returns color based on log level
---@param level LogLevel
---@return string
local function get_log_color(level)
	if colorMap[level] then
		return colorMap[level]
	end
	return RESET_COLOR
end

local levelValueMap = {
	["error"] = 2,
	["warn"] = 1,
	["warning"] = 1,
	["success"] = 0,
	["info"] = 0,
	["debug"] = -1,
	["trace"] = -2,
}

---returns integer equivalent of log level
---@param level LogLevel
---@return LogLevelInt
local function level_value(level)
	if type(level) ~= "string" then return 0 end
	local lvl = levelValueMap[level]
	if (type(lvl) == nil) then return 0 end
	return lvl
end

---prints log
---comment
---@param data LogMessage
---@param colorful boolean
---@param color string
---@param noTime boolean
---@param includeFields boolean|string[]
local function log_txt(data, colorful, color, noTime, includeFields)
	local module = ""
	if data.module ~= nil and data.module ~= "" then
		module = "(" .. tostring(data.module) .. ") "
	end

	local time = not noTime and os.date"%H:%M:%S" or ""

	if data.msg:sub(#data.msg, #data.msg) == "\n" then
		data.msg = data.msg:sub(1, #data.msg - 1)
	end

	if includeFields then
		if not exTable.is_array(includeFields) then
			includeFields = exTable.filter(exTable.keys(data), function (_, v)
				return v ~= "msg" and v ~= "module" and v ~= "level"
			end)
		end

		local _fields = {}
		local _any = false
		for _, v in ipairs(includeFields --[[@as table]]) do
			_any = true
			_fields[v] = data[v]
		end
		local _addition = _any and ("\n" .. encode_to_hjson(_fields)) or ""
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
	print(encode_to_json(data, { indent = false, skipkeys = true }))
end

---makes sure string is converted to EliLogMessage
---@param msg LogMessage | string
---@return LogMessage
local function wrap_msg(msg)
	if type(msg) ~= "table" then
		return { msg = msg, level = "info" } --[[@as LogMessage]]
	end
	return msg --[[@as LogMessage]]
end

---#DES 'Logger:log'
---
---Logs message with specified level
---@param self Logger
---@param msg LogMessage | string
---@param level LogLevel
---@param vars table?
function Logger:log(msg, level, vars)
	msg = wrap_msg(msg)
	if level ~= nil then
		msg.level = level
	end

	msg.msg = string.interpolate(msg.msg, vars)

	if level_value(self.options.level) > level_value(msg.level) then
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
---@param msg LogMessage | string
---@param vars table?
function Logger:success(msg, vars)
	self:log(msg, "success", vars)
end

---#DES 'Logger:debug'
---
---@param self Logger
---@param msg LogMessage | string
---@param vars table?
function Logger:debug(msg, vars)
	self:log(msg, "debug", vars)
end

---#DES 'Logger:trace'
---
---@param self Logger
---@param msg LogMessage | string
---@param vars table?
function Logger:trace(msg, vars)
	self:log(msg, "trace", vars)
end

---#DES 'Logger:info'
---
---@param self Logger
---@param msg LogMessage | string
---@param vars table?
function Logger:info(msg, vars)
	self:log(msg, "info", vars)
end

---#DES 'Logger:warn'
---
---@param self Logger
---@param msg LogMessage | string
---@param vars table?
function Logger:warn(msg, vars)
	self:log(msg, "warn", vars)
end

---#DES 'Logger:error'
---
---@param self Logger
---@param msg LogMessage | string
---@param vars table?
function Logger:error(msg, vars)
	self:log(msg, "error", vars)
end

return Logger
