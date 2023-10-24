local url = {}
local exTable = require"eli.extensions.table"
local util = require"eli.util"

---@class UrlQuery: table<string | number, string | number | boolean>
---@operator band(UrlQuery, UrlQuery|string):UrlQuery

---@class Url
---@field scheme string
---@field __authority string
---@field path string
---@field port string?
---@field host string?
---@field kind string?
---@field query UrlQuery
---@field fragment string?
---@field username string?
---@field password string?
---@operator div(string):Url
---@field normalize fun():Url

local legalInPath = ":_-.!~*'()@&=$,;"
local legalInQuery = ":_-.,!~*';()@$"

---@param str string
local function split_to_map(str)
	local map = {}
	for char in str:gmatch"." do
		map[char] = true
	end
	return map
end

url.options = {
	separator = "&",
	cumulativeParameters = false,
	legalInPath = split_to_map(legalInPath),
	legalInQuery = split_to_map(legalInQuery),
	queryPlusIsSpace = true,
}

url.services = {
	http  = 80,
	https = 443,
}

function url.decode(str)
	return (str:gsub("%%(%x%x)", function (c)
		return string.char(tonumber(c, 16))
	end))
end

function url.encode(str, legal)
	return (str:gsub("([^%w])", function (v)
		if legal[v] then
			return v
		end
		return string.upper(string.format("%%%02x", string.byte(v)))
	end))
end

-- for query values, + can mean space if configured as such
local function decodeValue(str)
	if url.options.queryPlusIsSpace then
		str = str:gsub("+", " ")
	end
	return url.decode(str)
end


---builds url query
---@param tab table<string | number, string | number | boolean>
---@param sep? string
---@param key? string
---@return string
function url.build_query(tab, sep, key)
	local query = {}
	sep = sep or url.options.separator or "&"

	local keys = exTable.keys(tab)
	table.sort(keys, function (a, b)
		local function padnum(n, rest) return ("%03d" .. rest):format(tonumber(n)) end
		return tostring(a):gsub("(%d+)(%.)", padnum) < tostring(b):gsub("(%d+)(%.)", padnum)
	end)

	for _, name in ipairs(keys) do
		local value = tab[name]
		name = url.encode(tostring(name), { ["-"] = true, ["_"] = true, ["."] = true })
		if key then
			if url.options.cumulativeParameters and string.find(name, "^%d+$") then
				name = tostring(key)
			else
				name = string.format("%s[%s]", tostring(key), tostring(name))
			end
		end
		if type(value) == "table" then
			table.insert(query, url.build_query(value, sep, name))
		else
			local value = url.encode(tostring(value), url.options.legalInQuery)
			if value ~= "" then
				table.insert(query, string.format("%s=%s", name, value))
			else
				table.insert(query, name)
			end
		end
	end
	return table.concat(query, sep)
end

---#DES 'url.query_equals'
--- compares two url queries
---@param query1 UrlQuery
---@param query2 UrlQuery|string
---@return boolean
function url.query_equals(query1, query2)
	if type(query2) == "string" then
		query2 = url.parse_query(query2)
	end

	return url.build_query(query1) == url.build_query(query2)
end

---#DES 'url.add_query'
--- adds values to url query,
--- replaces existing values
---@param queryObj UrlQuery
---@param query UrlQuery|string
---@return UrlQuery
function url.add_query(queryObj, query)
	if type(query) == "string" then
		query = url.parse_query(query)
	end
	for k, v in pairs(query) do
		queryObj[k] = v
	end
	return queryObj
end

---parses url query
---@param str string
---@param sep? string
---@return UrlQuery
function url.parse_query(str, sep)
	sep = sep or url.options.separator or "&"

	local values = {}
	for key, val in str:gmatch(string.format("([^%q=]+)(=*[^%q=]*)", sep, sep)) do
		key = decodeValue(key)
		local keys = {}
		key = key:gsub("%[([^%]]*)%]", function (v)
			-- extract keys between balanced brackets
			if string.find(v, "^-?%d+$") then
				v = tonumber(v)
			else
				v = decodeValue(v)
			end
			table.insert(keys, v)
			return "="
		end)
		key = key:gsub("=+.*$", "")
		key = key:gsub("%s", "_") -- remove spaces in parameter name
		val = val:gsub("^=+", "")

		if not values[key] then
			values[key] = {}
		end

		if #keys > 0 and type(values[key]) ~= "table" then
			values[key] = {}
		elseif #keys == 0 and type(values[key]) == "table" then
			values[key] = decodeValue(val)
		elseif url.options.cumulativeParameters
		and    type(values[key]) == "string" then
			values[key] = { values[key] }
			table.insert(values[key], decodeValue(val))
		end

		local t = values[key]
		for i, k in ipairs(keys) do
			if type(t) ~= "table" then
				t = {}
			end
			if k == "" then
				k = #t + 1
			end
			if not t[k] then
				t[k] = {}
			end
			if i == #keys then
				t[k] = val
			end
			t = t[k]
		end
	end
	setmetatable(values, url.__QUERY_METATABLE)
	return values
end

---adds query to url table
---@param urlObj Url
---@param query table<string | number, string | number | boolean> | string
function url.set_query(urlObj, query)
	if type(query) == "table" then
		query = url.build_query(query)
	end
	urlObj.query = url.parse_query(query)
end

---#DES 'url.add_segment'	
---
---@param urlObj table
---@param path string
---@return Url
function url.add_segment(urlObj, path, legalInPath)
	if type(path) == "string" then
		urlObj.path = urlObj.path ..
			"/" .. url.encode(path:gsub("^/+", ""), type(legalInPath) == "table" and legalInPath or url.options.legalInPath)
	end
	return urlObj
end

---#DES 'url.equals'
---
---@param urlObj1 Url|string
---@param urlObj2 Url|string
function url.equals(urlObj1, urlObj2)
	if type(urlObj1) == "string" then
		urlObj1 = url.parse(urlObj1)
	end
	if type(urlObj2) == "string" then
		urlObj2 = url.parse(urlObj2)
	end
	return url.build(urlObj1) == url.build(urlObj2)
end

---#DES 'url.extract_ip'
---
---@param str any
---@return string?, string
function url.validate_ip(str)
	local chunks_ipv4 = { str:match"^(%d+)%.(%d+)%.(%d+)%.(%d+)$" }
	if #chunks_ipv4 == 4 then
		for _, v in pairs(chunks_ipv4) do
			if tonumber(v) > 255 then
				return nil, "invalid IPv4 address"
			end
		end
		return str, "ipv4"
	end

	local ipv6 = str:match"^%[(.-)%]$"
	if ipv6 then
		local segments = {}
		for segment in ipv6:gmatch"([^:]+)" do
			table.insert(segments, segment)
		end

		local _, emptySegmentCount = string.gsub(str, "::", "::")
		if emptySegmentCount > 1 then
			return nil, "invalid IPv6 address"
		end

		for _, segment in ipairs(segments) do
			-- Check for embedded IPv4 address
			local ipv4_octets = { segment:match"(%d+)%.(%d+)%.(%d+)%.(%d+)" }
			if #ipv4_octets == 4 then
				-- Validate each IPv4 octet
				for _, octet in ipairs(ipv4_octets) do
					if tonumber(octet) > 255 then
						return nil, "invalid embedded IPv4 address"
					end
				end
			else
				-- Validate IPv6 segment
				if #segment > 0 and (tonumber(segment, 16) > 65535 or tonumber(segment, 16) == nil) then
					return nil, "invalid IPv6 address"
				end
			end
		end

		return ipv6, "ipv6"
	end

	return nil, "not-ip"
end

--- extracts authority components for http request
--- returns scheme, host, port, path + query + fragment, credentials
---@param authorityStr string
---@return string, string, string
local function extract_authority_components(authorityStr)
	local host, port, credentials
	local authorityStr = tostring(authorityStr or "")
	authorityStr = authorityStr:gsub(":(%d+)$", function (v)
		port = tonumber(v)
		return ""
	end)
	authorityStr = authorityStr:gsub("^([^@]*)@", function (v)
		credentials = v
		return ""
	end)
	host = authorityStr
	return host, port, credentials
end

---#DES 'url.set_authority'	
---
---@param urlObj table
---@param authority string
---@return Url, string?
function url.set_authority(urlObj, authority)
	if type(authority) ~= "string" then return urlObj, "invalid authority" end
	urlObj.__authority = authority
	urlObj.host = nil
	urlObj.port = nil
	urlObj.username = nil
	urlObj.password = nil

	local hostInfo, port, userinfo = extract_authority_components(authority)
	urlObj.port = port

	local ip, kind = url.validate_ip(hostInfo)
	urlObj.kind = kind
	if ip then
		urlObj.host = ip
	elseif kind == "not-ip" then
		if hostInfo ~= "" and not urlObj.host then
			local host = hostInfo:lower()
			if string.match(host, "^[%d%a%-%.]+$") ~= nil and
			string.sub(host, 0, 1) ~= "." and
			string.sub(host, -1) ~= "." and
			string.find(host, "%.%.") == nil then
				urlObj.host = host
			end
			urlObj.kind = "domain"
		else
			urlObj.kind = "invalid"
		end
	end

	if userinfo then
		userinfo = userinfo:gsub(":([^:]*)$", function (v)
			urlObj.password = v
			return ""
		end)
		if string.find(userinfo, "^[%w%+%.]+$") then
			urlObj.username = userinfo
		else
			-- incorrect userinfo
			urlObj.username = nil
			urlObj.password = nil
		end
	end

	return urlObj
end

---#DES 'url.clone'	
---
---@param urlObj Url
---@return Url
function url.clone(urlObj)
	return util.clone(urlObj, true)
end

---#DES 'url.build'	
---
---@param urlObj Url
---@return string
function url.build(urlObj)
	local result = ""

	result = result .. tostring(urlObj.path or "")
	local queryStr = url.build_query(urlObj.query) or ""
	result = result .. (queryStr ~= "" and "?" .. queryStr or "")
	if urlObj.host then
		local authority = urlObj.host
		if urlObj.kind == "ipv6" then
			authority = "[" .. authority .. "]" -- IPv6
		end
		if urlObj.port and urlObj.port ~= url.services[urlObj.scheme] then
			authority = authority .. ":" .. urlObj.port
		end
		if urlObj.username and urlObj.username ~= "" then
			authority = urlObj.username .. (urlObj.password and ":" .. urlObj.password or "") .. "@" .. authority
		end
		if authority and authority ~= "" then
			result = "//" .. authority .. (result ~= "" and "/" .. result:gsub("^/+", "") or "")
		end
	end
	result = (urlObj.scheme and urlObj.scheme .. ":" or "") .. result
	result = result .. (urlObj.fragment and "#" .. urlObj.fragment or "")
	return result
end

---extracts url components
---returns scheme, authority, path, query, fragment
---@param urlStr string
---@return string, string, string, string, string
local function extract_url_components(urlStr)
	local scheme, authority, path, query, fragment
	local urlStr = tostring(urlStr or "")
	urlStr = urlStr:gsub("#(.*)$", function (v)
		fragment = v
		return ""
	end)
	urlStr = urlStr:gsub("^([%w][%w%+%-%.]*)%:", function (v)
		scheme = v:lower()
		return ""
	end)
	urlStr = urlStr:gsub("%?(.*)", function (v)
		query = v
		return ""
	end)
	urlStr = urlStr:gsub("^//([^/]*)", function (v)
		authority = v
		return ""
	end)
	path = urlStr

	return scheme, authority, path, query, fragment
end

---parses url string
---@param urlStr string
---@return Url
function url.parse(urlStr)
	local result = {}
	result.query = url.parse_query""

	local scheme, authority, path, query, fragment = extract_url_components(urlStr)
	result.fragment = fragment
	result.scheme = scheme
	if query ~= nil then
		url.set_query(result, query)
	end
	if authority ~= nil then
		url.set_authority(result, authority)
	end
	if path ~= nil then
		result.path = path:gsub("([^/]+)", function (s)
			return url.encode(url.decode(s), url.options.legalInPath)
		end)
	end

	setmetatable(result, url.__URL_METATABLE)
	return result
end

---#DES 'url.remove_dot_segments'
---
---@param path string
---@return string
function url.remove_dot_segments(path)
	local fields = {}
	if string.len(path) == 0 then
		return ""
	end
	local startslash = false
	local endslash = false
	if string.sub(path, 1, 1) == "/" then
		startslash = true
	end
	if (string.len(path) > 1 or startslash == false) and string.sub(path, -1) == "/" then
		endslash = true
	end

	for c in path:gmatch"[^/]+" do
		table.insert(fields, c)
	end

	local new = {}
	local j = 0

	for _, c in ipairs(fields) do
		if c == ".." then
			if j > 0 then
				j = j - 1
			end
		elseif c ~= "." then
			j = j + 1
			new[j] = c
		end
	end
	local ret = ""
	if #new > 0 and j > 0 then
		ret = table.concat(new, "/", 1, j)
	else
		ret = ""
	end
	if startslash then
		ret = "/" .. ret
	end
	if endslash then
		ret = ret .. "/"
	end
	return ret
end

local function reduce_path(basePath, relativePath)
	if string.sub(relativePath, 1, 1) == "/" then
		return "/" .. string.gsub(relativePath, "^[%./]+", "")
	end
	local path = basePath
	local startslash = string.sub(path, 1, 1) ~= "/";
	if relativePath ~= "" then
		path = (startslash and "" or "/") .. path:gsub("[^/]*$", "")
	end
	path = path .. relativePath
	path = path:gsub("([^/]*%./)", function (s)
		if s ~= "./" then return s else return "" end
	end)
	path = string.gsub(path, "/%.$", "/")
	local reduced
	while reduced ~= path do
		reduced = path
		path = string.gsub(reduced, "([^/]*/%.%./)", function (s)
			if s ~= "../../" then return "" else return s end
		end)
	end
	path = string.gsub(path, "([^/]*/%.%.?)$", function (s)
		if s ~= "../.." then return "" else return s end
	end)
	local reduced
	while reduced ~= path do
		reduced = path
		path = string.gsub(reduced, "^/?%.%./", "")
	end
	return (startslash and "" or "/") .. path
end

---#DES 'url.resolve'
--- builds a new url by using the one given as parameter and resolving paths
---@param base Url|string
---@param other Url|string
---@return Url
function url.resolve(base, other)
	if type(base) == "string" then
		base = url.parse(base)
	end
	if type(other) == "string" then
		other = url.parse(other)
	end
	if other.scheme then
		return other
	else
		other.scheme = base.scheme
		if not other.__authority or other.__authority == "" then
			url.set_authority(other, base.__authority)
			if not other.path or other.path == "" then
				other.path = base.path
				local query = other.query
				if not query or not next(query) then
					other.query = base.query
				end
			else
				other.path = reduce_path(base.path, other.path)
			end
		end
		return other
	end
end

---#DES 'url.normalize'
--- normalize a url path following some common normalization rules
--- described on <a href="http://en.wikipedia.org/wiki/URL_normalization">The URL normalization page of Wikipedia</a>
---@param urlObj Url|string
--- @return Url
function url.normalize(urlObj)
	if type(urlObj) == "string" then
		urlObj = url.parse(urlObj)
	end
	if urlObj.path then
		local path = urlObj.path
		path = reduce_path(path, "")
		-- normalize multiple slashes
		path = string.gsub(path, "//+", "/")
		urlObj.path = path
	end
	return urlObj
end

---#DES 'url.to_request_parameters'
--- returns scheme, host, port, path + query + fragment, credentials
---@param urlObjOrStr Url | string
---@return string?, string?, string?, string?, string?
function url.extract_components_for_request(urlObjOrStr)
	if type(urlObjOrStr) == "string" then
		local scheme, authority, path, query, fragment = extract_url_components(urlObjOrStr)
		local host, port, credentials = extract_authority_components(authority)
		return scheme, host, port, (path or "") .. (query and "?" .. query or "") .. (fragment and "#" .. fragment or ""),
			credentials
	end
	local urlObj = urlObjOrStr
	local scheme = urlObj.scheme
	local host = urlObj.host
	local port = urlObj.port
	local credentials = urlObj.username and urlObj.username .. (urlObj.password and ":" .. urlObj.password or "") or nil

	local pathQueryFragment = tostring(urlObj.path or "")
	local queryStr = url.build_query(urlObj.query) or ""
	pathQueryFragment = pathQueryFragment .. (queryStr ~= "" and "?" .. queryStr or "")
	pathQueryFragment = pathQueryFragment .. (urlObj.fragment and "#" .. urlObj.fragment or "")

	return scheme, host, port, pathQueryFragment, credentials
end

url.__URL_METATABLE = {
	__index = {
		build = url.build,
		normalize = url.normalize,
		add_segment = url.add_segment,
		set_authority = url.set_authority,
		set_query = url.set_query,
		resolve = url.resolve,
		to_http_request_components = url.extract_http_request_components,
	},
	__tostring = url.build,
	__div = url.add_segment,
	__eq = url.equals,
}

url.__QUERY_METATABLE = {
	__tostring = url.build_query,
	__type = "ELI_URL_QUERY",
	__band = url.add_query,
}

return url
