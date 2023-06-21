local escape_string = require"tools.escape".escape_string
local separator = require"eli.path".default_sep()

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

	if fs.file_type(location) == "file" then
		if (not filter or location:match(filter)) and not should_ignore(location) then
			table.insert(result, location)
			return result
		end
	end

	for _, file in ipairs(fs.read_dir(location, { returnFullPaths = false, recurse = recurse })) do
		if not should_ignore(file) then
			if fs.file_type(path.combine(location, file)) == "file" and (not filter or file:match(filter)) then
				local _modulePath = file:gsub("/", resultSeparator)
				table.insert(result, _modulePath)
			end
		end
	end
	return result
end

---@class GenerateEmbedableModuleOptions
---@field minify boolean?
---@field amalgate boolean?
---@field escapeForLuaGsub boolean?
---@field escape boolean?

---processes lua file and returns it as embedable string
---@param config table
---@param options GenerateEmbedableModuleOptions?
---@return string
local function generate_embedable_module(config, options)
	if type(options) ~= "table" then options = {} end
	if options.minify == nil then
		options.minify = true
	end
	if options.amalgate == nil then
		options.amalgate = true
	end
	if options.escape == nil then
		options.escape = true
	end
	if options.escapeForLuaGsub == nil then
		options.escapeForLuaGsub = true
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
		local oldworkDir = os.cwd()
		if options.amalgate then
			local filesToEmbed = ""
			for _, file in ipairs(files) do
				filesToEmbed = filesToEmbed .. " " .. file:gsub(".lua$", "")
			end
			if fs.file_type(module.path) == "file" then
				os.chdir(path.dir(module.path))
			else
				os.chdir(module.path)
			end
			local _pathToAmalg = path.combine(oldworkDir, "tools/amalg.lua")
			local f <close> = io.popen("eli" .. " " .. _pathToAmalg .. " " .. filesToEmbed, "r")
			s = assert(f:read"*a")
			os.chdir(oldworkDir)
		else
			for _, file in ipairs(files) do
				s = s .. fs.read_file(file) .. "\n"
			end
		end
		if options.minify then
			local tmpFile = os.tmpname()
			local tmpOutput = os.tmpname()
			fs.write_file(tmpFile, s)

			os.chdir"deps/luasrcdiet"
			local _pathToLuaDiet = path.combine(oldworkDir, "deps/luasrcdiet/bin/luasrcdiet")
			local f <close> =
				io.popen(
					"eli" ..
					" " .. _pathToLuaDiet .. " " .. tmpFile .. " -o " .. tmpOutput .. "",
					"r"
				)
			assert(f:read"*a":match"lexer%-based optimizations summary", "Minification Failed")
			s = fs.read_file(tmpOutput)
			os.chdir(oldworkDir)
		end
		modulesToEmbed = modulesToEmbed .. s .. "\n"
	end
	if options.escape then
		modulesToEmbed = escape_string(modulesToEmbed)
	end
	if options.escapeForLuaGsub then
		return modulesToEmbed:gsub("%%", "%%%%")
	end
	return modulesToEmbed
end
return generate_embedable_module
