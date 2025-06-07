local _exclude = { "eli.internals.util", "eli.pipe.extra", "eli.proc.extra", "eli.stream.extra", "eli.fs.extra",
	"eli.os.extra", "eli.env.extra" }

---comment
---@param code string
---@param libName string
---@return string, number, string, boolean
local function _get_next_doc_block(code, libName, position)
	local isInject = code:match"^--- META_INJECT"
	local _blockContent = ""
	local _blockStart, _blockEnd = code:find("%s-%-%-%-.-\n[^%S\n]*", position)
	if _blockStart == nil then return nil end
	_blockContent = _blockContent ..
	   code:sub(_blockStart, _blockEnd):match"^%s*(.-)%s*$" ..
	   "\n"

	-- extension libs are overriding existing libs so we need to remove extensions part
	if libName:match"extensions%.([%w_]*)" then
		libName = libName:match"extensions%.([%w_]*)"
	end
	local _field = code:sub(_blockStart, _blockEnd):match(
		"%-%-%-[ ]?#DES '?" .. libName .. ".([%w_:]+)'?.-\n%s*")
	-- lib level class export
	if _field == nil and
	code:sub(_blockStart, _blockEnd):match(
		"%-%-%-[ ]?#DES '?" .. libName .. "'?.-\n%s*") then
		_field = libName
	end
	while true do
		local _start, _end = code:find("%-%-%-.-\n[^%S\n]*", _blockEnd)
		if _start == nil or _start ~= _blockEnd + 1 then break end
		_blockContent = _blockContent ..
		   code:sub(_start, _end):match"^%s*(.-)%s*$" .. "\n"
		_blockEnd = _end
	end
	return _blockContent, _blockEnd, _field, isInject
end

---@alias DocBlockKind
---| "independent"'
---| '"field"'
---| '"function"'
---| '"class"'
---| '"safe_function"'
---| '"inject"'

---@class DocBlock
---@field kind DocBlockKind
---@field name string
---@field content string
---@field fieldType type
---@field blockEnd number
---@field isPublic boolean
---@field libFieldSeparator '"."'|'":"'
---@field value any

---comment
---@param code string
---@param libName string
---@param docBlock DocBlock
---@param isGlobal boolean
---@return string
local function _collect_function(code, libName, docBlock, isGlobal)
	local _start = code:find("function.-%((.-)%)", docBlock.blockEnd)
	-- extension libs are overriding existing libs so we need to remove extensions part
	if libName:match"extensions%.([%w_]*)" then
		libName = libName:match"extensions%.([%w_]*)"
	end
	local _functionDef = "function " .. libName .. docBlock.libFieldSeparator ..
	   docBlock.name
	if _start ~= docBlock.blockEnd + 1 then
		local _start =
		   code:find("local%s-function.-%((.-)%)", docBlock.blockEnd)
		if _start ~= docBlock.blockEnd + 1 then
			local _params = {}
			for _paramName in string.gmatch(docBlock.content,
				"%-%-%-[ ]?@param%s+([%w_]*)%s+.-\n") do
				table.insert(_params, _paramName)
			end
			return docBlock.content .. _functionDef .. "(" ..
			   string.join_strings(", ", table.unpack(_params)) ..
			   ") end\n"
		end
	end
	local _params = code:match("function.-%((.-)%)", docBlock.blockEnd)
	return docBlock.content .. _functionDef .. "(" .. _params .. ") end\n"
end

-- // TODO: remove
-- ---collects safe function
-- ---@param code string
-- ---@param libName string
-- ---@param docBlock DocBlock
-- ---@param isGlobal boolean
-- ---@return string
-- local function _collect_safe_function(code, libName, docBlock, isGlobal)
-- 	local _content = _collect_function(code, libName, docBlock, isGlobal)
-- 	_content = _content:gsub("#DES '?" .. libName .. "%." ..
-- 		docBlock.name:match"safe_(.*)" .. "'?",
-- 		"#DES '" .. libName .. "." .. docBlock.name .. "'")
-- 	-- fix content for safe function
-- 	if _content:find"---[ ]?@return" then
-- 		_content = _content:gsub("---[ ]?@return", "---@return boolean, string|")
-- 	else
-- 		local _, _end = _get_next_doc_block(_content, libName)
-- 		_content = _content:sub(1, _end) .. "---@return boolean, string?\n" ..
-- 			_content:sub(_end + 1)
-- 	end
-- 	return _content
-- end

---comment
---@param _ string
---@param libName string
---@param docBlock DocBlock
---@param isGlobal boolean
---@return string
local function _collect_class(_, libName, docBlock, isGlobal)
	if docBlock.isPublic then
		if docBlock.name == libName and
		docBlock.content:match("%-%-%-[ ]?#DES '?" .. libName .. "'?%s-\n") then
			return docBlock.content .. (isGlobal and "" or "local ") .. libName ..
			   " = {}\n"
		end
		return docBlock.content .. (isGlobal and "" or "local ") .. libName ..
		   "." .. docBlock.name .. " = {}\n"
	else
		return docBlock.content .. "\n"
	end
end

---comment
---@param _ string
---@param libName string
---@param docBlock DocBlock
---@return string
local function _collect_field(_, libName, docBlock, isGlobal)
	local _defaultValues = {
		["nil"] = "nil",
		["string"] = '""',
		["boolean"] = "false",
		["table"] = "{}",
		["number"] = "0",
		["thread"] = "nil",
		["userdata"] = "nil",
	}
	local _type = docBlock.fieldType
	if _type == "nil" then
		_type = docBlock.content:match"%-%-%-[ ]?@type%s+(%w+)"
	end
	if docBlock.fieldType == "boolean" then
		_defaultValues["boolean"] = tostring(docBlock.value == true)
	end

	if docBlock.isPublic then
		return docBlock.content .. (isGlobal and "" or "local ") .. libName ..
		   "." .. docBlock.name .. " = " .. _defaultValues[_type] ..
		   "\n"
	else
		return docBlock.content .. "\n"
	end
end

local function collect_inject(_, libName, docBlock, isGlobal)
	local content = docBlock.content
	-- strip "--- META_INJECT"
	local _, _end = content:find("META_INJECT", 0, true)
	-- strip leading --- from each line
	content = content:sub(_end + 1):gsub("\n%s*%-%-%-", "\n")

	--- trim empty lines
	content = content:gsub("\n\n+", "\n")

	return content
end

---@type table<string, fun(code: string, libName: string, docBlock: DocBlock, isGlobal: boolean): string>
local _collectors = {
	["independent"] = function (_, _, docBlock, _) return docBlock.content end,
	["function"] = _collect_function,
	-- ["safe_function"] = _collect_safe_function,
	["class"] = _collect_class,
	["field"] = _collect_field,
	["inject"] = collect_inject,
}

---comment
---@param libPath string
---@param libReference any
---@param sourceFiles nil|string|string[]
---@param isGlobal boolean
local function _generate_meta(libPath, libReference, sourceFiles, isGlobal)
	if isGlobal == nil then isGlobal = true end
	local _libName = libPath:match"eli%.(.*)" or libPath
	---@type table
	local _lib = libReference or require(libPath)
	if type(_lib) ~= "table" then return "" end
	local _fields = {}
	for k, _ in pairs(_lib) do table.insert(_fields, k) end
	table.sort(_fields)

	-- inject meta header, meta name should be used for libs which are meant to be required
	local _generatedDoc = "---@meta\n"

	--- @type string | table
	local _sourcePaths = { "lib/eli/" .. _libName:gsub("%.", "/") .. ".lua" }
	if type(sourceFiles) == "string" then
		_sourcePaths = { sourceFiles }
	elseif type(sourceFiles) == "table" and util.is_array(sourceFiles) then
		_sourcePaths = sourceFiles
	end
	local _code = ""
	for _, v in ipairs(_sourcePaths) do
		local codePart, _ = fs.read_file(v)
		if codePart then
			_code = _code .. codePart .. "\n"
		end
	end
	if _code == "" then return #_generatedDoc > 8 and _generatedDoc or "" end

	---@type DocBlock[]
	local _docsBlocks = {}
	local _blockEnds = 0

	while true do
		local _docBlock, _field, isInject
		_docBlock, _blockEnds, _field, isInject = _get_next_doc_block(_code, _libName, _blockEnds)
		if _docBlock == nil then break end
		if isInject then
			table.insert(_docsBlocks, {
				name = _field,
				kind = "inject",
				content = _docBlock,
				blockEnd = _blockEnds,
			})
		end

		if _field == nil then                                 -- dangling
			if _docBlock:match"@class" or _docBlock:match"@alias" then -- only classes and aliases are allowed into danglings
				table.insert(_docsBlocks, {
					name = _field,
					kind = "independent",
					content = _docBlock,
					blockEnd = _blockEnds,
				})
			end
			goto continue
		end

		if _docBlock:match"@class" then
			table.insert(_docsBlocks, {
				name = _field,
				kind = "class",
				content = _docBlock,
				blockEnd = _blockEnds,
				isPublic = _lib[_field] ~= nil or _libName == _field,
			})
		else
			local _fieldType = type(_lib[_field])
			table.insert(_docsBlocks, {
				name = _field,
				kind = _fieldType == "function" and "function" or "field",
				fieldType = _fieldType,
				content = _docBlock,
				blockEnd = _blockEnds,
				isPublic = _lib[_field] ~= nil,
				value = _lib[_field],
				libFieldSeparator = _docBlock:match(
					   "%-%-%-[ ]?#DES '?" .. _libName .. "(.)[%w_:]+'?.-\n%s*") or
				   ".",
			})
		end
		::continue::
	end
	-- post process blocks:
	-- check and correct class functions
	for _, v in ipairs(_docsBlocks) do
		if v.kind == "field" then
			local _className, _fieldName =
			   v.name:match"(%w+)%s*[:%.]%s*([%w_]+)"
			if _lib[_className] ~= nil and type(_lib[_className][_fieldName]) ==
			"function" then
				v.kind = "function"
			end
		end
	end

	for _, v in ipairs(_docsBlocks) do
		local _collector = _collectors[v.kind]
		if _collector ~= nil then
			_generatedDoc = _generatedDoc .. _collector(_code, _libName, v, isGlobal) ..
			   "\n"
			-- //TODO: remove
			-- if v.kind == "function" and not v.name:match"^safe_" then
			-- 	local _safeFnName = "safe_" .. v.name
			-- 	if type(_lib[_safeFnName]) == "function" then
			-- 		local _saveV = util.clone(v, true)
			-- 		_saveV.name = _safeFnName
			-- 		_generatedDoc = _generatedDoc ..
			-- 		   _collectors["safe_function"](_code,
			-- 			   _libName,
			-- 			   _saveV,
			-- 			   isGlobal) ..
			-- 		   "\n"
			-- 	end
			-- end
		end
	end
	if not isGlobal then
		_generatedDoc = _generatedDoc .. "return " .. _libName:match"[^%.]+"
		if not _generatedDoc:match("local%s+" .. _libName:match"[^%.]+") then
			local _toInject = ""
			local _part = nil
			for _match in _libName:gmatch"([^%.]+)" do
				_toInject = _toInject .. (_part or "local ") .. _match ..
				   " = {}\n"
				_part = (_part or "") .. _match .. "."
			end
			_generatedDoc = _toInject .. "\n" .. _generatedDoc
		end
	end
	return _generatedDoc
end

local _hjson = require"hjson"

local _configContent = fs.read_file"config.hjson"
local _config = _hjson.parse(_configContent)

for _, _docs in ipairs(_config.inject_docs) do
	local _source = _docs.source
	for _, _file in ipairs(_docs.files) do
		local _generatedDocs = _generate_meta(_file.lib, require(_file.lib),
			path.combine(_source, _file.name),
			_file.isGlobal)
		local _libDir = ".meta"
		if type(_file.destination) == "string" then
			_libDir = path.combine(_libDir, path.dir(_file.destination or ""))
		end
		fs.mkdirp(_libDir)
		fs.write_file(path.combine(_libDir,
			type(_file.destination) == "string" and
			path.file(_file.destination) or _file.lib ..
			".lua"), _generatedDocs)
	end
end

for k, v in pairs(package.preload) do
	if not k:match"eli%..*" then goto continue end
	for _, _excluded in ipairs(_exclude) do
		if k:match(_excluded) then goto continue end
	end
	local _docs = _generate_meta(k)
	fs.write_file(".meta/" .. k:match"eli%.(.*)" .. ".lua", _docs)
	::continue::
end
