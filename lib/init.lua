ELI_LIB_VERSION = '0.38.0-alpha'
ELI_VERSION = '0.38.0-alpha'
do
	-- install process-global guards and the combined os extras
	-- before any application code can cache the original functions
	require"eli.worker"
	require"eli.os.extra"
	-- install the mbedtls threading runtime before any bundled mbedtls
	-- consumer (hash, zip) can initialize contexts
	require"socket"
	local path = require"eli.path"
	local _eos = require"eli.os"
	local exString = require"eli.extensions.string"
	local i_min = 0
	while arg[i_min] do
		i_min = i_min - 1
	end

	local function try_identify_interpreter(interpreter)
		if path.default_sep() == "/" then
			local quoted = "'" .. interpreter:gsub("'", "'\\''") .. "'"
			local f = io.popen("which -- " .. quoted)
			if not f then return interpreter end
			local _path = f:read"a*"
			local closed = f:close()
			if not closed or _path == nil then return interpreter end
			_path = _path:gsub("[\r\n]+$", "")
			return _path ~= "" and _path or interpreter
		end
		return interpreter
	end

	INTERPRETER = arg[i_min + 1]
	if not INTERPRETER:match(path.default_sep()) then
		local identified, _interpreter = pcall(try_identify_interpreter, INTERPRETER)
		if identified then
			INTERPRETER = _interpreter
		end
	elseif not path.isabs(INTERPRETER) and _eos.EOS then
		INTERPRETER = path.abs(INTERPRETER, _eos.cwd())
	end

	if i_min == -1 then                   -- we are running without script (interactive mode)
		APP_ROOT = nil
	else
		if _eos.EOS and not path.isabs(arg[0]) then
			APP_ROOT_SCRIPT = path.abs(arg[0], _eos.cwd())
		else
			APP_ROOT_SCRIPT = arg[0]
		end
		APP_ROOT = path.dir(APP_ROOT_SCRIPT)
	end

	APP_ROOT = exString.trim(APP_ROOT)            -- remove leading and trailing whitespaces
	APP_ROOT_SCRIPT = exString.trim(APP_ROOT_SCRIPT) -- remove leading and trailing whitespaces

	local _shouldElify = true
	for i, v in ipairs(arg) do
		if v == "--lua-env" then
			_shouldElify = false
			table.remove(arg, i)
			break
		end
	end
	local _elify = require"eli.elify".elify
	if _shouldElify then
		_elify()
	else -- if not elified initial we make elify global
		elify = _elify
	end
end
