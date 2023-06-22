--
-- Embed the Lua scripts into src/host/scripts.c as static data buffers.
-- I embed the actual scripts, rather than Lua bytecodes, because the
-- bytecodes are not portable to different architectures, which causes
-- issues in Mac OS X Universal builds.
--

local function stripstring(s, type)
	if type == nil then
		type = "lua"
	end
	if type == "txt" then
		s = s:gsub("\\", "\\\\")
		s = s:gsub("\n", "\\n")
		s = s:gsub('"', '\\"')
		return s
	end

	-- this messes with whitespace strings
	-- s = s:gsub("[\t]", "")

	-- strip any CRs
	s = s:gsub("[\r]", "")

	-- strip out comments
	s = s:gsub("%-%-%[%[.-%]%]", "")
	s = s:gsub("\n%-%-[^\n]*", "")

	s = s:gsub("%-%-%[%[.-%]%]", "")

	-- escape backslashes
	s = s:gsub("\\", "\\\\")

	-- strip duplicate line feeds
	s = s:gsub("\n+", "\n")

	-- strip out leading comments
	s = s:gsub("^%-%-\n", "")

	-- escape line feeds
	s = s:gsub("\n", "\\n")

	-- escape double quote marks
	s = s:gsub('"', '\\"')

	-- remove multiple spaces
	-- this messes with whitespace strings
	-- s = s:gsub("%s+", " ")
	return s
end

local function stripfile(fname)
	local f <close> = io.open(fname)
	local s = assert(f:read("*a"))
	return stripstring(s)
end

return {
	escape_file = stripfile,
	escape_string = stripstring
}
