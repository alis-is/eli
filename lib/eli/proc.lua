local _util = require"eli.util"
local eprocLoaded, eproc = pcall(require, "eli.proc.extra")
local _sx = require"eli.extensions.string"
local _sep = package.config:sub(1, 1)

local proc = {
	---#DES os.EPROC
	---
	---@type boolean
	EPROC = eprocLoaded,
}

---@class GetStdStreamPartOptions
---@field stdoutRedirectTemplate nil | string
---@field stderrRedirectTemplate nil | string
---@field stdinRedirectTemplate nil | string

proc.settings = {
	stdoutRedirectTemplate = '> "<file>"',
	stderrRedirectTemplate = '2> "<file>"',
	stdinRedirectTemplate = _sep == "\\" and 'type "<file>" |' or 'cat "<file>" |',
}

---Compiles std option into exec template
---@param stdname string
---@param file nil | string
---@param options GetStdStreamPartOptions
---@return string, string?, boolean?
local function _get_stdstream_cmd_part(stdname, file, options)
	local _tmpMode = false
	if file == nil then return "", nil end
	if file == "pipe" then
		file = os.tmpname()
		_tmpMode = true
	end
	if type(file) ~= "string" then
		error("Invalid " .. stdname .. " filename (got: " .. tostring(file) ..
			", expects: string)!")
	end
	if file == "ignore" then return "", nil end
	local _template = options[stdname .. "RedirectTemplate"] or
		proc.settings[stdname .. "RedirectTemplate"]
	if type(_template) == "function" then
		return _template(file), file, _tmpMode
	elseif type(_template) == "string" then
		return _template:gsub("<file>", file), file, _tmpMode
	else
		return "", nil
	end
end

---@class ExecTmpFile
---@field __type '"ELI_EXEC_TMP_FILE"'
---@field __file file*
---@field __closed boolean
---@field path string
local ExecTmpFile = {}
ExecTmpFile.__index = ExecTmpFile

function ExecTmpFile:new(path)
	local _tmpFile = {}
	_tmpFile.path = path
	_tmpFile.__file = io.open(path, "rb")
	_tmpFile.__closed = false

	setmetatable(_tmpFile, self)
	self.__index = self
	self.__type = "ELI_EXEC_TMP_FILE"
	return _tmpFile
end

---@return string
function ExecTmpFile.__tostring() return "ELI_EXEC_TMP_FILE" end

---@param self ExecTmpFile
---@param mode string|number
---@return string
function ExecTmpFile:read(mode) return self.__file:read(mode) end

---@param self ExecTmpFile
function ExecTmpFile:close() return self.__file:close() end

---Handles tmp file removal
---@param self ExecTmpFile
function ExecTmpFile:__gc()
	if not self.__closed then
		self.__file:close()
		os.remove(self.path)
	end
end

---Handles tmp file removal
---@param self ExecTmpFile
function ExecTmpFile:__close()
	if not self.__closed then
		self.__file:close()
		os.remove(self.path)
	end
end

---@class ExecOptions : GetStdStreamPartOptions
---@field stdout nil | string
---@field stderr nil | string
---@field stdin nil | string

---@class ExecResult
---@field exitcode integer
---@field exitType "exit"|"signal"
---@field stdoutStream nil | ExecTmpFile
---@field stderrStream nil | ExecTmpFile

---#DES proc.exec
---
--- Executes specified cmd (waits for exit)
---@param cmd string
---@param options ExecOptions?
---@return ExecResult
function proc.exec(cmd, options)
	if type(options) ~= "table" then options = {} end

	local _stdoutPart, _stdout, _tmpStdout =
		_get_stdstream_cmd_part("stdout", options.stdout, options)
	local _stderrPart, _stderr, _tmpStderr =
		_get_stdstream_cmd_part("stderr", options.stderr, options)
	local _stdinPart = _get_stdstream_cmd_part("stdin", options.stdin, options)

	local _cmd =
		_sx.join_strings(" ", _stdinPart, cmd, _stdoutPart, _stderrPart)
	local _, _exitType, _code = os.execute(_cmd)

	return {
		exitcode = _code,
		exittype = _exitType,
		stdoutStream = _stdout and
			(_tmpStdout and ExecTmpFile:new(_stdout) or io.open(_stdout)),
		stderrStream = _stderr and
			(_tmpStderr and ExecTmpFile:new(_stderr) or io.open(_stderr)),
	}
end

if not eprocLoaded then return _util.generate_safe_functions(proc) end

---@class SpawnResult
---@field exitcode integer
---@field stdoutStream nil | ExecTmpFile
---@field stderrStream nil | ExecTmpFile

---@alias StdType '"ignore"' | '"pipe"' | '"inherit"' | string | file*

---@class SpawnStdio
---@field stdin StdType?
---@field stdout StdType?
---@field stderr StdType?

---@class SpawnOptions
---@field env table<string, string>?
---@field wait boolean?
---@field stdio SpawnStdio | StdType | nil

---@class EliProcessStdioInfo
---@field stdin '"ignore"' | '"pipe"' | '"inherit"' | '"external' | '"file"'
---@field stdout '"ignore"' | '"pipe"' | '"inherit"' | '"external' | '"file"'
---@field stderr '"ignore"' | '"pipe"' | '"inherit"' | '"external' | '"file"'

---@class EliWritableStream
---@field __type '"ELI_STREAM_W_METATABLE"'
---@field wirte fun(self: EliWritableStream, content: string)

---@class EliReadableStream
---@field __type '"ELI_STREAM_R_METATABLE"'
---@field read fun(self: EliReadableStream): string

---@class EliProcess
---@field __type '"ELI_PROCESS"'
---@field __tostring fun(self: EliProcess): string
---@field pid fun(self: EliProcess): integer
---@field wait fun(self: EliProcess, intervalSeconds: integer?, unitsDivider: integer?): integer
---@field kill fun(self: EliProcess, signal: integer?): integer
---@field get_exitcode fun(self: EliProcess): integer
---@field exited fun(self: EliProcess): boolean
---@field get_stdout fun(self: EliProcess): EliWritableStream | nil
---@field get_stderr fun(self: EliProcess): EliReadableStream | file* | nil
---@field get_stdin fun(self: EliProcess): EliReadableStream | file* | nil
---@field get_stdio_info fun(self: EliProcess): EliProcessStdioInfo

---#DES 'proc.generate_spawn_result'
---
---@param _proc EliProcess
---@return SpawnResult
function proc.generate_spawn_result(_proc)
	if ((type(_proc) == "userdata" or type(_proc) == "table") and _proc.__type ~= "ELI_PROCESS") or
	etype(_proc) == "ELI_PROCESS" then
		return {
			exitcode = _proc:get_exitcode(),
			stdoutStream = _proc:get_stdout(),
			stderrStream = _proc:get_stderr(),
		}
	end
	error
	"Generate process result is possible only from ELI_PROCESS data structure!"
end

---#DES 'proc.spawn'
---
---Spawn process from executable in path (wont wait unless wait set to true)
---@param path string
---@param argsOrOptions string[]|SpawnOptions?
---@param options SpawnOptions?
---@return EliProcess | SpawnResult
function proc.spawn(path, argsOrOptions, options)
	if type(argsOrOptions) == "table" and not _util.is_array(argsOrOptions) and type(options) ~= "table" then
		options = argsOrOptions
		argsOrOptions = nil
	end
	if type(options) ~= "table" then options = {} end

	local spawnParams = _util.merge_tables({
		command = path,
		args = argsOrOptions,
	}, options)
	local _proc, err = eproc.spawn(spawnParams)
	if not _proc then error(err) end

	if type(options.wait) == "boolean" and options.wait then
		_proc:wait()
		return proc.generate_spawn_result(_proc)
	end

	if type(options.wait) == "number" and options.wait > 0 then
		local _exitCode = _proc:wait(options.wait)
		if _exitCode >= 0 then return proc.generate_spawn_result(_proc) end
	end

	return _proc
end

---#DES 'proc.get_by_pid'
---
--- gets process by pid
---@param pid integer
---@return EliProcess
function proc.get_by_pid(pid)
	return eproc.get_by_pid(pid)
end

return _util.generate_safe_functions(proc)
