local lfs = require"lfs"
local path = require"eli.path"
local fs = require"eli.fs"
local readfile, writefile = fs.readfile, fs.writefile

local escape = require"tools.escape"
local io = require"io"
local os = require"os"

local separator = path.default_sep()
local interpreter = path.isabs(arg[-1]) and arg[1] or path.abs(arg[-1], lfs.currentdir())

local function getFiles(path, recurse, filter, ignore, resultSeparator)
    if not resultSeparator then 
         resultSeparator = separator 
    end
    local result = {}
    if lfs.attributes(path,"mode") == "file" then
        if (not filter or path:match(filter)) and (not ignore or not path:match(ignore)) then  
            table.insert(result, path) 
            return result
        end
    end
    
    for file in lfs.dir(path) do  
        if file ~= '.' and file ~= '..' and (not ignore or not file:match(ignore)) then 
            local fullPath = path .. separator .. file        
            if lfs.attributes(fullPath, "mode") == "file" and (not filter or file:match(filter)) then 
                table.insert(result, file)
            elseif lfs.attributes(fullPath, "mode") == "directory" and recurse then 
                for _, _file in ipairs(getFiles(fullPath, recurse, filter, ignore, resultSeparator)) do
                   table.insert(result, file .. resultSeparator .. _file) -- :gsub("[\\/]", "."))
                end          
            end
        end
    end
    return result
end

local function generateModuleString(config, minify, amalgate)
   if minify == nil then minify = true end
   if amalgate == nil then amalgate = true end
   local modulesToEmbed = ""

   for _, module in ipairs(config) do 
       local files = {}
       if module.auto then 
           files = getFiles(module.path, true, ".*%.lua$", module.ignore, ".") 
       else
           files = module.files 
       end
       local s = ''
       local oldworkDir = lfs.currentdir()
       if amalgate then 
          local filesToEmbed = ''
          for i, file in ipairs(files) do
             filesToEmbed = filesToEmbed .. ' ' .. file:gsub(".lua$", "")                   
          end
          if lfs.attributes(module.path,"mode") == "file" then
             lfs.chdir(path.dir(module.path))
          else
             lfs.chdir(module.path)
          end
          local f = io.popen("/root/luabuild/eli" .. ' ' .. path.combine(oldworkDir, "tools/amalg.lua") .. ' ' .. filesToEmbed, "r")
          s = assert(f:read('*a'))
          f:close()            
          lfs.chdir(oldworkDir)
       else 
          for i, file in ipairs(files) do
             s = s .. readfile(file) .. '\n'
          end
       end 
       if minify then
          local tmpFile = os.tmpname()
          local tmpOutput = os.tmpname()
          writefile(tmpFile, s)
             
          lfs.chdir("tools/luasrcdiet")
          local f = io.popen("/root/luabuild/eli" .. ' ' .. path.combine(oldworkDir, "tools/luasrcdiet/bin/luasrcdiet")  .. ' ' .. tmpFile .. ' -o ' .. tmpOutput .. ' --basic', "r")
          assert(f:read('*a'):match("lexer%-based optimizations summary"), "Minification Failed")
          s = readfile(tmpOutput)
          f:close()
          lfs.chdir(oldworkDir)
       end
       modulesToEmbed = modulesToEmbed .. s .. '\n'
   end
   modulesToEmbed = escape.escape_string(modulesToEmbed)
   return modulesToEmbed
end 
return generateModuleString
