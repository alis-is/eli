local test = TEST or require"u-test"
local path = require"eli.path"

test["path core"] = function ()
	test.equal(path.combine("a", "b"), "a/b")
	test.equal(path.abs("script.lua", "/work"), "/work/script.lua")
	test.equal(path.dir("/work/script.lua"), "/work")
	test.equal(path.file("/work/script.lua"), "script.lua")
	test.equal(path.ext("archive.tar.gz"), "gz")
	test.equal(path.normalize("a/./b/../c/", "unix", { endsep = "leave" }), "a/c/")
	test.equal(path.commonpath("a/b", "a/c"), "a/")
	test.equal(path.rel("a/b", "a/c"), "../b")
	local ended, did_end = path.endsep("a", "unix", true)
	test.equal(ended, "a/")
	test.assert(did_end)
	test.equal(path.filename(" bad?.txt", "win", function (match) return match == "?" and "_" or "" end), "bad_.txt")
	test.equal(path.type("C:\\work", "win"), "abs")
	test.assert(path.isabs("C:\\work", "win"))
	test.equal(path.combine("C:\\work", "script.lua", "win"), "C:\\work\\script.lua")
end

if not TEST then test.summary() end
