local urlLoaded, url = pcall(require, "eli.net.url")
local test = require"u-test"
local util = require"eli.util"

if not urlLoaded then
	test["eli.net.url not available"] = function ()
		test.assert(false, "eli.net.url not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["(url) queries"] = function ()
	local u = url.parse"http://www.example.com"
	u.query.net = "url"
	test.assert("http://www.example.com/?net=url" == tostring(u), "not equal")

	u.query.net = "url 2nd try"
	test.assert("net=url%202nd%20try" == tostring(u.query), "not equal")
	test.assert("http://www.example.com/?net=url%202nd%20try" == tostring(u), "not equal")

	u.query = u.query & { net2 = "url 2nd try" }
	test.assert("net=url%202nd%20try&net2=url%202nd%20try" == tostring(u.query), "not equal")
end
test["(url) parameter removal"] = function ()
	local u = url.parse"http://www.example.com/?last=mansion&first=bertrand&test=more"

	test.assert("http://www.example.com/?first=bertrand&last=mansion&test=more" == tostring(u), "incorrectly sorted query")
	u.query.test = nil
	test.assert("http://www.example.com/?first=bertrand&last=mansion" == tostring(u), "failed to remove query parameter 1")
	u.query.first = nil
	test.assert("http://www.example.com/?last=mansion" == tostring(u), "failed to remove query parameter 2")
	u.query.last = nil
	test.assert("http://www.example.com/" == tostring(u), "failed to remove query parameter 3")
end

test["(url) space in parameters"] = function ()
	local u = url.parse"http://www.example.com/"
	u:set_query"dilly%20all.day&flapdoodle"
	test.assert("http://www.example.com/?dilly_all.day&flapdoodle" == tostring(u), "not equal")
end

test["(url) query with brackets"] = function ()
	local u = url.parse"http://www.example.com/"
	u.query = url.parse_query"start=10&test[0][first][1.1][20]=coucou"
	test.assert("http://www.example.com/?start=10&test[0][first][1.1][20]=coucou" == tostring(u),
		"not equal")
	test.assert("10" == u.query.start, "'start' not equal")
	test.assert("coucou" == u.query.test[0]["first"]["1.1"][20], "nested not equal")
end

test["(url) schemes"] = function ()
	local u = url.parse"http://example.com/"
	test.assert("http" == u.scheme, "scheme not matching")
	u.scheme = "gopher"
	test.assert("gopher://example.com/" == tostring(u), "scheme not matching")
end

test["(url) fragment"] = function ()
	local u = url.parse"http://example.com/"
	u.fragment = "lua"
	test.assert("http://example.com/#lua" == tostring(u), "fragment mismatch")
end

test["(url) valid credentials"] = function ()
	local u = url.parse"https://john:smith@bing.com"
	test.assert(u.username == "john" and u.password == "smith", "credentials mismatch")
end

test["(url) invalid credentials"] = function ()
	local u = url.parse"https://example.com\\uFF03@bing.com"
	test.assert(u.username == nil and u.password == nil, "username or password found")
end

test["(url) valid hostname"] = function ()
	-- Test valid domain name
	local u = url.parse"http://lua.org"
	test.assert(u.host == "lua.org", "host not found")

	-- Test valid IPv4 address
	u = url.parse"http://192.0.2.146:80/test"
	test.assert(u.host == "192.0.2.146", "host not found")

	-- Test valid IPv6 address
	u = url.parse"http://[2001:db8::ff00:42:8329]:8080/test"
	test.assert(u.host == "2001:db8::ff00:42:8329", "host not found")
	-- Test valid IPv6 address
	u = url.parse"http://[::1]:8080/test"
	test.assert(u.host == "::1", "host not found")

	-- Test valid IPv4-mapped IPv6 address
	u = url.parse"http://[::ffff:192.0.2.128]:8080/test"
	test.assert(u.host == "::ffff:192.0.2.128", "host not found")

	-- Test valid hostname with subdomain
	u = url.parse"http://subdomain.example.com"
	test.assert(u.host == "subdomain.example.com", "host not found")

	-- Test valid hostname with hyphen
	u = url.parse"http://example-domain.com"
	test.assert(u.host == "example-domain.com", "host not found")

	-- Test valid hostname with port number
	u = url.parse"http://example.com:8080"
	test.assert(u.host == "example.com", "host not found")
end

test["(url) invalid hostname"] = function ()
	local u = url.parse"http:// lua.org"
	test.assert(u.host == nil, "host found")

	u = url.parse"http://127.260.30.1:80/test"
	test.assert(u.host == nil, "host not nil")

	u = url.parse"http://[56FE::2159:5BBC::6594]:8080/test"
	test.assert(u.host == nil, "host not nil")
end

test["(url) resolution"] = function ()
	local samples = {
		["g:h"] = "g:h",
		["g"] = "http://a/b/c/g",
		["./g"] = "http://a/b/c/g",
		["g/"] = "http://a/b/c/g/",
		["/g"] = "http://a/g",
		["//g"] = "http://g",
		["?y"] = "http://a/b/c/d;p?y",
		["g?y"] = "http://a/b/c/g?y",
		["#s"] = "http://a/b/c/d;p?q#s",
		["g#s"] = "http://a/b/c/g#s",
		["g?y#s"] = "http://a/b/c/g?y#s",
		[";x"] = "http://a/b/c/;x",
		["g;x"] = "http://a/b/c/g;x",
		["g;x?y#s"] = "http://a/b/c/g;x?y#s",
		[""] = "http://a/b/c/d;p?q",
		["."] = "http://a/b/c/",
		["./"] = "http://a/b/c/",
		[".."] = "http://a/b/",
		["../"] = "http://a/b/",
		["../g"] = "http://a/b/g",
		["../.."] = "http://a/",
		["../../"] = "http://a/",
		["../../g"] = "http://a/g",
		["../../../g"] = "http://a/g",
		["../../../../g"] = "http://a/g",
		["/./g"] = "http://a/g",
		["/../g"] = "http://a/g",
		["g."] = "http://a/b/c/g.",
		[".g"] = "http://a/b/c/.g",
		["g.."] = "http://a/b/c/g..",
		["..g"] = "http://a/b/c/..g",
		["./../g"] = "http://a/b/g",
		["./g/."] = "http://a/b/c/g/",
		["g/./h"] = "http://a/b/c/g/h",
		["g/../h"] = "http://a/b/c/h",
		["g;x=1/./y"] = "http://a/b/c/g;x=1/y",
		["g;x=1/../y"] = "http://a/b/c/y",
		["g?y/./x"] = "http://a/b/c/g?y%2F.%2Fx",
		["g?y/../x"] = "http://a/b/c/g?y%2F..%2Fx",
		["g#s/./x"] = "http://a/b/c/g#s/./x",
		["g#s/../x"] = "http://a/b/c/g#s/../x",
	}

	for k, v in pairs(samples) do
		local u = url.parse"http://a/b/c/d;p?q"
		local res = u:resolve(k)
		test.assert(tostring(res) == v, "Test resolve '" .. k .. "' => '" .. v .. " => " .. tostring(res))
	end
end

test["(url) normalization"] = function ()
	local samples = {
		["/foo/bar/."] = "/foo/bar/",
		["/foo/bar/./"] = "/foo/bar/",
		["/foo/bar/.."] = "/foo/",
		["/foo/bar/../"] = "/foo/",
		["/foo/bar/../baz"] = "/foo/baz",
		["/foo/bar/../.."] = "/",
		["/foo/bar/../../"] = "/",
		["/foo/bar/../../baz"] = "/baz",
		["/./foo"] = "/foo",
		["/foo."] = "/foo.",
		["/.foo"] = "/.foo",
		["/foo.."] = "/foo..",
		["/..foo"] = "/..foo",
		["/./foo/."] = "/foo/",
		["/foo/./bar"] = "/foo/bar",
		["/foo/../bar"] = "/bar",
		["/foo//"] = "/foo/",
		["/foo///bar//"] = "/foo/bar/",
		["http://www.foo.com:80/foo"] = "http://www.foo.com/foo",
		["http://www.foo.com/foo/../foo"] = "http://www.foo.com/foo",
		["http://www.foo.com:8000/foo"] = "http://www.foo.com:8000/foo",
		["http://www.foo.com/%7ebar"] = "http://www.foo.com/~bar",
		["http://www.foo.com/%7Ebar"] = "http://www.foo.com/~bar",
		["http://www.foo.com/?p=529&#038;cpage=1#comment-783"] = "http://www.foo.com/?p=529#038;cpage=1#comment-783",
		["/foo/bar/../../../baz"] = "/baz",
		["/foo/bar/../../../../baz"] = "/baz",
		["/./../foo"] = "/foo",
		["/../foo"] = "/foo",
		["foo/../test"] = "test",
	}

	for k, v in pairs(samples) do
		local u = url.parse(k):normalize()
		test.assert(tostring(u) == v, "Test normalize '" .. k .. "' => '" .. v .. "' => '" .. tostring(u) .. "'")
	end
end

test["(url) parse"] = function ()
	local samples = {
		["http://:@example.com/"] = "http://example.com/",
		["http://@example.com/"] = "http://example.com/",
		["http://example.com"] = "http://example.com",
		["HTTP://example.com/"] = "http://example.com/",
		["http://EXAMPLE.COM/"] = "http://example.com/",
		["http://example.com/%7Ejane"] = "http://example.com/~jane",
		["http://example.com/?q=%C3%87"] = "http://example.com/?q=%C3%87",
		["http://example.com/?q=%E2%85%A0"] = "http://example.com/?q=%E2%85%A0",
		["http://example.com/?q=%5c"] = "http://example.com/?q=%5C",
		["http://example.com/?q=%5C"] = "http://example.com/?q=%5C",
		["http://example.com:80/"] = "http://example.com/",
		["http://example.com/"] = "http://example.com/",
		["http://example.com/~jane"] = "http://example.com/~jane",
		["http://example.com/a/b"] = "http://example.com/a/b",
		["http://example.com:8080/"] = "http://example.com:8080/",
		["http://user:password@example.com/"] = "http://user:password@example.com/",
		["http://www.ietf.org/rfc/rfc2396.txt"] = "http://www.ietf.org/rfc/rfc2396.txt",
		["telnet://192.0.2.16:80/"] = "telnet://192.0.2.16:80/",
		["ftp://ftp.is.co.za/rfc/rfc1808.txt"] = "ftp://ftp.is.co.za/rfc/rfc1808.txt",
		["http://[2001:db8::7]/?a=b"] = "http://[2001:db8::7]/?a=b",
		["http://[2001:db8::1:0:0:1]:8080/test?a=b"] = "http://[2001:db8::1:0:0:1]:8080/test?a=b",
		["mailto:John.Doe@example.com"] = "mailto:John.Doe@example.com",
		["news:comp.infosystems.www.servers.unix"] = "news:comp.infosystems.www.servers.unix",
		["urn:oasis:names:specification:docbook:dtd:xml:4.1.2"] = "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
		["http://www.w3.org/2000/01/rdf-schema#"] = "http://www.w3.org/2000/01/rdf-schema#",
		["http://127.0.0.1/"] = "http://127.0.0.1/",
		["http://127.0.0.1:80/"] = "http://127.0.0.1/",
		["http://example.com:081/"] = "http://example.com:81/",
		["http://example.com/?q=foo"] = "http://example.com/?q=foo",
		["http://example.com?q=foo"] = "http://example.com/?q=foo",
		["http://example.com/a/../a/b"] = "http://example.com/a/../a/b",
		["http://example.com/a/./b"] = "http://example.com/a/./b",
		["http://example.com/A/./B"] = "http://example.com/A/./B", -- don't convert path case
		["/test"] = "/test",                                   -- keep absolute paths
		["foo/bar"] = "foo/bar",                               -- keep relative paths
		-- encoding tests
		["https://google.com/Link with a space in it/"] = "https://google.com/Link%20with%20a%20space%20in%20it/",
		["https://google.com/Link%20with%20a%20space%20in%20it/"] = "https://google.com/Link%20with%20a%20space%20in%20it/",
		["https://google.com/a%2fb%2fc/"] = "https://google.com/a%2Fb%2Fc/",
		["//lua.org/path?query=1:2"] = "//lua.org/path?query=1:2",
		["http://www.foo.com/some +path/?args=foo%2Bbar"] = "http://www.foo.com/some%20%2Bpath/?args=foo%2Bbar",
		-- by default, a "plus" sign in query value is encoded as %20
		["http://www.foo.com/?args=foo+bar"] = "http://www.foo.com/?args=foo%20bar",
		-- by default, a space in query value is encoded as %20
		["http://www.foo.com/?args=foo bar"] = "http://www.foo.com/?args=foo%20bar",
		["http://www.foo.com/some%20%20path/?args=foo%20bar"] = "http://www.foo.com/some%20%20path/?args=foo%20bar",
		["http://www.foo.com/some%2B%2Bpath/?args=foo%2Bbar"] = "http://www.foo.com/some%2B%2Bpath/?args=foo%2Bbar",
	}


	for k, v in pairs(samples) do
		local u = url.parse(k)
		test.assert(tostring(u) == v, "Test rebuild and clean '" .. k .. "' => '" .. v .. " => " .. tostring(u))
	end
end

test["(url) query mutation"] = function ()
	local samples = {
		-- can also encode plus sign as %2B instead of space (option)
		["http://www.foo.com/?args=foo+bar"] = "http://www.foo.com/?args=foo%2Bbar",
		-- can also leave plus sign alone in path (option)
		["http://www.foo.com/some +path/?args=foo+bar"] = "http://www.foo.com/some%20+path/?args=foo%2Bbar",
	}

	local optionsBackup = util.clone(url.options, true)

	for k, v in pairs(samples) do
		url.options.legalInPath["+"] = true;
		url.options.queryPlusIsSpace = false;
		local u = url.parse(k)
		test.assert(tostring(u) == v, "Test plus sign '" .. k .. "' => '" .. v .. " => " .. tostring(u))
	end

	url.options = optionsBackup
end

test["(url) to components"] = function ()
	local urlObj = url.parse"https://www.example.com:8080/path/to/resource?param1=value1&param2=value2#fragment"
	local scheme, host, port, pathQueryFragment, credentials = url.to_http_request_components(urlObj)

	test.assert(scheme == "https", "Scheme should be 'https'")
	test.assert(host == "www.example.com", "Host should be 'www.example.com'")
	test.assert(port == 8080, "Port should be '8080'")
	test.assert(pathQueryFragment == "/path/to/resource?param1=value1&param2=value2#fragment",
		"Path, query and fragment should be '/path/to/resource?param1=value1&param2=value2#fragment'")
	test.assert(credentials == nil, "Credentials should be nil")

	-- // test without port
	urlObj = url.parse"https://www.example.com/path/to/resource?param1=value1&param2=value2#fragment"
	scheme, host, port, pathQueryFragment, credentials = url.to_http_request_components(urlObj)

	test.assert(scheme == "https", "Scheme should be 'https'")
	test.assert(host == "www.example.com", "Host should be 'www.example.com'")
	test.assert(port == nil, "Port should be nil")
	test.assert(pathQueryFragment == "/path/to/resource?param1=value1&param2=value2#fragment",
		"Path, query and fragment should be '/path/to/resource?param1=value1&param2=value2#fragment'")
	test.assert(credentials == nil, "Credentials should be nil")

	-- // test without port and fragment and with credentials
	urlObj = url.parse"https://user:password@localhost/path/to/resource?param1=value1&param2=value2"
	scheme, host, port, pathQueryFragment, credentials = url.to_http_request_components(urlObj)

	test.assert(scheme == "https", "Scheme should be 'https'")
	test.assert(host == "localhost", "Host should be 'localhost'")
	test.assert(port == nil, "Port should be nil")
	test.assert(pathQueryFragment == "/path/to/resource?param1=value1&param2=value2",
		"Path, query and fragment should be '/path/to/resource?param1=value1&param2=value2'")
	test.assert(credentials == "user:password", "Credentials should be 'user:password'")
end

test["(url) add segment through /"] = function ()
	local urlObj = url.parse"https://www.example.com:8080/path/to/resource?param1=value1&param2=value2#fragment"
	urlObj = urlObj / "newSegment"

	test.assert(
		tostring(urlObj) == "https://www.example.com:8080/path/to/resource/newSegment?param1=value1&param2=value2#fragment",
		"Path should be 'https://www.example.com:8080/path/to/resource/newSegment?param1=value1&param2=value2#fragment'")

	-- multiple segments
	urlObj = url.parse"https://www.example.com:8080/path/to/resource?param1=value1&param2=value2#fragment"
	urlObj = urlObj / "newSegment" / "anotherSegment"

	test.assert(
		tostring(urlObj) ==
		"https://www.example.com:8080/path/to/resource/newSegment/anotherSegment?param1=value1&param2=value2#fragment",
		"Path should be 'https://www.example.com:8080/path/to/resource/newSegment/anotherSegment?param1=value1&param2=value2#fragment'")
end



test["(queries) string with array values"] = function ()
	local s = "first=abc&a[]=123&a[]=false&b[]=str&c[]=3.5&a[]=last"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		first = "abc",
		a = {
			"123", "false", "last",
		},
		b = { "str" },
		c = { "3.5" },
	}, true), "not equal")
end

test["(queries) query with empty string"] = function ()
	local s = "first&second=&a[]=&a[]&a[4]=&b[1][1]"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		first = "",
		second = "",
		a = {
			"", "", [4] = "",
		},
		b = { { "" } },
	}, true), "not equal")
	test.assert(tostring(q) == "a[1]&a[2]&a[4]&b[1][1]&first&second", "not equal")
end

test["(queries) numerical array keys"] = function ()
	local s = "arr[0]=sid&arr[4]=bill"
	local q = url.parse_query(s)

	test.assert(util.equals(q, { arr = { [0] = "sid", [4] = "bill" } }, true), "not equal")
end

test["(queries) string containing associative keys"] = function ()
	local s = "arr[first]=sid&arr[last]=bill"
	local q = url.parse_query(s)

	test.assert(util.equals(q, { arr = { first = "sid", last = "bill" } }, true), "not equal")
end

test["(queries) string with encoded data and plus signs"] = function ()
	local s = "a=%3c%3d%3d%20%20foo+bar++%3d%3d%3e&b=%23%23%23Hello+World%23%23%23"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["a"] = "<==  foo bar  ==>",
		["b"] = "###Hello World###",
	}, true), "not equal")
end

test["(queries) string with single quotes characters"] = function ()
	local s = "firstname=Bill&surname=O%27Reilly"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["firstname"] = "Bill",
		["surname"] = "O'Reilly",
	}, true), "not equal")
end

test["(queries) string with backslash characters"] = function ()
	local s = "sum=10%5c2%3d5"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["sum"] = "10\\2=5",
	}, true), "not equal")
end

test["(queries) string with double quotes data"] = function ()
	local s = "str=A%20string%20with%20%22quoted%22%20strings"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["str"] = 'A string with "quoted" strings',
	}, true), "not equal")
end

test["(queries) string with nulls"] = function ()
	local s = "str=A%20string%20with%20%00%00%00%20nulls"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["str"] = "A string with \0\0\0 nulls",
	}, true), "not equal")
end

test["(queries) 2-dim array with numeric keys"] = function ()
	local s = "arr[3][4]=sid&arr[3][6]=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr"] = {
			[3] = {
				[4] = "sid",
				[6] = "fred",
			},
		},
	}, true), "not equal")
end

test["(queries) 2-dim array with null keys"] = function ()
	local s = "arr[][]=sid&arr[][]=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr"] = {
			[1] = { [1] = "sid" },
			[2] = { [1] = "fred" },
		},
	}, true), "not equal")
end

test["(queries) 2-dim array with non-numeric keys"] = function ()
	local s = "arr[one][four]=sid&arr[three][six]=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr"] = {
			["one"] = { ["four"] = "sid" },
			["three"] = { ["six"] = "fred" },
		},
	}, true), "not equal")
end

test["(queries) 3-dim array with numeric keys"] = function ()
	local s = "arr[1][2][3]=sid&arr[1][2][6]=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr"] = {
			[1] = {
				[2] = {
					[3] = "sid",
					[6] = "fred",
				},
			},
		},
	}, true), "not equal")
end

test["(queries) string with badly formed strings 1"] = function ()
	local s = "arr[1=sid&arr[4][2=fred&arr[4][3]=test&arr][4]=abc&arr]1=tata&arr[4]2]=titi"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr[1"] = "sid",
		["arr"] = { [4] = "titi" },
		["arr]"] = { [4] = "abc" },
		["arr]1"] = "tata",
	}, true), "not equal")
end

test["(queries) string with badly formed strings 2"] = function ()
	local s = "arr1]=sid&arr[4]2]=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr1]"] = "sid",
		["arr"] = { [4] = "fred" },
	}, true), "not equal")
end

test["(queries) string with badly formed strings 3"] = function ()
	local s = "arr[one=sid&arr[4][two=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr[one"] = "sid",
		["arr"] = { [4] = "fred" },
	}, true), "not equal")
end

test["(queries) string with badly formed % numbers"] = function ()
	local s = "first=%41&second=%a&third=%b"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["first"] = "A",
		["second"] = "%a",
		["third"] = "%b",
	}, true), "not equal")
end

test["(queries) string with non-binary safe name"] = function ()
	local s = "arr.test[1]=sid&arr test[4][two]=fred"
	local q = url.parse_query(s)

	test.assert(util.equals(q, {
		["arr.test"] = { [1] = "sid" },
		["arr_test"] = {
			[4] = { ["two"] = "fred" },
		},
	}, true), "not equal")
end

test["(queries) Non default separator"] = function ()
	local optionsBackup = util.clone(url.options, true)
	url.options.separator = ";"
	local s = ";first=val1;;;;second=val2;third[1]=val3;"
	local q = url.parse_query(s)

	url.options = optionsBackup

	test.assert(util.equals(q, {
		["first"] = "val1",
		["second"] = "val2",
		["third"] = { [1] = "val3" },
	}, true), "not equal")
end

test["(queries) Same name parameters create a table"] = function ()
	local optionsBackup = util.clone(url.options, true)
	url.options.separator = "&"
	url.options.cumulativeParameters = true
	local s = "param=val1&param=val2"
	local q = url.parse_query(s)

	url.options = optionsBackup

	test.assert(util.equals(q, {
		["param"] = { [1] = "val1", [2] = "val2" },
	}, true), "not equal")
end

test["(queries) Mix brackets and cumulative parameters"] = function ()
	local optionsBackup = util.clone(url.options, true)
	url.options.cumulativeParameters = true
	local s = "param=val1&param=val2&param[test]=val3"
	local q = url.parse_query(s)

	url.options = optionsBackup

	test.assert(util.equals(q, {
		["param"] = { [1] = "val1", [2] = "val2", ["test"] = "val3" },
	}, true), "not equal")
end

if not TEST then
	test.summary()
end
