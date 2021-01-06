--[[ // TODO consider implications of mergin proc with os and fs with io ]]
local _elified = false
local _overridenValues = {}

local function _elify()
    if (_elified) then return end
    local _special = { os = true }
    local _exclude = { "eli%..*%.extra", "eli%.extensions%..*", "eli%.elify" }
    for k, v in pairs(package.preload) do
        if not k:match("eli%..*") then goto continue end
        for _, _ex in ipairs(_exclude) do 
            if k:match(_ex) then goto continue end
        end
        local _efk = k:match("eli%.(.*)")
        if not _efk or _special[_efk] then goto continue end
        _G[_efk] = require(k)
        ::continue::
    end
    _overridenValues.os = os
    os = util.merge_tables(os, require("eli.os"))

    _overridenValues.type = type
    type = function(v)
        local _t = _overridenValues.type(v)
        if _t == "table" then
            local _ttype = type(_t.__type)
            if type(_ttype) == "string" then
                return _t.__type
            elseif type(_ttype) == "function" then
                return _t.__type()
            end
        end
        return _t
    end

    _elified = true
end

return {
    elify = _elify,
    get_overriden_values = function()
        return _overridenValues
    end,
    is_elified = function()
        return _elified == true
    end
}