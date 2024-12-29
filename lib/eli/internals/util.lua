local separator = require"eli.path".default_sep()
local join = require"eli.extensions.string".join

local internals_util = {}

function internals_util.get_root_dir(paths)
	-- check whether we have all files in same dir
	local rood_dir_segments = {}
	for _, path in ipairs(paths) do
		if #rood_dir_segments == 0 then
			for segment in string.gmatch(path, "(.-)[/\\]") do
				table.insert(rood_dir_segments, segment)
			end
		else
			local j = 0
			for segment in string.gmatch(path, "(.-)[/\\]") do
				if segment ~= rood_dir_segments[j + 1] then
					break
				end
				j = j + 1
			end
			if j < #rood_dir_segments then
				rood_dir_segments = table.move(rood_dir_segments, 1, j, 1, {})
			end
		end

		if #rood_dir_segments == 0 then
			break
		end
	end
	local root_dir = join(package.config:sub(1, 1), table.unpack(rood_dir_segments))
	if type(root_dir) == "string" and #root_dir > 0 and not root_dir:sub(#root_dir, #root_dir):match"[/\\]" then
		root_dir = root_dir .. separator
	end
	return root_dir or ""
end

return internals_util
