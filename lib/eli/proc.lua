local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables
local clone = util.clone
local eprocLoaded, eproc = pcall(require, "eli.proc.extra")

local function _generate_exec_result(_proc)
   if (type(_proc) ~= "userdata" and type(_proc) ~= "table") or
      (_proc.__type ~= "ELI_PROCESS" and _proc.__type ~= "ELI_PROCESS_COMPAT") then
	   return nil, "Generate process result is possible only from ELI_PROCESS or ELI_PROCESS_COMPAT data structure!"
   end
   return {
      exitcode = _proc:get_exitcode(),
      stdoutStream = _proc:get_stdout(),
      stderrStream = _proc:get_stderr()
   }
end

--[[ EliProcessCompat - mimics proc.extra
      - we wait for full execution
      - get_stdio_info
      - get_stderr
      - get_stdout
      - get_stdin returns nil always
      - get_exitcode
      - exited always true as we wait always
      - kill just returns as process had to exit
      - pid returns -1/nil ???
]]

local EliProcessCompat = {}
EliProcessCompat.__index = EliProcessCompat

function EliProcessCompat:new(options)
   local _epc = {}
   _epc.__type = "ELI_PROCESS_COMPAT"
   _epc.__tostring = function ()
      return "ELI_PROCESS_COMPAT"
   end
   _epc.__internal = options

   setmetatable(_epc, self)
   self.__index = self
   return _epc
end

function EliProcessCompat:wait()
   return _generate_exec_result(self)
end

function EliProcessCompat:get_stdout()
   return self.__internal.stdout
end

function EliProcessCompat:get_stderr()
   return self.__internal.stderr
end

function EliProcessCompat:get_stdin()
   return nil
end

function EliProcessCompat:get_exitcode()
   return self.__internal.exitcode
end

function EliProcessCompat:get_stdio_info()
 --[[ // TODO ]]
end

function EliProcessCompat:kill()
   return self:get_exitcode()
end

function EliProcessCompat:exited()
   return true
end

local function _stdoption_to_filename(stdStreamOption)
   if stdStreamOption == "pipe" then
      return os.tmpname
   elseif type(stdStreamOption) == "string" then
      return stdStreamOption
   end
   return "ignore"
end

local function _exec(cmd, options)
   if type(options) ~= "table" then
      options = {}
   end
   if type(options.stdio) ~= "table" then
      if type(options.stdio) == "string" then
         options.stdio = {
            stdout = options.stdio,
            stderr= options.stdio
         }
      else
         options.stdio = {
            stdout = "ignore",
            stderr = "ignore"
         }
      end
   end

   local _injectStdout = ""
   local _stdoutFile =_stdoption_to_filename(options.stdio.stdout)
   if _stdoutFile ~= "ignore" then
      _injectStdout = " >" .. _stdoutFile
   end

   local _injectStderr = ""
   local _stderrFile =_stdoption_to_filename(options.stdio.stderr)
   if _stderrFile ~= "ignore" then
      _injectStdout = " >" .. _stderrFile
   end

   local _cmdline = cmd .. _injectStdout .. _injectStderr
   local _, _, _exitcode = os.execute(_cmdline)

--[[
   create lua temporary file here
   custom metatable with removal on gc or close
]]

   local _result = EliProcessCompat:new({
      stdoutStream = io.open(_stdoutFile),
      stderrStream = io.open(_stdoutFile),
      exitcode = _exitcode
   })
   if options.wait then 
      return _generate_exec_result(_result)
   end
end

local proc = {
   exec = _exec,
   EPROC = eprocLoaded
}

if not eprocLoaded then
   return proc
end
local epipe = require"eli.pipe.extra"

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

return generate_safe_functions(merge_tables(proc, eproc, true))
