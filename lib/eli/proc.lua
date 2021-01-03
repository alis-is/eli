local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables
local clone = util.clone
local eprocLoaded, eproc = pcall(require, "eli.proc.extra")

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
