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

local _isUnixLike = package.config:sub(1, 1) == "/"
_test["spawn"] = function()
    local _testExecutable = _isUnixLike and "sh" or "cmd"
    local _proc, _, _ = _eliProc.spawn(_testExecutable)
    local _wr = _proc:get_stdin()
    _wr:write("echo 173\n")
    _wr:write("exit\n")
    local _exitcode = _proc:wait()
    local _result = _proc:get_stdout():read("a")
    _test.assert(_exitcode == 0 and _result:match("173"))
end

_test["spawn (cleanup)"] = function()
    local _testExecutable = _isUnixLike and "sh" or "cmd"
    function _t()
        local _, _, _ = _eliProc.spawn(_testExecutable)
    end
    _t()
    -- we would segfault/sigbus here if cleanup does not work properly
    _test.assert(true)
end

_test["spawn (not found)"] = function()
    local _testExecutable = not _isUnixLike and "sh" or "cmd"
    local _ok, _err = _eliProc.safe_spawn(_testExecutable)
    _test.assert(not _ok and _err:match("The system cannot find the file specified") or _err:match("No such file or directory"))
end

_test["spawn (args)"] = function()
    local _proc = _isUnixLike and _eliProc.spawn("printf", { "173" }) or _eliProc.spawn("cmd", { "/c", "echo", "173" })
    local _exit = _proc:wait()
    local _result = _proc:get_stdout():read("a")
    _test.assert(_exit == 0 and _result:match("173"))
end

_test["spawn (wait)"] = function()
    local _options = {wait = true}
    local _result = _isUnixLike and 
        _eliProc.spawn("sh", {"-c", "printf '173'"}, _options) or
        _eliProc.spawn("cmd", {"/c", "echo 173"}, _options)
    _test.assert(_result.exitcode == 0 and _result.stdoutStream:read("a"):match("173"))
end

_test["spawn (custom env)"] = function()
    local _options = {wait = true, env = {TEST = "test env variable"}}
    local _result = _isUnixLike and 
        _eliProc.spawn("sh", {"-c", "printf \"$TEST\""}, _options) or
        _eliProc.spawn("cmd", {"/c", 'echo', '"%TEST%"'}, _options)
    _test.assert(0 == _result.exitcode and _result.stdoutStream:read("a"):match("test env variable"))
end

_test["spawn (custom stdout)"] = function()
    local _stdoutFile = io.open("tmp/test.stdout", "w+")
    local _options = {wait = true, stdio = { stdout = _stdoutFile }}
    local _result = _isUnixLike and
        _eliProc.spawn("sh", {"-c", "printf '173'"}, _options) or
        _eliProc.spawn("cmd", {"/c", 'echo 173'}, _options)
    local _stdout = string.trim(_eliFs.read_file("tmp/test.stdout"))
    _test.assert(_result.exitcode == 0 and _stdout == "173")
end

_test["spawn (custom stderr)"] = function()
    local _stderrFile = io.open("tmp/test.stderr", "w+")
    local _options = { stdio = { stderr = _stderrFile }}
    local _command = _isUnixLike and
        "printf 'error 173' >&2;\n" or
        "echo error 173 >&2;\n"
    local _proc = _isUnixLike and
        _eliProc.spawn("sh", {}, _options) or
        _eliProc.spawn("cmd", {}, _options)
    local _wr = _proc:get_stdin()
    _wr:write(_command)
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _eliFs.read_file("tmp/test.stderr")
    _test.assert(_exit == 0 and _result:match("error 173"))
end

_test["spawn (stdin)"] = function()
    local _proc = _eliProc.spawn(_isUnixLike and "sh" or "cmd.exe", {}, {wait = false})
    local _wr, _rd, _rderr = _proc:get_stdin(), _proc:get_stdout(), _proc:get_stderr()
    _wr:write(_isUnixLike and "printf '172'\n" or "echo 172\n")
    _wr:write(_isUnixLike and "printf 'error 173' >&2;\n" or "echo error 173 >&2;\n")
    _wr:write("exit\n")
    local _exit = _proc:wait()
    local _result = _rd:read("a")
    local _error = _rderr:read("a")
    _test.assert(_exit == 0 and _result:match("172") and _error:match('error 173'))
end

_test["spawn (stdio=ignore)"] = function()
    local _options = {wait = true, stdio = "ignore"}
    local _result = _isUnixLike and 
        _eliProc.spawn("sh", {"-c", "printf '173'"}, _options) or
        _eliProc.spawn("cmd", {"/c", "echo 173"}, _options)
    _test.assert(_result.exitcode == 0 and _result.stdoutStream == nil and _result.stderrStream == nil)
end

_test["spawn (stdio=ignore stdout and stderr only)"] = function()
    local _options = { stdio = { stdout = "ignore", stderr = "ignore" }}
    local _proc = _isUnixLike and 
        _eliProc.spawn("sh", {"-c", "printf '173'"}, _options) or
        _eliProc.spawn("cmd", {"/c", "echo 173"}, _options)
    local _wr, _rd, _rderr = _proc:get_stdin(), _proc:get_stdout(), _proc:get_stderr()
    _test.assert(_proc:wait() == 0 and _rd == nil and _rderr == nil, _wr ~= nil)
end

_test["spawn (file as stdin)"] = function()
    local _stdinFile = io.open("assets/test" .. (_isUnixLike and ".unix" or ".win") .. ".script", "r");
    local _options = {wait = true, stdio = { stdin = _stdinFile }}
    local _result = _isUnixLike and
        _eliProc.spawn("sh", _options) or
        _eliProc.spawn("cmd", _options)
    local _stdout = _result.stdoutStream:read("a")
    print(_result.exitcode, _stdout)
    _test.assert(_result.exitcode == 0 and _stdout:match("13354"))
end

_test["spawn (stdin/stdout/stderr as path)"] = function()
    local _options = {
        wait = true,
        stdio = {
            stdin = "assets/test" .. (_isUnixLike and ".unix" or ".win") .. ".script",
            stdout = "tmp/stdout.log",
            stderr = "tmp/stderr.log"
        }
    }
    local _result = _isUnixLike and
        _eliProc.spawn("sh", _options) or
        _eliProc.spawn("cmd", _options)
    local _stdout = _result.stdoutStream:read("a")
    print(_result.exitcode, _stdout)
    _test.assert(_result.exitcode == 0 and _stdout:match("13354"))
end

if not TEST then
    _test.summary()
end
