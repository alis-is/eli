local lfs = require "lfs"
local path = require "eli.path"
local fs = require "eli.fs"
local readfile, writefile = fs.readfile, fs.writefile

local escape = require "tools.escape"
local io = require "io"
local os = require "os"

local separator = require "eli.path".default_sep()

local function getFiles(location, recurse, filter, ignore, resultSeparator)
    if not resultSeparator then
        resultSeparator = separator
    end
    local result = {}
    local function should_ignore(file)
        if not file then
            return false
        end

        if type(ignore) == "table" then
            for _, v in ipairs(ignore) do
                if file:match(v) then
                    return true
                end
            end
            return false
        elseif type(ignore) == "string" then
            return file:match(ignore)
        else
            return false
        end
    end

    if lfs.attributes(location, "mode") == "file" then
        if (not filter or location:match(filter)) and not should_ignore(location) then
            table.insert(result, location)
            return result
        end
    end

    for file in lfs.dir(location) do
        if file ~= "." and file ~= ".." and not should_ignore(file) then
            local fullPath = location .. separator .. file
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
    if minify == nil then
        minify = true
    end
    if amalgate == nil then
        amalgate = true
    end
    local modulesToEmbed = ""

    for _, module in ipairs(config) do
        local files
        if module.auto then
            files = getFiles(module.path, true, ".*%.lua$", module.ignore, ".")
        else
            files = module.files
        end
        local s = ""
        local oldworkDir = lfs.currentdir()
        if amalgate then
            local filesToEmbed = ""
            for _, file in ipairs(files) do
                filesToEmbed = filesToEmbed .. " " .. file:gsub(".lua$", "")
            end
            if lfs.attributes(module.path, "mode") == "file" then
                lfs.chdir(path.dir(module.path))
            else
                lfs.chdir(module.path)
            end
            local _pathToAmalg = path.combine(oldworkDir, "tools/amalg.lua")
            local f = io.popen("/root/luabuild/eli" .. " " .. _pathToAmalg .. " " .. filesToEmbed, "r")
            s = assert(f:read("*a"))
            f:close()
            lfs.chdir(oldworkDir)
        else
            for _, file in ipairs(files) do
                s = s .. readfile(file) .. "\n"
            end
        end
        if minify then
            local tmpFile = os.tmpname()
            local tmpOutput = os.tmpname()
            writefile(tmpFile, s)

            lfs.chdir("tools/luasrcdiet")
            local _pathToLuaDiet = path.combine(oldworkDir, "tools/luasrcdiet/bin/luasrcdiet")
            local f =
                io.popen(
                "/root/luabuild/eli" ..
                    " " .. _pathToLuaDiet .. " " .. tmpFile .. " -o " .. tmpOutput .. " --basic",
                "r"
            )
            assert(f:read("*a"):match("lexer%-based optimizations summary"), "Minification Failed")
            s = readfile(tmpOutput)
            f:close()
            lfs.chdir(oldworkDir)
        end
        modulesToEmbed = modulesToEmbed .. s .. "\n"
    end
    modulesToEmbed = escape.escape_string(modulesToEmbed)
    return modulesToEmbed
end
return generateModuleString
