local test = TEST or require"u-test"
local _ok, eliProc = pcall(require, "eli.proc")
local eliFs = require"eli.fs"
local eliPath = require"eli.path"

if not _ok then
	test["eli.proc available"] = function ()
		test.assert(false, "eli.proc not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

local pathSeparator = package.config:sub(1, 1)

test["eli.proc available"] = function ()
	test.assert(true)
end

test["exec"] = function ()
	local result = eliProc.exec"echo 135"
	test.assert(result.exitcode == 0 and result.stdoutStream == nil and result.stderrStream == nil)
end

test["exec (stdout)"] = function ()
	local result = eliProc.exec("echo 135", { stdout = "pipe" })
	test.assert(result.exitcode == 0 and string.trim(result.stdoutStream:read"a") == "135" and
		result.stderrStream == nil)
end

test["exec (stdout - path)"] = function ()
	local result = eliProc.exec("echo 135", { stdout = "tmp/stdout.tmp" })
	test.assert(result.exitcode == 0 and string.trim(result.stdoutStream:read"a") == "135" and
		result.stderrStream == nil)
end

test["exec (stderr)"] = function ()
	local cli = "sh -c"
	if pathSeparator == "\\" then
		cli = "cmd /c"
	end
	local _result = eliProc.exec(cli .. " \"echo error 173 >&2\"", { stderr = "pipe" })
	test.assert(_result.exitcode == 0 and _result.stdoutStream == nil and
		string.trim(_result.stderrStream:read"a") == "error 173")
end

test["exec (stderr - path)"] = function ()
	local cli = "sh -c"
	if pathSeparator == "\\" then
		cli = "cmd /c"
	end
	local result = eliProc.exec(cli .. " \"echo error 173 >&2\"", { stderr = "tmp/stderr.tmp" })
	test.assert(result.exitcode == 0 and result.stdoutStream == nil and
		string.trim(result.stderrStream:read"a") == "error 173")
end

test["exec (stdin)"] = function ()
	local scriptPath = eliPath.combine("tmp", "script")
	local ok = eliFs.safe_write_file(scriptPath, "123\n\n")
	test.assert(ok, "Failed to write stdin file")
	local result = eliProc.exec("more", { stdin = scriptPath, stdout = "pipe" })
	test.assert(result.exitcode == 0 and string.trim(result.stdoutStream:read"a") == "123" and
		result.stderrStream == nil)
end

if not eliProc.EPROC then
	if not TEST then
		test.summary()
		print"EPROC not detected, only basic tests executed..."
		os.exit()
	else
		print"EPROC not detected, only basic tests executed..."
		return
	end
end

local isUnixLike = package.config:sub(1, 1) == "/"
test["spawn"] = function ()
	local testExecutable = isUnixLike and "sh" or "cmd"
	local proc, _, _ = eliProc.spawn(testExecutable)
	local wr = proc:get_stdin()
	wr:write"echo 173\n"
	wr:write"exit\n"
	local exitcode = proc:wait()
	local result = proc:get_stdout():read"a"
	test.assert(exitcode == 0 and result:match"173")
end

test["spawn (cleanup)"] = function ()
	local testExecutable = isUnixLike and "sh" or "cmd"
	function t()
		local _, _, _ = eliProc.spawn(testExecutable)
	end

	t()
	-- we would segfault/sigbus here if cleanup does not work properly
	test.assert(true)
end

test["spawn (not found)"] = function ()
	local testExecutable = "nonExistentExecutable"
	local ok, _ = eliProc.safe_spawn(testExecutable)
	test.assert(not ok)
end

test["spawn (args)"] = function ()
	local proc = isUnixLike and eliProc.spawn("printf", { "173" }) or eliProc.spawn("cmd", { "/c", "echo", "173" })
	local exit = proc:wait()
	local result = proc:get_stdout():read"a"
	test.assert(exit == 0 and result:match"173")
end

test["spawn (wait)"] = function ()
	local options = { wait = true }
	local result = isUnixLike and
		eliProc.spawn("sh", { "-c", "printf '173'" }, options) or
		eliProc.spawn("cmd", { "/c", "echo 173" }, options)
	test.assert(result.exitcode == 0 and result.stdoutStream:read"a":match"173")
end

test["spawn (custom env)"] = function ()
	local options = { wait = true, env = { TEST = "test env variable" } }
	local result = isUnixLike and
		eliProc.spawn("sh", { "-c", "printf \"$TEST\"" }, options) or
		eliProc.spawn("cmd", { "/c", "echo", '"%TEST%"' }, options)
	test.assert(0 == result.exitcode and result.stdoutStream:read"a":match"test env variable")
end

test["spawn (custom stdout)"] = function ()
	local stdoutFile = io.open("tmp/test.stdout", "w+")
	local options = { wait = true, stdio = { stdout = stdoutFile } }
	local result = isUnixLike and
		eliProc.spawn("sh", { "-c", "printf '173'" }, options) or
		eliProc.spawn("cmd", { "/c", "echo 173" }, options)
	local _stdout = string.trim(eliFs.read_file"tmp/test.stdout")
	test.assert(result.exitcode == 0 and _stdout == "173")
end

test["spawn (custom stderr)"] = function ()
	local stderrFile = io.open("tmp/test.stderr", "w+")
	local options = { stdio = { stderr = stderrFile } }
	local command = isUnixLike and
		"printf 'error 173' >&2;\n" or
		"echo error 173 >&2;\n"
	local proc = isUnixLike and
		eliProc.spawn("sh", {}, options) or
		eliProc.spawn("cmd", {}, options)
	local wr = proc:get_stdin()
	wr:write(command)
	wr:write"exit\n"
	local exit = proc:wait()
	local result = eliFs.read_file"tmp/test.stderr"
	test.assert(exit == 0 and result:match"error 173")
end

test["spawn (stdin)"] = function ()
	local proc = eliProc.spawn(isUnixLike and "sh" or "cmd.exe", {}, { wait = false })
	local wr, rd, rderr = proc:get_stdin(), proc:get_stdout(), proc:get_stderr()
	wr:write(isUnixLike and "printf '172'\n" or "echo 172\n")
	wr:write(isUnixLike and "printf 'error 173' >&2;\n" or "echo error 173 >&2;\n")
	wr:write"exit\n"
	local exit = proc:wait()
	local result = rd:read"a"
	local error = rderr:read"a"
	test.assert(exit == 0 and result:match"172" and error:match"error 173")
end

test["spawn (stdio=ignore)"] = function ()
	local options = { wait = true, stdio = "ignore" }
	local result = isUnixLike and
		eliProc.spawn("sh", { "-c", "printf '173'" }, options) or
		eliProc.spawn("cmd", { "/c", "echo 173" }, options)
	test.assert(result.exitcode == 0 and result.stdoutStream == nil and result.stderrStream == nil)
end

test["spawn (stdio=ignore stdout and stderr only)"] = function ()
	local options = { stdio = { stdout = "ignore", stderr = "ignore" } }
	local proc = isUnixLike and
		eliProc.spawn("sh", { "-c", "printf '173'" }, options) or
		eliProc.spawn("cmd", { "/c", "echo 173" }, options)
	local wr, rd, rderr = proc:get_stdin(), proc:get_stdout(), proc:get_stderr()
	test.assert(proc:wait() == 0 and rd == nil and rderr == nil, wr ~= nil)
end

test["spawn (file as stdin)"] = function ()
	local stdinFile = io.open("assets/scripts/echo.script", "r");
	local options = { wait = true, stdio = { stdin = stdinFile } }
	local result = isUnixLike and
		eliProc.spawn("sh", options) or
		eliProc.spawn("cmd", options)
	local stdout = result.stdoutStream:read"a"
	test.assert(result.exitcode == 0 and stdout:match"13354")
end

test["spawn (stdin/stdout/stderr as path)"] = function ()
	local options = {
		wait = true,
		stdio = {
			stdin = "assets/scripts/echo.script",
			stdout = "tmp/stdout.log",
			stderr = "tmp/stderr.log",
		},
	}
	local result = isUnixLike and
		eliProc.spawn("sh", options) or
		eliProc.spawn("cmd", options)
	local _stdout = result.stdoutStream:read"a"
	test.assert(result.exitcode == 0 and _stdout:match"13354")
end

test["spawn (process group)"] = function ()
	if not isUnixLike then
		-- "process group not tested on windows"
		return
	end
	local options = {
		wait = false,
		createProcessGroup = true,
	}
	local proc = eliProc.spawn("sh", { "-c", "sleep 10" }, options)
	local testCmd = string.interpolate("ps -eo pid,pgid | grep -E \"${pid}\\s+${pid}\"", { pid = proc:get_pid() })
	test.assert(os.execute(testCmd))
end

test["spawn (separated output)"] = function ()
	local stdinFile = io.open("assets/scripts/stdout_stderr.script", "r");
	local options = { wait = true, stdio = { stdin = stdinFile, stdout = "pipe", stderr = "pipe" } }
	local result = isUnixLike and
		eliProc.spawn("sh", options) or
		eliProc.spawn("cmd", options)
	local stdout = result.stdoutStream:read"a"
	local stderr = result.stderrStream:read"a"
	test.assert(result.exitcode == 0 and stdout:match"stdout" and stderr:match"stderr")
end

test["spawn (combined output)"] = function ()
	local stdinFile = io.open("assets/scripts/stdout_stderr.script", "r");
	local options = { wait = true, stdio = { stdin = stdinFile, output = "pipe" } }
	local result = isUnixLike and
		eliProc.spawn("sh", options) or
		eliProc.spawn("cmd", options)
	local stdout = result.stdoutStream:read"a"
	test.assert(result.exitcode == 0 and stdout:match"stdout" and stdout:match"stderr")
end

test["spawn (read timeout)"] = function ()
	local options = { stdio = { output = "pipe" } }
	local result = isUnixLike and
		eliProc.spawn("sh", { "assets/scripts/delayed.sh" }, options) or
		eliProc.spawn("cmd", { "/c", "assets\\scripts\\delayed.bat" }, options) --[[@as EliProcess]]
	local output = result:get_stdout()
	test.assert(output ~= nil)
	local content = output:read("a", 1, "s")
	test.assert(not content:match"12345")
	content = output:read("a", 10, "s")
	test.assert(content:match"12345")
	test.assert(result:wait() == 0)
end

test["spawn (read timeout ms)"] = function ()
	local options = { stdio = { output = "pipe" } }
	local result = isUnixLike and
		eliProc.spawn("sh", { "assets/scripts/delayed.sh" }, options) or
		eliProc.spawn("cmd", { "/c", "assets\\scripts\\delayed.bat" }, options) --[[@as EliProcess]]
	local output = result:get_stdout()
	test.assert(output ~= nil)
	local beforeRead = os.time()
	local content = output:read("a", 10, "ms")
	test.assert(os.time() - beforeRead <= 1)
	test.assert(content == "")
	content = output:read("a", 5, "s")
	test.assert(content:match"12345")
	test.assert(result:wait() == 0)
	test.assert(output:read("a", 5, "ms") == nil)
end

test["spawn (read timeout divider)"] = function ()
	local options = { stdio = { output = "pipe" } }
	local result = isUnixLike and
		eliProc.spawn("sh", { "assets/scripts/delayed.sh" }, options) or
		eliProc.spawn("cmd", { "/c", "assets\\scripts\\delayed.bat" }, options) --[[@as EliProcess]]
	local output = result:get_stdout()
	test.assert(output ~= nil)
	local beforeRead = os.time()
	local content = output:read("a", 10, 1000)
	test.assert(os.time() - beforeRead <= 1)
	test.assert(content == "")
	content = output:read("a", 5, "s")
	test.assert(content:match"12345")
	test.assert(result:wait() == 0)
	test.assert(output:read("a", 5, "ms") == nil)
end

if not TEST then
	test.summary()
end
