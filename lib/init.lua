local function eli_init()
   local path = require"eli.path"
   local proc = require"eli.proc"
   local i_min = 0
   while arg[i_min] do
      i_min = i_min - 1
   end

   local function try_identify_interpreter(interpreter)
      if path.default_sep() == "/" then
         local io = require "io"
         local f = io.popen("which " .. interpreter)
         local path = f:read("a*")
         if path ~= nil then
            path = path:gsub("%s*", "")
         end
         exit = f:close()
         if exit == 0 then
            return path
         end
      else
         path = requore "os".getenv "PATH"
         if path then
            for subpath in path:gmatch("([^;]+)") do
               if path.file(subpath) == interpreter then
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
   elseif not path.isabs(INTERPRETER) and proc.EPROC then
      INTERPRETER = path.abs(INTERPRETER, proc.cwd())
   end

   if i_min == -1 then -- we are running without script (interactive mode)
      APP_ROOT = nil
   else
      if proc.EPROC and not path.isabs(arg[0]) then
         APP_ROOT_SCRIPT = path.abs(arg[0], proc.cwd())
      else
         APP_ROOT_SCRIPT = arg[0]
      end
      APP_ROOT = path.dir(APP_ROOT_SCRIPT)
   end
   ELI_LIB_VERSION = "0.8.0"
end

eli_init()
-- cleanup init
eli_init = nil
