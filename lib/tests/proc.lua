local _test = TEST or require "u-test"
local _ok, _eliProc = pcall(require, "eli.proc")
local _eliFs = require("eli.fs")
local _eliPath = require"eli.path"

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

local _pathSeparator = package.config:sub(1,1)

_test["eli.proc available"] = function()
    _test.assert(true)
end

_test["exec"] = function ()
    local _result = _eliProc.exec("echo 135")
    _test.assert(_result.exitcode == 0 and _result.stdoutStream == nil and _result.stderrStream == nil)
end

_test["exec (stdout)"] = function ()
    local _result = _eliProc.exec("echo 135", { stdout = "pipe" })
    _test.assert(_result.exitcode == 0 and string.trim(_result.stdoutStream:read("a")) == "135"  and _result.stderrStream == nil)
end

_test["exec (stdout - path)"] = function ()
    local _result = _eliProc.exec("echo 135", { stdout = "tmp/stdout.tmp" })
    _test.assert(_result.exitcode == 0 and string.trim(_result.stdoutStream:read("a")) == "135" and _result.stderrStream == nil)
end

_test["exec (stderr)"] = function ()
    local _cli = "sh -c"
    if _pathSeparator == "\\" then
        _cli = "cmd /c"
    end
    local _result = _eliProc.exec(_cli .. " \"echo error 173 >&2\"", { stderr = "pipe" })
    _test.assert(_result.exitcode == 0 and _result.stdoutStream == nil and string.trim(_result.stderrStream:read("a")) == "error 173")
end

_test["exec (stderr - path)"] = function ()
    local _cli = "sh -c"
    if _pathSeparator == "\\" then
        _cli = "cmd /c"
    end
    local _result = _eliProc.exec(_cli .. " \"echo error 173 >&2\"", { stderr = "tmp/stderr.tmp" })
    _test.assert(_result.exitcode == 0 and _result.stdoutStream == nil and  string.trim(_result.stderrStream:read("a")) == "error 173")
end

_test["exec (stdin)"] = function ()
    local _scriptPath = _eliPath.combine("tmp", "script")
    local _ok = _eliFs.safe_write_file(_scriptPath, "123\n\n")
    _test.assert(_ok, "Failed to write stdin file")
    local _result = _eliProc.exec("more", { stdin = _scriptPath, stdout = "pipe" })
    _test.assert(_result.exitcode == 0 and string.trim(_result.stdoutStream:read("a")) == "123" and _result.stderrStream == nil)
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

_test["spawn"] = function()
    local _proc, _err, code = _eliProc.spawn("sh")
    local _wr = _proc:get_stdin()
    _wr:write("printf '173'\n")
    _wr:write("exit\n")
    local _exitcode = _proc:wait()
    local _result = _proc:get_stdout():read("a")
    _test.assert(_exitcode == 0 and _result == "173")
end

_test["spawn (args)"] = function()
    local _proc = _eliProc.spawn("printf", { "173" })
    local _exit = _proc:wait()
    local _result = _proc:get_stdout():read("a")
    _test.assert(_exit == 0 and _result == "173")
end

_test["spawn (wait)"] = function()
    local _result = _eliProc.spawn("sh", {"-c", "printf '173'"}, {wait = true})
    _test.assert(_result.exitcode == 0 and _result.stdoutStream:read("a") == "173")
end

_test["spawn (custom env)"] = function()
    local _result = _eliProc.spawn("sh", {"-c", "printf \"$TEST\""}, {wait = true, env = {TEST = "test env variable"}})
    _test.assert(0 == _result.exitcode and _result.stdoutStream:read("a") == "test env variable")
end

_test["spawn (custom stdout)"] = function()
    local _stdoutFile = io.open("tmp/test.stdout", "w+")
    local _result = _eliProc.spawn("sh", {"-c", "printf '173'"}, {wait = true, stdio = { stdout = _stdoutFile }})
    local _stdout = _eliFs.read_file("tmp/test.stdout")
    _test.assert(_result.exitcode == 0 and _stdout == "173")
end

_test["spawn (custom stderr)"] = function()
    local _stderrFile = io.open("tmp/test.stderr", "w+")
    local _proc = _eliProc.spawn("sh", {}, {  stdio = { stderr = _stderrFile }})
    local _wr = _proc:get_stdin()
    _wr:write("printf 'error 173' >&2;\n")
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _eliFs.read_file("tmp/test.stderr")
    _test.assert(_exit == 0 and _result == "error 173")
end

_test["spawn (stdin)"] = function()
    local _proc = _eliProc.spawn("sh", {}, {wait = false})
    local _wr, _rd, _rderr = _proc:get_stdin(), _proc:get_stdout(), _proc:get_stderr()
    _wr:write("printf '173'\n")
    _wr:write("printf 'error 173' >&2;\n")
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _rd:read("a")
    local _error = _rderr:read("a")
    _test.assert(_exit == 0 and _result == "173" and _error == 'error 173')
end

_test["spawn (stdio=ignore)"] = function()
    local _result = _eliProc.spawn("sh", {"-c", "printf '173'"}, {wait = true, stdio = "ignore"})
    _test.assert(_result.exitcode == 0 and _result.stdoutStream == nil and _result.stderrStream == nil)
end

_test["spawn (stdio=ignore stdin)"] = function()
    local _proc = _eliProc.spawn("sh", {"-c", "printf '173'"}, { stdio = { stdout = "ignore", stderr = "ignore" }})
    local _wr, _rd, _rderr = _proc:get_stdin(), _proc:get_stdout(), _proc:get_stderr()    
    _test.assert(_proc:wait() == 0 and _rd == nil and _rderr == nil, _wr ~= nil)
end

_test["spawn (file as stdin)"] = function()
    local _stdinFile = io.open("assets/test.script", "r");
    local _result = _eliProc.spawn("sh", {}, {wait = true, stdio = { stdin = _stdinFile }})
    _test.assert(_result.exitcode == 0 and _result.stdoutStream:read("a") == "13354\n")
end

_test["spawn (stdin/stdout/stderr as path)"] = function()
    local _result = _eliProc.spawn("sh", {}, {
        wait = true,
        stdio = {
            stdin = "assets/test.script",
            stdout = "/tmp/stdout.log",
            stderr = "/tmp/stderr.log"
        }
    })
    _test.assert(_result.exitcode == 0 and _result.stdoutStream:read("a") == "13354\n")
end

if not TEST then
    _test.summary()
end
