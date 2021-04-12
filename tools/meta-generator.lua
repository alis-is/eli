elify()
---comment
---@param libPath string
local function _generate_meta(libPath)
    local _libName = libPath:match("eli%.(.*)")
    local _lib = require(libPath)

    if type(_lib) ~= "table" then return "" end
    local _fields = {}
    for k, _ in pairs(_lib) do table.insert(_fields, k) end
    table.sort(_fields)

    local _generatedDoc = ""
    --- @type string
    local _ok, _code = fs.safe_read_file(
                           "lib/eli/" .. _libName:gsub('%.', '/') .. ".lua")
    -- lua file not found 
    -- // TODO: merge from C modules ?
    if not _ok then return "" end

    local _fnCache = {}
    for _, _field in ipairs(_fields) do
        local _fieldType = type(_lib[_field])
        if _fieldType == "function" and _field:find("safe_") == 1 then
            goto continue
        end

        local _toMatch = "%-%-%-[ ]?#DES '?" .. _libName .. "." .. _field ..
                             "'?.-\n%s*"

        local _docsStartPos, _docsEndPos = _code:find(_toMatch)
        if _libName == "lz" then print(_field, _toMatch) end
        if _docsStartPos == nil then goto continue end
        while true do
            local _start, _end = _code:find("%-%-%-.-\n", _docsEndPos)
            if _start == nil or _start ~= _docsEndPos + 1 then break end
            _docsEndPos = _end
        end
        local _subDocs = _code:sub(_docsStartPos, _docsEndPos)

        if _fieldType == "function" then
            local _params = _code:match("function.-%((.-)%)", _docsEndPos)
            _fnCache[_field] = {docs = _subDocs, params = _params}
            _subDocs = _subDocs .. "function " .. _libName .. "." .. _field ..
                           "(" .. _params .. ") end\n"
        else

        end

        _code = _code:sub(0, _docsStartPos - 1) .. _code:sub(_docsEndPos + 1)
        _generatedDoc = _generatedDoc .. _subDocs .. "\n"
        ::continue::
    end
    -- collect safe functions
    for _, _field in ipairs(_fields) do
        local _fieldType = type(_lib[_field])
        if _fieldType ~= "function" or _field:find("safe_") ~= 1 then
            goto continue
        end
        local docs = _fnCache[_field:match("safe_(.*)")]

        if docs == nil then goto continue end
        local _subDocs = docs.docs;
        _subDocs = _subDocs:gsub("#DES '?" .. _libName .. "%." ..
                                     _field:match("safe_(.*)") .. "'?",
                                 "#DES '" .. _libName .. "." .. _field .. "'")
        if _subDocs:find("---[ ]?@return") then
            _subDocs = _subDocs:gsub("---[ ]?@return", "---@return boolean,")
        else
            _subDocs = _subDocs .. "---@return boolean\n"
        end
        _subDocs =
            _subDocs .. "function " .. _libName .. "." .. _field .. "(" ..
                docs.params .. ") end\n"

        _generatedDoc = _generatedDoc .. _subDocs .. "\n"
        ::continue::
    end
    -- collect classes 
    local _additionalDefinitions = ""
    local _addionalEnd = 0
    while true do
        local _classStart, _classEnd = _code:find("%-%-%-[ ]?@class.-\n",
                                                  _addionalEnd)
        if _classStart == nil then break end

        while true do
            local _start, _end = _code:find("%-%-%-.-\n", _classEnd)
            if _start == nil or _start ~= _classEnd + 1 then break end
            _classEnd = _end
        end

        _additionalDefinitions = _additionalDefinitions ..
                                     _code:sub(_classStart, _classEnd) .. "\n"

        _addionalEnd = _classEnd
    end
    return _additionalDefinitions .. "\n" .. _generatedDoc
end

fs.mkdir(".meta")
for k, v in pairs(package.preload) do
    if not k:match("eli%..*") then goto continue end
    local _docs = _generate_meta(k)
    fs.write_file(".meta/" .. k:match("eli%.(.*)") .. ".lua", _docs)
    ::continue::
end
