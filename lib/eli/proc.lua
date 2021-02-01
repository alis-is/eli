local _util = require "eli.util"
local eprocLoaded, eproc = pcall(require, "eli.proc.extra")
local _sx = require"eli.extensions.string"

local settings = {
   stdoutRedirectTemplate = '> "<file>"',
   stderrRedirectTemplate = '2> "<file>"',
   stdinRedirectTemplate = 'type "<file>" |',
}

local function _set_settings(param, value)
   if type(param) == "string" then
      settings[param] = value
   elseif type(param) == "table" then
      settings = _util.merge_tables(settings, param)
   end
end

local function _get_stdstream_cmd_part(stdname, file, options)
   local _tmpMode = false
   if file == nil then
      return "", nil
   end
   if file == "pipe" then
      file = os.tmpname()
      _tmpMode = true
   end
   if type(file) ~= "string" then
      error("Invalid " .. stdname .. " filename (got: " .. tostring(file) .. ", expects: string)!")
   end
   if file == "ignore" then return "", nil end
   local _template = options[stdname.. "RedirectTemplate"] or settings[stdname.. "RedirectTemplate"]
   if type(_template) == "function" then
      return _template(file), file, _tmpMode
   elseif type(_template) == "string" then
      return _template:gsub("<file>", file), file, _tmpMode
   else
      return "", nil
   end
end

local ExecTmpFile = {}
ExecTmpFile.__index = ExecTmpFile

function ExecTmpFile:new(path)
   local _tmpFile = {}
   _tmpFile.path = path
   _tmpFile.__file = io.open(path)

   setmetatable(_tmpFile, self)
   self.__index = self
   self.__type = "ELI_EXEC_TMP_FILE"
   return _tmpFile
end

function ExecTmpFile:__tostring()
   return "ELI_EXEC_TMP_FILE"
end

function ExecTmpFile:read(mode)
   return self.__file:read(mode)
end

function ExecTmpFile:close(mode)
   return self.__file:close(mode)
end

function ExecTmpFile:__gc()
   self.__file:close()
   os.remove(self.path)
end

local function _exec(cmd, options)
   if type(options) ~= "table" then options = {} end

   local _stdoutPart, _stdout, _tmpStdout = _get_stdstream_cmd_part("stdout", options.stdout, options)
   local _stderrPart, _stderr, _tmpStderr = _get_stdstream_cmd_part("stderr", options.stderr, options)
   local _stdinPart = _get_stdstream_cmd_part("stdin", options.stdin, options)

   local _cmd = _sx.join_strings(" ", _stdinPart, cmd, _stdoutPart, _stderrPart)
   local _, _exitType, _code = os.execute(_cmd)

   return {
      exitcode = _code,
      exittype = _exitType,
      stdoutStream = _stdout and (_tmpStdout and ExecTmpFile:new(_stdout) or io.open(_stdout)),
      stderrStream = _stderr and (_tmpStderr and ExecTmpFile:new(_stderr) or io.open(_stderr))
   }
end

local proc = {
   exec = _exec,
   set_settings = _set_settings,
   EPROC = eprocLoaded
}

if not eprocLoaded then
   return _util.generate_safe_functions(proc)
end

local function _generate_exec_result(_proc)
   if (type(_proc) ~= "userdata" and type(_proc) ~= "table") or
      (_proc.__type ~= "ELI_PROCESS") then
	   return nil, "Generate process result is possible only from ELI_PROCESS data structure!"
   end
   return {
      exitcode = _proc:get_exitcode(),
      stdoutStream = _proc:get_stdout(),
      stderrStream = _proc:get_stderr()
   }
end

local function _spawn(file, args, options)
   if type(options) ~= "table" then
      options = {}
   end

   local _proc, err = eproc.spawn { command = file, args = args, env = options.env, stdio = options.stdio}
   if not _proc then
      return _proc, err
   end

   if type(options.wait) == "boolean" and options.wait then
      _proc:wait()
      return _generate_exec_result(_proc)
   end

   if type(options.wait) == "number" and options.wait > 0 then
      local _exitCode =_proc:wait(options.wait)
      if _exitCode >= 0 then
         return _generate_exec_result(_proc)
      end
   end

   return _proc
end

proc.spawn = _spawn

return _util.generate_safe_functions(proc)
