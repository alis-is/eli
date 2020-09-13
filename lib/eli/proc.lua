local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables
local eprocLoaded, eproc = pcall(require, "eli.proc.extra")
local fs = require "eli.fs"

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

if not eprocLoaded or type(fs.pipe) ~= "function" then
   return proc
end

local function _close_fd(f)
   if (type(f) == "table" or type(f) == "userdata") and type(f.close) == "function" then
      f:close()
   end
end

local function _read_fd(f)
   if (type(f) == "table" or type(f) == "userdata") and type(f.read) == "function" then
      return f:read("a")
   end
   return nil
end

local function _create_pipe(pipe, stdio)
   local rd, wr
   if type(pipe) == "string" then
      wr, rd = io.open(pipe, "w"), io.open(pipe, "r")
   elseif pipe ~= false and stdio ~= false then
      rd, wr = fs.pipe()
   end
   return rd, wr
end

local function _create_stdin_pipe(pipe, stdio)
   local rd, wr
   if type(pipe) == "string" then
      rd = io.open(pipe, "r")
   elseif pipe ~= false and stdio ~= false then
      rd, wr = fs.pipe()
   end
   return rd, wr
end

local function _execute(file, args, options)
   if type(options) ~= "table" then
      options = {}
   end
   local proc_rd, wr = _create_stdin_pipe(options.stdin, options.stdio)
   local rd, proc_wr = _create_pipe(options.stdout, options.stdio)
   local rderr, proc_werr = _create_pipe(options.stderr, options.stdio)

   local _proc, err = eproc.spawn {stdin = proc_rd, stdout = proc_wr, stderr = proc_werr, command = file, args = args, env = options.env}
   _close_fd(proc_rd)
   _close_fd(proc_wr)
   _close_fd(proc_werr)
   if not _proc then
      _close_fd(wr)
      _close_fd(rd)
      _close_fd(rderr)
      return _proc, err
   end

   if type(options.wait) == "boolean" and options.wait then
      return _proc:wait(), _read_fd(rd), _read_fd(rderr)
   end

   if type(options.wait) == "number" and options.wait > 0 then
      local _exitCode = _proc:wait(options.wait)
      if _exitCode >= 0 then
         return _exitCode, _read_fd(rd), _read_fd(rderr)
      end
   end

   return _proc, rd, wr, rderr
end

proc.execute = _execute

return generate_safe_functions(merge_tables(proc, eproc))
