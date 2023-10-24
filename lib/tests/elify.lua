local test = TEST or require"u-test"

test["is_elified"] = function ()
	test.assert(require"eli.elify".is_elified() == true)
end

test["cli"] = function ()
	test.assert(cli == require"eli.cli")
end

test["env"] = function ()
	test.assert(env == require"eli.env")
end

test["fs"] = function ()
	test.assert(fs == require"eli.fs")
end

test["hash"] = function ()
	test.assert(hash == require"eli.hash")
end

test["net"] = function ()
	test.assert(net == require"eli.net")
end

test["proc"] = function ()
	test.assert(proc == require"eli.proc")
end

test["util"] = function ()
	test.assert(util == require"eli.util")
end

test["ver"] = function ()
	test.assert(ver == require"eli.ver")
end

test["zip"] = function ()
	test.assert(zip == require"eli.zip")
end

test["os"] = function ()
	local _eliOs = require"eli.os"
	test.assert(os ~= _eliOs)
	for k, v in pairs(_eliOs) do
		test.assert(os[k] == v)
	end
end

test["etype"] = function ()
	test.assert(etype"string" == "string")
	test.assert(etype(true) == "boolean")
	test.assert(etype(nil) == "nil")
	test.assert(etype(0) == "number")
	test.assert(etype{} == "table")
	local _t = { __type = "test" }
	setmetatable(_t, _t)
	test.assert(etype(_t) == "test")
end

test["get_overriden_values"] = function ()
	local _overriden = require"eli.elify".get_overriden_values()
	test.assert(_overriden.os == require"os")
	test.assert(_overriden.type ~= type)
end

test["extensions.string"] = function ()
	local _esx = require"eli.extensions.string"
	for k, v in pairs(_esx) do
		if k ~= "globalize" then
			test.assert(string[k] == v)
		end
	end
end

test["extensions.table"] = function ()
	local _etx = require"eli.extensions.table"
	for k, v in pairs(_etx) do
		if k ~= "globalize" then
			test.assert(table[k] == v)
		end
	end
end

if not TEST then
	test.summary()
end
