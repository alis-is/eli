local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables
local eprocLoaded, eproc = pcall(require, "eli.proc.extra")

local function _io_execute(cmd)
   local _processFile = io.popen(cmd)
   local _output = _processFile:read "a*"
   local _ok, _exitCode = _processFile:close()
   return _ok, _exitCode, _output
end

local proc = {
   io_execute = _io_execute,
   os_execute = os.execute,
   safe_io_execute = _io_execute,
   safe_os_execute = os.execute,
   EPROC = eprocLoaded
}

if not eprocLoaded then
   return proc
end
local epipe = require"eli.pipe.extra"

local function _generate_exec_result(_proc)
   if (type(_proc) ~= "userdata" and type(_proc) ~= "table")  or _proc.__type ~= "ELI_PROCESS" then
	return nil, "Can not generate process from non ELI_PROCESS data structure!"
   end
   return {
      exitcode = _proc:get_exitcode(),
      stdoutStream = _proc:get_stdout(),
      stderrStream = _proc:get_stderr()
   }
end

local function _execute(file, args, options)
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

proc.execute = _execute

return generate_safe_functions(merge_tables(proc, eproc))
