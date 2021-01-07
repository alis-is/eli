local function eli_init()
   local path = require"eli.path"
   local _eos = require"eli.os"
   local i_min = 0
   while arg[i_min] do
      i_min = i_min - 1
   end

   local function try_identify_interpreter(interpreter)
      if path.default_sep() == "/" then
         local io = require "io"
         local f = io.popen("which " .. interpreter)
         local _path = f:read("a*")
         if _path ~= nil then
            _path = _path:gsub("%s*", "")
         end
         local _exit = f:close()
         if _exit == 0 then
            return _path
         end
      else
         local _path = require "os".getenv "PATH"
         if _path then
            for subpath in _path:gmatch("([^;]+)") do
               if _path.file(subpath) == interpreter then
                  return subpath
               end
            end
         end
      end
   end

   INTERPRETER = arg[i_min + 1]
   if not INTERPRETER:match(path.default_sep()) then
      local identified, _interpreter = pcall(try_identify_interpreter, INTERPRETER)
      if identified then
         INTERPRETER = _interpreter
      end
   elseif not path.isabs(INTERPRETER) and _eos.EOS then
      INTERPRETER = path.abs(INTERPRETER, _eos.cwd())
   end

   if i_min == -1 then -- we are running without script (interactive mode)
      APP_ROOT = nil
   else
      if _eos.EOS and not path.isabs(arg[0]) then
         APP_ROOT_SCRIPT = path.abs(arg[0], _eos.cwd())
      else
         APP_ROOT_SCRIPT = arg[0]
      end
      APP_ROOT = path.dir(APP_ROOT_SCRIPT)
   end
   ELI_LIB_VERSION = "0.11.1"
end

eli_init()
-- cleanup init
eli_init = nil
elify = require("eli.elify").elify