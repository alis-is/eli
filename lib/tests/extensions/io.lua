local test = TEST or require"u-test"
local ok, exIo = pcall(require, "eli.extensions.io")

if not ok then
	test["eli.extensions.io available"] = function ()
		test.assert(false, "eli.extensions.io not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["eli.extensions.io available"] = function ()
	test.assert(true)
end

test["file as stream - line"] = function ()
	local refContent = io.open"assets/test.file":read"l"
	local streamContent = exIo.open_fstream"assets/test.file":read"l"
	print(exIo.open_fstream"assets/test.file":read"l")
	test.assert(refContent == streamContent, "content does not match")

	local refContent = io.open"assets/test.file":read"a"
	local stream = exIo.open_fstream"assets/test.file"
	local streamContent = stream:read"a"
	while true do
		local line = stream:read"L"
		if not line then
			break
		end
		streamContent = streamContent .. line
	end

	test.assert(refContent == streamContent, "content does not match")
end

test["file as stream - all"] = function ()
	local refContent = io.open"assets/test.file":read"a"
	local streamContent = exIo.open_fstream"assets/test.file":read"a"

	test.assert(refContent == streamContent, "content does not match")
end

test["file as stream - bytes"] = function ()
	local refContent = io.open"assets/test.file":read"l"
	local streamContent = exIo.open_fstream"assets/test.file":read"l"

	test.assert(refContent == streamContent, "content does not match")

	local refContent = io.open"assets/test.file":read"a"
	local stream = exIo.open_fstream"assets/test.file"
	local streamContent = stream:read"a"
	while true do
		local line = stream:read(100)
		if not line then
			break
		end
		streamContent = streamContent .. line
	end

	test.assert(refContent == streamContent, "content does not match")
end

if not TEST then
	test.summary()
end