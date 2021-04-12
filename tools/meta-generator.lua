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

    local _cache = {}

    local _generatedDoc = ""
    --- @type string
    local _ok, _code = fs.safe_read_file(
                           "lib/eli/" .. _libName:gsub('%.', '/') .. ".lua")
    -- lua file not found 
    -- // TODO: merge from C modules ?
    if not _ok then return "" end

    for _, _field in ipairs(_fields) do

        local _toMatch = "---[ ]?#DES '" .. _libName .. "." .. _field ..
                             "'.-\n%s*"
        local _fieldType = type(_lib[_field])
        local _isSafeFn = false
        if _fieldType == "function" and _field:find("safe_") == 1 then
            _isSafeFn = true

            _toMatch = "---[ ]?#DES '" .. _libName .. "." ..
                           _field:match("safe_(.*)") .. "'.-\n%s*"
        end

        local _subDocs = ""
        local _docsStartPos, _docsEndPos = _code:find(_toMatch)
        if _docsStartPos == nil then goto continue end
        while true do
            local _start, _end = _code:find("---.-\n", _docsEndPos)
            if _start == nil or _start ~= _docsEndPos + 1 then break end
            _docsEndPos = _end
        end
        _subDocs = _subDocs .. _code:sub(_docsStartPos, _docsEndPos)

        if _fieldType == "function" then
            if _isSafeFn then
                _subDocs = _subDocs:gsub(
                               "#DES '" .. _libName .. "%." ..
                                   _field:match("safe_(.*)") .. "'",
                               _libName .. "." .. _field)
                if _subDocs:find("---[ ]?@return") then
                    _subDocs = _subDocs:gsub("---[ ]?@return",
                                             "---@return boolean,")
                else
                    _subDocs = _subDocs .. "---@return boolean\n"
                end
            end
            local _params = _code:match("function.-%((.-)%)", _docsEndPos)
            _subDocs = _subDocs .. "function " .. _libName .. "." .. _field ..
                           "(" .. _params .. ") end\n"
        else

        end

        _generatedDoc = _generatedDoc .. _subDocs .. "\n"
        ::continue::
    end
    return _generatedDoc
end

fs.mkdir(".meta")
for k, v in pairs(package.preload) do
    if not k:match("eli%..*") then goto continue end
    local _docs = _generate_meta(k)
    fs.write_file(".meta/" .. k:match("eli%.(.*)") .. ".lua", _docs)
    ::continue::
end
