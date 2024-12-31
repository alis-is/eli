local util = require"eli.util"
local is_proc_extra_loaded, proc_extra = pcall(require, "eli.proc.extra")
local string_extensions = require"eli.extensions.string"
local separator = package.config:sub(1, 1)

local proc = {
	---#DES os.EPROC
	---
	---@type boolean
	EPROC = is_proc_extra_loaded,
}

---@class GetStdStreamPartOptions
---@field stdout_redirect_template string?
---@field stderr_redirect_template string?
---@field stdin_redirect_template string?

proc.settings = {
	stdout_redirect_template = '> "<file>"',
	stderr_redirect_template = '2> "<file>"',
	stdin_redirect_template = separator == "\\" and 'type "<file>" |' or 'cat "<file>" |',
}

---Compiles std option into exec template
---@param stdname string
---@param file string?
---@param options GetStdStreamPartOptions
---@return string, string?, boolean?
local function get_stdstream_cmd_part(stdname, file, options)
	local is_tmp_file_mode = false
	if file == nil then return "", nil end
	if file == "pipe" then
		file = os.tmpname()
		is_tmp_file_mode = true
	end
	if type(file) ~= "string" then
		error("Invalid " .. stdname .. " filename (got: " .. tostring(file) ..
			", expects: string)!")
	end
	if file == "ignore" then return "", nil end
	local template = options[stdname .. "_redirect_template"] or
	   proc.settings[stdname .. "_redirect_template"]
	if type(template) == "function" then
		return template(file), file, is_tmp_file_mode
	elseif type(template) == "string" then
		return template:gsub("<file>", file), file, is_tmp_file_mode
	else
		return "", nil
	end
end

---@class ExecTmpFile
---@field __type '"ELI_EXEC_TMP_FILE"'
---@field __file file*
---@field __closed boolean
---@field path string
---@field read fun(self: ExecTmpFile, mode: integer | "a" | "l" | "L"): string
---@field close fun(self: ExecTmpFile)
local ExecTmpFile = {}
ExecTmpFile.__index = ExecTmpFile

---#DES 'ExecTmpFile:new'
---
---@param path string
function ExecTmpFile:new(path)
	local tmp_file = {}
	tmp_file.path = path
	tmp_file.__file = io.open(path, "rb")
	tmp_file.__closed = false

	setmetatable(tmp_file, self)
	self.__index = self
	self.__type = "ELI_EXEC_TMP_FILE"
	return tmp_file
end

---@return string
function ExecTmpFile.__tostring() return "ELI_EXEC_TMP_FILE" end

---#DES 'ExecTmpFile:read'
---
---@param self ExecTmpFile
---@param mode integer | "a" | "l" | "L"
---@return string
function ExecTmpFile:read(mode) return self.__file:read(mode) end

---#DES 'ExecTmpFile:close'
---
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
---@field stdout string?
---@field stderr string?
---@field stdin string?

---@class ExecResult
---@field exit_code integer
---@field exit_type "exit"|"signal"
---@field stdout_stream ExecTmpFile?
---@field stderr_stream ExecTmpFile?

---#DES proc.exec
---
--- Executes specified cmd (waits for exit)
---@param cmd string
---@param options ExecOptions?
---@return ExecResult
function proc.exec(cmd, options)
	if type(options) ~= "table" then options = {} end

	local stdout_cmd_part, stdout_tmp_file_path, is_stdout_tmp =
	   get_stdstream_cmd_part("stdout", options.stdout, options)
	local stderr_cmd_part, stderr_tmp_file_path, is_stderr_tmp =
	   get_stdstream_cmd_part("stderr", options.stderr, options)
	local stdin_cmd_part = get_stdstream_cmd_part("stdin", options.stdin, options)

	local cmd =
	   string_extensions.join_strings(" ", stdin_cmd_part, cmd, stdout_cmd_part, stderr_cmd_part)
	local _, exit_type, exit_code = os.execute(cmd)

	return {
		exit_code = exit_code,
		exit_type = exit_type,
		stdout_stream = stdout_tmp_file_path and
		   (is_stdout_tmp and ExecTmpFile:new(stdout_tmp_file_path) or io.open(stdout_tmp_file_path)),
		stderr_stream = stderr_tmp_file_path and
		   (is_stderr_tmp and ExecTmpFile:new(stderr_tmp_file_path) or io.open(stderr_tmp_file_path)),
	} --[[@as ExecResult]]
end

if not is_proc_extra_loaded then return util.generate_safe_functions(proc) end

---@class SpawnResult
---@field exit_code integer
---@field stdout_stream ExecTmpFile?
---@field stderr_stream ExecTmpFile?

---@alias StdType '"ignore"' | '"pipe"' | '"inherit"' | string | file*

---@class SpawnStdio
---@field stdin StdType?
---@field stdout StdType?
---@field stderr StdType?

---@class SpawnOptions
---@field env table<string, string>?
---@field wait boolean?
---@field stdio SpawnStdio | StdType | nil
---@field create_process_group boolean? create new process group (preffered over process_group)
---@field process_group EliProcessGroup? process group to run process in
---@field username string? user to run process as (may require root)
---@field password string? password for user to run process as (only on windows, not implemented yet)

---@class EliProcessStdioInfo
---@field stdin '"ignore"' | '"pipe"' | '"inherit"' | '"external' | '"file"'
---@field stdout '"ignore"' | '"pipe"' | '"inherit"' | '"external' | '"file"'
---@field stderr '"ignore"' | '"pipe"' | '"inherit"' | '"external' | '"file"'

---@class EliStreamBase
---@field close fun(self: EliReadableStream)

---@class EliWritableStream : EliStreamBase
---@field __type '"ELI_STREAM_W_METATABLE"'
---@field write fun(self: EliWritableStream, content: string)

---@class EliReadableStream : EliStreamBase
---@field __type '"ELI_STREAM_R_METATABLE"'
---@field read fun(self: EliReadableStream, opt: integer | "a" | "l" | "L", timeout: integer?,  divider_or_units: "s" | "ms" | integer | nil): string

---@class EliRWStream: EliReadableStream, EliWritableStream
---@field __type '"ELI_STREAM_RW_METATABLE"'

---@class EliProcessGroup
---@field kill fun(self: EliProcessGroup, signal: integer?): integer

---@class EliProcess
---@field __type '"ELI_PROCESS"'
---@field __tostring fun(self: EliProcess): string
---@field get_pid fun(self: EliProcess): integer
---@field wait fun(self: EliProcess, intervalSeconds: integer?, unitsDivider: integer | '"s"' | '"ms"' | nil): integer
---@field kill fun(self: EliProcess, signal: integer?): integer
---@field get_exit_code fun(self: EliProcess): integer
---@field exited fun(self: EliProcess): boolean
---@field get_stdout fun(self: EliProcess): EliReadableStream | nil
---@field get_stderr fun(self: EliProcess): EliReadableStream | file* | nil
---@field get_stdin fun(self: EliProcess): EliWritableStream | file* | nil
---@field get_stdio_info fun(self: EliProcess): EliProcessStdioInfo
---@field get_group fun(self: EliProcess): EliProcessGroup | nil

---#DES 'proc.generate_spawn_result'
---
---@param process EliProcess
---@return SpawnResult
function proc.generate_spawn_result(process)
	if ((type(process) == "userdata" or type(process) == "table") and process.__type ~= "ELI_PROCESS") or
	etype(process) == "ELI_PROCESS" then
		return {
			exit_code = process:get_exit_code(),
			stdout_stream = process:get_stdout(),
			stderr_stream = process:get_stderr(),
		} --[[@as SpawnResult]]
	end
	error
	"Generate process result is possible only from ELI_PROCESS data structure!"
end

---#DES 'proc.spawn'
---
---Spawn process from executable in path (wont wait unless wait set to true)
---@param path string
---@param args_or_options string[]|SpawnOptions?
---@param options SpawnOptions?
---@return EliProcess | SpawnResult
function proc.spawn(path, args_or_options, options)
	if type(args_or_options) == "table" and not util.is_array(args_or_options) and type(options) ~= "table" then
		options = args_or_options
		args_or_options = nil
	end
	if type(options) ~= "table" then options = {} end

	-- // TODO: remove in the next version
	if options.createProcessGroup ~= nil and options.create_process_group then
		options.create_process_group = options.createProcessGroup
		print"createProcessGroup is deprecated, use create_process_group instead"
	end

	local spawnParams = util.merge_tables({
		command = path,
		args = args_or_options,
	}, options)
	local process, err = proc_extra.spawn(spawnParams)
	if not process then error(err) end

	if type(options.wait) == "boolean" and options.wait then
		process:wait()
		return proc.generate_spawn_result(process)
	end

	if type(options.wait) == "number" and options.wait > 0 then
		local exit_code = process:wait(options.wait)
		if exit_code >= 0 then return proc.generate_spawn_result(process) end
	end

	return process
end

---@class GetByPidOptions
---@field is_separate_process_group boolean?

---#DES 'proc.get_by_pid'
---
--- gets process by pid
---@param pid integer
---@param options GetByPidOptions?
---@return EliProcess
function proc.get_by_pid(pid, options)
	return proc_extra.get_by_pid(pid, options)
end

return util.generate_safe_functions(proc)
