local _test = TEST or require "u-test"
local _ok, _eliProc = pcall(require, "eli.proc")
local _eliFs = require("eli.fs")

if not _ok then
    _test["eli.proc available"] = function()
        _test.assert(false, "eli.proc not available")
    end
    if not TEST then
        _test.summary()
        os.exit()
    else
        return
    end
end

_test["eli.proc available"] = function()
    _test.assert(true)
end

_test["os_execute"] = function()
    local _ok, _, _code = _eliProc.os_execute("sh -c 'exit 173'")
    _test.assert(not _ok and _code == 173)
end

_test["io_execute"] = function()
    local _ok, _, _output = _eliProc.io_execute('sh -c "printf \'test\'"')
    _test.assert(_ok and _output == "test")
end

if not _eliProc.EPROC then
    if not TEST then
        _test.summary()
        print "EPROC not detected, only basic tests executed..."
        os.exit()
    else
        print "EPROC not detected, only basic tests executed..."
        return
    end
end

_test["execute"] = function()
    local _proc, _rd, _wr = _eliProc.execute("sh")
    _wr:write("printf '173'\n")
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _rd:read("a")
    _test.assert(_exit == 0 and _result == "173")
end

_test["execute (args)"] = function()
    local _proc, _rd = _eliProc.execute("sh", {"-c", "printf '173'"})
    local _exit = _proc:wait()
    local _result = _rd:read("a")
    _test.assert(_exit == 0 and _result == "173")
end

_test["execute (wait)"] = function()
    local _exit, _result = _eliProc.execute("sh", {"-c", "printf '173'"}, {wait = true})
    _test.assert(_exit == 0 and _result == "173")
end

_test["execute (wait limited)"] = function()
    local _proc, _rd = _eliProc.execute("sh", {"-c", "sleep 3 && printf '173'"}, {wait = 1})
    _test.assert(type(_proc) == "userdata" and type(_rd) == "userdata")
    local _exit = _proc:wait()
    local _result = _rd:read("a")
    _test.assert(_exit == 0 and _result == "173")
end

_test["execute (custom env)"] = function()
    local _exit, _result = _eliProc.execute("sh", {"-c", "printf \"$TEST\""}, {wait = true, env = {TEST = "test env variable"}})
    _test.assert(_exit == 0 and _result == "test env variable")
end

_test["execute (custom stdout)"] = function()
    local _exit = _eliProc.execute("sh", {"-c", "printf '173'"}, {wait = true, stdout = "tmp/test.stdout"})
    local _result = _eliFs.read_file("tmp/test.stdout")
    _test.assert(_exit == 0 and _result == "173")
end

_test["execute (custom stderr)"] = function()
    local _proc, _, _wr, _ = _eliProc.execute("sh", {}, { stderr = "tmp/test.stderr" })
    _wr:write("printf 'error 173' >&2;\n")
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _eliFs.read_file("tmp/test.stderr")
    _test.assert(_exit == 0 and _result == "error 173")
end

_test["execute (stdin)"] = function()
    local _proc, _rd, _wr, _rderr = _eliProc.execute("sh", {}, {wait = false})
    _wr:write("printf '173'\n")
    _wr:write("printf 'error 173' >&2;\n")
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _rd:read("a")
    local _error = _rderr:read("a")
    _test.assert(_exit == 0 and _result == "173" and _error == 'error 173')
end

_test["execute (stdio=false)"] = function()
    local _exit, _stdout, _stderr = _eliProc.execute("sh", {"-c", "printf '173'"}, {wait = true, stdio = false})
    _test.assert(_exit == 0 and _stdout == nil and _stderr == nil)
end

_test["execute (stdio=false stdin)"] = function()
    local _proc, rd, wr, rderr = _eliProc.execute("sh", {"-c", "printf '173'"}, {stdio = false})
    local _exit = _proc:wait()
    _test.assert(_exit == 0 and rd == nil and wr == nil and rderr == nil)
end

_test["execute (file as stdin)"] = function()
    local _exit, _result = _eliProc.execute("sh", {}, {wait = true, stdin = "test.script"})
    _test.assert(_exit == 0 and _result == "13354\n")
end

if not TEST then
    _test.summary()
end
