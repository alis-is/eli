ELI_LIB_VERSION = '0.32.0-dev.18'
ELI_VERSION = '0.32.0-dev.18'
do
	local path = require"eli.path"
	local _eos = require"eli.os"
	local i_min = 0
	while arg[i_min] do
		i_min = i_min - 1
	end

	local function try_identify_interpreter(interpreter)
		if path.default_sep() == "/" then
			local io = require"io"
			local f <close> = io.popen("which " .. interpreter)
			local _path = f:read"a*"
			if _path ~= nil then
				_path = _path:gsub("%s*", "")
			end
			return _path
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

	if i_min == -1 then -- we are running without script (interactive mode)
		APP_ROOT = nil
	else
		if _eos.EOS and not path.isabs(arg[0]) then
			APP_ROOT_SCRIPT = path.abs(arg[0], _eos.cwd())
		else
			APP_ROOT_SCRIPT = arg[0]
		end
		APP_ROOT = path.dir(APP_ROOT_SCRIPT)
	end

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
