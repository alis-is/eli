  
local _test = TEST or require 'u-test'
local _ok, _eliVer  = pcall(require, "eli.ver")

if not _ok then 
    _test["eli.ver available"] = function ()
        _test.assert(false, "eli.ver not available")
    end
    if not TEST then 
        _test.summary()
        os.exit()
    else 
        return 
    end
end

_test["semver_compare"] = function() -- from: http://semver.org/spec/v2.0.0.html#spec-item-11
    local _testCases = {
        {"1", "0", 1},
        {"1", "1", 0},
        {"1", "3", -1},
        {"1.5", "0.8", 1},
        {"1.5", "1.3", 1},
        {"1.2", "2.2", -1},
        {"3.0", "1.5", 1},
        {"1.5", "1.5", 0},
        {"1.0.9", "1.0.0", 1},
        {"1.0.9", "1.0.9", 0},
        {"1.1.5", "1.1.9", -1},
        {"1.2.2", "1.1.9", 1},
        {"1.2.2", "1.2.9", -1},
    }

    for _, v in ipairs(_testCases) do
        _test.assert(_eliVer.compare_version(v[1], v[2]) == v[3])
    end
end

_test["semver_compare_full"] = function()
    local _testCases = {
        {"1.5.1", "1.5.1-beta", 1},
        {"1.5.1-beta", "1.5.1", -1},
        {"1.5.1-beta", "1.5.1-beta", 0},
        {"1.5.1-beta", "1.5.1-alpha", 1},
        {"1.5.1-beta.1", "1.5.1-alpha.1", 1},
        {"1.5.1-beta.1", "1.5.1-beta.0", 1},
        {"1.5.1-beta.1.5", "1.5.1-beta.1.5", 0},
        {"1.5.1-beta.1.5", "1.5.1-beta.1.4", 1},
        {"1.5.1-beta.1.0", "1.5.1-beta.1.4", -1},
        {"1.5.1-beta.1.0", "1.5.1-alpha.1.0", 1},
        {"1.5.1-beta.1.100", "1.5.1-alpha.1.99", 1},
        {"1.5.1-beta.1.123456789", "1.5.1-alpha.1.12345678", 1},
        {"1.5.1-beta.alpha.1", "1.5.1-beta.alpha.1.12345678", -1},
        {"1.5.1-beta.alpha.1", "1.5.1-beta.alpha.1+123", 0},
        {"1.5.1-beta.1+20130313144700", "1.5.1-beta.1+20120313144700", 0},
        {"1.5.1-beta.1+20130313144700", "1.5.1-beta.1+20130313144700", 0},
        {"1.5.1-beta.1+20130313144700", "1.5.1-beta.1+exp.sha.5114f85", 0},
        {"1.5.1-beta.1+exp.sha.5114f85", "1.5.1-beta.1+exp.sha.5114f84", 0},
        {"1.5.1-beta.1+exp.sha.5114f85", "1.5.1-beta.1+exp.sha1.5114f84", 0},
        {"1.5.1-beta.1+exp.sha", "1.5.1-beta.1+exp.sha256", 0},
        {"1.5.1-alpha.beta", "1.5.1-1.beta", 1}
    }

    for _, v in ipairs(_testCases) do
        _test.assert(_eliVer.compare_version(v[1], v[2]) == v[3])
    end
end

_test["semver_compare_spec"] = function() -- from: http://semver.org/spec/v2.0.0.html#spec-item-11
    local _testCases = {
        {"1.0.0-alpha", "1.0.0-alpha.1", -1},
        {"1.0.0-alpha.1", "1.0.0-alpha.beta", -1},
        {"1.0.0-alpha.beta", "1.0.0-beta", -1},
        {"1.0.0-beta", "1.0.0-beta.2", -1},
        {"1.0.0-beta.2", "1.0.0-beta.11", -1},
        {"1.0.0-beta.11", "1.0.0-rc.1", -1},
        {"1.0.0-rc.1", "1.0.0", -1}
    }

    for _, v in ipairs(_testCases) do
        _test.assert(_eliVer.compare_version(v[1], v[2]) == v[3])
    end
end

if not TEST then 
    _test.summary()
end