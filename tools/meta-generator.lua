elify()
---comment
---@param libPath string
local function _generate_meta(libPath)
    local _libName = libPath:match("eli%.(.*)")
    local _lib = require(libPath)
    local _fields = {}
    for k, _ in pairs(_lib) do table.insert(_fields, k) end
    table.sort(_fields)
    util.print_table(_fields)

    local _cache = {}

    --- @type string
    local _code = fs.read_file("lib/eli/" .. _libName .. ".lua")
    local _generatedDoc = ""

    for _, _field in ipairs(_fields) do
        local _toMatch = "---[ ]?#DES '" .. _libName .. "." .. _field ..
                             "'.-\n%s*"
        local _docsStartPos, _docsEndPos = _code:find(_toMatch)
        if _docsStartPos ~= nil and _docsEndPos ~= nil then
            while true do
                local _start, _end = _code:find("---.-\n", _docsEndPos)
                if _start == nil or _start ~= _docsEndPos + 1 then
                    break
                end
                _docsEndPos = _end
            end
            _generatedDoc = _generatedDoc ..
                                _code:sub(_docsStartPos, _docsEndPos)
        end
        local _fieldType = type(_lib[_field])
        if _fieldType == "function" then
            local _params = _code:match("function.-%((.-)%)", _docsEndPos)
            _generatedDoc = _generatedDoc .. "function " .. _libName .. "." ..
                                _field .. "(" .. _params .. ") end\n"
        else

        end
        _generatedDoc = _generatedDoc .. "\n"
    end
    print(_generatedDoc)

end

fs.mkdir(".meta")
for k, v in pairs(package.preload) do
    if not k:match("eli%..*") then goto continue end
    if k == "eli.util" then _generate_meta(k) end

    fs.write_file(".meta/" .. k:match("eli%.(.*)") .. ".lua")
    ::continue::
end
