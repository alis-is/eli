local corehttpLoaded, corehttp = pcall(require, "corehttp")
local io = require"io"
local util = require"eli.util"
local hjson = require"hjson"
local exTable = require"eli.extensions.table"
local netUrl = require"eli.net.url"
local zlib = require"zlib"
local base64 = require"base64"

local MINIMUM_BUFFER_CAPACITY = 1024
local MINIMUM_HEADERS_BUFFER_CAPACITY = 1024
local DEFAULT_BUFFER_CAPACITY = 16 * 1024
local MAXIMUM_BUFFER_CAPACITY = 1024 * 1024
local net = {
	---#DES 'CURL_AVAILABLE'
	---@type boolean
	ENET = corehttpLoaded,
	corehttp = corehttp,
}

net.set_default_buffer_capacity = function (capacity)
	if type(capacity) ~= "number" then return end
	if capacity < MINIMUM_BUFFER_CAPACITY then
		capacity = MINIMUM_BUFFER_CAPACITY
	elseif capacity > MAXIMUM_BUFFER_CAPACITY then
		capacity = MAXIMUM_BUFFER_CAPACITY
	else
		DEFAULT_BUFFER_CAPACITY = capacity
	end
end

if not corehttpLoaded then
	return net
end

---@class CorehttpClient
---@field endpoint fun(self: CorehttpClient): string
---@field request fun(self: CorehttpClient,  path: string, method: string, options: BaseRequestOptions): BaseResponse

---@class ClientCertificate
---@field certificate string
---@field key string
---@field password string?

---@class BaseRequestOptions
---@field retryLimit integer?
---@field followRedirects boolean?
---@field verifyPeer boolean?
---@field timeout integer? @deprecated use connectTimeout
---@field connectTimeout integer? timeout to wait (ms) for server response, 0 means no timeout, default 5 minuts
---@field readTimeout integer? timeout to wait (ms) for bytes to arrive on sockets during recv, 0 means no timeout, default 0
---@field writeTimeout integer? timeout to wait (ms) for bytes to be sent on sockets during send, 0 means no timeout, default 0
---@field contentType string? @deprecated use headers
---@field ignoreHttpErrors boolean? @deprecated not relevant anymore, errors are ignored by default
---@field progressFunction (fun(total?: number, current: number))? @deprecated use progress_function
---@field progress_function (fun(total?: number, current: number))?
---@field showDefaultProgress boolean|number? respected only if progressFunction not defined
---@field bufferCapacity number? @default 16K (16 * 1024)
---@field drbgSeed string?
---@field useBundledRootCertificates boolean?
---@field caCertificates table<string>?
---@field clientCertificate ClientCertificate?
---@field responseBufferCapacity number? @default 16K (16 * 1024)
---@field credentials { username: string, password: string }?

---@class MimeCodec
---@field encode fun(data: any): string
---@field decode fun(data: string): any

---@class RequestOptions: BaseRequestOptions
---@field write_function fun(data: string)?
---@field headers table<string, string>?
---@field codecs table<string, MimeCodec>

---@alias HTTPMethodKind '"GET"'|'"HEAD"'|'"POST"'|'"PUT"'|'"DELETE"'|'"CONNECT"'|'"OPTIONS"'|'"TRACE"'|'"PATH"'

---@class BaseResponse
---@field code number
---@field data any
---@field raw string
---@field headers table<string, string>
---@field http_status_code fun(self: BaseResponse): integer
---@field status_code fun(self: BaseResponse): integer
---@field status fun(self: BaseResponse): string
---@field read fun(self: BaseResponse, size: number): string

---@class RequestData
---@field read fun(self: any, size: number): string
---@field seek (fun(self: any, whence: string, offset: number): number|nil, string?)?

---@class RestClientOptions: RequestOptions
---@field shortcut boolean?
---@field params (table<string,string>|string[])?
---@field data string?

---@class RestClient
---@field __type '"ELI_REST_CLIENT"'
---@field __parent nil|RestClient
---@field __is_child boolean
---@field __id nil|string
---@field __options RestClientOptions
---@field __url string
---@field __shortcuts table<string, RestClient>
---@field __client CorehttpClient -- // TODO: proper typing
net.RestClient = {}
net.RestClient.__index = net.RestClient

local DEFAULT_HEADERS = {
	["Accept"] = "application/json",
	["Accept-Encoding"] = "gzip, deflate, identity",
	["Cache-Control"] = "no-cache",
	["Pragma"] = "no-cache",
}

local function unwrap_safe_result(...)
	local result = table.pack(...)
	local msg, code = util.extract_error_info(result[2])
	if not result[1] then
		return result[1], msg, code
	end
	return table.unpack(result)
end

local function encodeURIComponent(url)
	if url == nil then return end
	url = url:gsub("\n", "\r\n")
	url = url:gsub("([^%w _%%%-%.~])", function (c)
		return string.format("%%%02X", string.byte(c))
	end)
	url = url:gsub(" ", "+")
	return url
end

---generates progress function
---@param step number
---@return function
local function generate_progress_function(step)
	local writtenSteps = 0
	if type(step) ~= "number" then step = 10 end
	return function (total, current)
		local progress = math.floor(current / total * 100)
		if progress >= writtenSteps * step then
			writtenSteps = writtenSteps + 1
			if progress == 100 then
				io.write"100%\n"
			else
				io.write(math.floor(progress / step) * step .. "%...")
			end
			io.flush()
		end
	end
end

local function parse_content_type(headerValue)
	-- Initially match for both MIME type and charset
	local type, subtype, charset = string.match(headerValue, "(%w+)/(%w+);%s*charset=(%w+)")

	-- If charset is missing, match only for MIME type
	if not charset then
		type, subtype = string.match(headerValue, "(%w+)/(%w+)")
	end

	return type, subtype, charset
end

---checks if client is targeting same authority as url
---@param client CorehttpClient
---@param url Url | string
local function is_client_targeting_same_authority(client, url)
	local scheme, host, port, _, _ = netUrl.extract_components_for_request(url)
	local clientScheme, clientHost, clientPort, _, _ = netUrl.extract_components_for_request(client:endpoint())
	return scheme == clientScheme and host == clientHost and port == clientPort
end

-- // TODO: port to C
---@param response BaseResponse
---@param options RequestOptions
---@param progress_function (fun(total?: number, current: number))?
---@return string
local function read_content(response, options, progress_function)
	local rawResponseData = ""

	local responseHeaders = response:headers()
	local contentLength = responseHeaders["Content-Length"] and tonumber(responseHeaders["Content-Length"])
	local contentEncoding = responseHeaders["Content-Encoding"]

	local totalBytesRead = 0
	local inflate = (contentEncoding == "deflate" or contentEncoding == "gzip") and zlib.inflate() or false
	local inflateCache = ""

	while true do
		local bufferCapacity = math.min(options.bufferCapacity or DEFAULT_BUFFER_CAPACITY, contentLength - totalBytesRead)
		local chunk = response:read(bufferCapacity)
		if not chunk or type(chunk) ~= "string" then
			if contentLength > 0 and totalBytesRead ~= contentLength then
				error("expected " .. contentLength .. " bytes, got " .. totalBytesRead)
			end
			break
		end
		totalBytesRead = totalBytesRead + #chunk
		if type(progress_function) == "function" then
			progress_function(contentLength, totalBytesRead)
		end
		if inflate then
			inflateCache = inflateCache .. chunk
			local bytes_in
			chunk, _, bytes_in = inflate(inflateCache)
			inflateCache = inflateCache:sub(bytes_in + 1) -- remove inflated part
		end
		if type(options.write_function) == "function" then
			options.write_function(chunk)
		else
			rawResponseData = rawResponseData .. chunk
		end
		if totalBytesRead == contentLength then break end
	end
	return rawResponseData
end

-- // TODO: port to C
local function read_chunked_content(response, options)
	local rawResponseData = ""

	local responseHeaders = response:headers()
	local contentEncoding = responseHeaders["Content-Encoding"]

	local inflate = (contentEncoding == "deflate" or contentEncoding == "gzip") and zlib.inflate() or false
	local inflateCache = ""

	local dataCache = ""
	---@type integer|nil
	local expectedChunkSize
	local availableDataSize = 0

	while true do
		-- we always need either chunk size and 5 bytes for next chunk size or at least 3 bytes for chunk header
		local bytesNeeded = expectedChunkSize and (expectedChunkSize - availableDataSize) + 5 or 3
		if bytesNeeded == 3 and availableDataSize > 1 then
			bytesNeeded = dataCache:sub(-1) == "\r" and 1 or 2 -- we need only 1 or 2 bytes to close chunk header
		end
		local bufferCapacity = math.min(options.bufferCapacity or DEFAULT_BUFFER_CAPACITY, bytesNeeded)

		local data, dataLen = response:read(bufferCapacity)
		if not data or type(data) ~= "string" then
			error(string.interpolate("cannot retreive data: ${error}", { error = dataLen }))
		end
		dataCache = dataCache .. data
		availableDataSize = availableDataSize + dataLen

		while true do
			if expectedChunkSize == nil then
				local _, _end = dataCache:find("\r\n", 1, true)
				if _end == 2 then
					_, _end = dataCache:find("\r\n", 3, true) -- skip \r\n
				end
				if not _end then break end         -- Not enough data to determine chunk size

				expectedChunkSize = tonumber(dataCache:sub(1, _end), 16)
				if expectedChunkSize == 0 then return rawResponseData end -- Last chunk
				dataCache = dataCache:sub(_end + 1)
				availableDataSize = availableDataSize - _end
			end

			if availableDataSize < expectedChunkSize then
				break -- Not enough data to read the full chunk
			end

			local chunk = dataCache:sub(1, expectedChunkSize)
			dataCache = dataCache:sub(expectedChunkSize + 1)
			availableDataSize = availableDataSize - expectedChunkSize
			expectedChunkSize = nil

			if inflate then
				inflateCache = inflateCache .. chunk
				local bytes_in
				chunk, _, bytes_in, _ = inflate(inflateCache)
				inflateCache = inflateCache:sub(bytes_in + 1) -- remove inflated part
			end

			if type(options.write_function) == "function" then
				options.write_function(chunk)
			else
				rawResponseData = rawResponseData .. chunk
			end
		end
	end
end

---Performs request
---@param client CorehttpClient
---@param path any
---@param method any
---@param options RequestOptions
---@param data (string | RequestData)?
local function request(client, path, method, options, data)
	if type(options) ~= "table" then options = { codecs = {} } end
	if type(options.headers) ~= "table" then options.headers = {} end
	if type(options.codecs) ~= "table" then options.codecs = {} end

	local requestOptions = {}
	local headers = setmetatable(options.headers or {}, corehttp.HEADERS_METATABLE)

	-- options
	requestOptions.verifyPeer = options.verifyPeer == nil and true or options.verifyPeer
	requestOptions.connectTimeout = options.connectTimeout or options.timeout
	requestOptions.readTimeout = options.readTimeout
	requestOptions.writeTimeout = options.writeTimeout
	requestOptions.drbgSeed = type(options.drbgSeed) == "string" or options.drbgSeed or "eli.net"
	requestOptions.useBundledRootCertificates = type(options.useBundledRootCertificates) == "boolean" or
		options.useBundledRootCertificates or true
	requestOptions.caCertificates = options.caCertificates
	requestOptions.clientCertificate = options.clientCertificate
	requestOptions.headers = headers
	requestOptions.bufferSize = math.max(
		math.min(options.bufferCapacity or DEFAULT_BUFFER_CAPACITY, MAXIMUM_BUFFER_CAPACITY),
		MINIMUM_HEADERS_BUFFER_CAPACITY)

	if options.credentials then
		local encoded = base64.encode(tostring(options.credentials.username) ..
			":" .. tostring(options.credentials.password))
		headers["Authorization"] = "Basic " .. encoded
	end

	-- progress function
	local progress_function = nil
	if options.showDefaultProgress == true or (type(options.showDefaultProgress) == "number" and options.showDefaultProgress > 0) then
		local step = type(options.showDefaultProgress) == "boolean" and 10 or options
			.showDefaultProgress --[[@as number]]
		if type(options.progressFunction) == "function" then
			progress_function = options.progressFunction
		elseif type(step) == "number" and step > 0 then
			progress_function = generate_progress_function(step)
		end
	end

	if type(data) ~= "nil" then
		if type(data.read) == "function" then
			if not headers["Content-Length"] and headers["Transfer-Encoding"] ~= "chunked" then
				local errMsg = "can not determine size of data"
				if type(data.seek) == "function" then
					local currentPos = data:seek("cur", 0)
					if currentPos == nil then
						error(errMsg)
					end
					local size = data:seek("end", 0)
					data:seek("set", currentPos)
					headers["Content-Length"] = tostring(size - currentPos)
				else
					error(errMsg)
				end
			end

			requestOptions.write_body_hook = function (context)
				while true do
					local chunk = data.read(data, options.bufferCapacity or DEFAULT_BUFFER_CAPACITY)
					if not chunk then break end
					context:write(chunk)
				end
			end
		else
			-- //TODO: remove contentType
			headers["Content-Type"] = options.contentType or headers["Content-Type"] or "application/json"
			local codec = options.codecs[headers["Content-Type"]]
			if codec and type(codec.encode) == "function" then
				requestOptions.body = codec.encode(data)
			end
		end
	end

	--- options contains 'headers' table and 'body' string
	local response, errMsg, errCode = client:request(path, method, requestOptions)
	if not response then
		error(tostring(errMsg) .. " (" .. tostring(errCode) .. ")")
	end

	local responseHeaders = response:headers()
	if options.followRedirects and exTable.includes({ 301, 302, 303, 307, 308 }, response:http_status_code()) then
		local location = responseHeaders["Location"]
		if location then
			-- we don't want to decode url values as they might be encoded secrets, we trust server to send us valid url
			if not is_client_targeting_same_authority(client, location) then
				local newScheme, newHost, newPort, newPath, _ = netUrl.extract_components_for_request(location)
				local newClient = corehttp.new_client(newScheme, newHost, newPort, options)
				return request(newClient, newPath, method, options, data)
			else
				return request(client, location, method, options, data)
			end
		end
	end

	local rawResponseData
	local isChunkedEncoding = responseHeaders["Transfer-Encoding"] == "chunked"
	local isEventStream = responseHeaders["Content-Type"] == "text/event-stream"

	if isChunkedEncoding then
		rawResponseData = read_chunked_content(response, options)
	elseif isEventStream then
		error"event stream not supported yet"
	else
		rawResponseData = read_content(response, options, progress_function)
	end

	local responseData = nil
	if type(rawResponseData) == "string" and #rawResponseData > 0 then
		local mimeType, subtype, _ = parse_content_type(responseHeaders["Content-Type"])
		local typeCodec = options.codecs[type] or options.codecs[mimeType .. "/" .. subtype]
		if typeCodec and type(typeCodec.decode) == "function" then
			responseData = typeCodec.decode(rawResponseData)
		end
	end

	local coreStatusCode = response:status_code()
	if coreStatusCode ~= 0 then
		error(tostring(response:status()) .. " (" .. tostring(coreStatusCode) .. ")")
	end

	local result = {
		code = response:http_status_code(),
		data = responseData,
		raw = rawResponseData,
		headers = responseHeaders,
	}
	setmetatable(result, {
		__type = "ELI_REST_CLIENT_RESPONSE",
		__tostring = function () return "ELI_REST_CLIENT_RESPONSE" end,
	})
	return result
end

---#DES 'net.RestClient:new'
---
---@param self RestClient
---@param urlOrId string
---@param parentOrOptions (RestClient|RestClientOptions)?
---@param options RestClientOptions?
---@return RestClient
function net.RestClient:new(urlOrId, parentOrOptions, options)
	local _restClient = {
		host = nil,
		__resources = {},
		__shortcuts = {},
		__is_child = false,
		__parent = nil,
		__id = nil,
	}

	if options == nil then options = {} end

	if tostring(parentOrOptions):match"ELI_REST_CLIENT" then
		local _parent = parentOrOptions --[[@as RestClient]]
		_restClient.__is_child = true
		_restClient.__parent = _parent
		_restClient.__id = urlOrId
		_restClient.__options = util.merge_tables(options, util.clone(
			_parent.__options))
		_restClient.__client = _parent.__client
	else
		options = parentOrOptions --[[@as RestClientOptions]]
		_restClient.__url = netUrl.parse(urlOrId)
		local scheme, host, port, _, _ = netUrl.extract_components_for_request(_restClient.__url)
		_restClient.__client = corehttp.new_client(scheme, host, port, options)
		_restClient.__options = util.merge_tables(options, {
			followRedirects = false,
			verifyPeer = true,
			trailing = "",
			shortcut = true,
			shortcutRules = {},
			headers = util.clone(DEFAULT_HEADERS, true),
			codecs = {
				["application/x-www-form-urlencoded"] = {
					encode = encodeURIComponent,
				},
				["text/plain"] = { encode = tostring },
				["application/json"] = {
					encode = function (v)
						return hjson.stringify_to_json(v, {
							invalidObjectsAsType = true,
							indent = false,
						})
					end,
					decode = hjson.parse,
				},
			},
		})
	end

	setmetatable(_restClient, self)
	self.__type = "ELI_REST_CLIENT"
	self.__index = function (t, k)
		local _result = rawget(self, k)
		if _result == nil and type(k) == "string" and not k:match"^__.*" then
			return net.RestClient:new(k, _restClient)
		end
		return _result
	end
	return _restClient
end

---#DES 'net.RestClient:__tostring'
---
---@param self RestClient
---@return string
function net.RestClient:__tostring()
	return "ELI_REST_CLIENT " ..
		(tostring(self.__url) or self.__id or "unknown host or id")
end

---#DES 'net.RestClient:get_url'
---
---@param self RestClient
---@return Url
function net.RestClient:get_url()
	if not self.__is_child then return util.clone(self.__url, true, false) --[[@as Url]] end
	local url = util.clone(self.__parent:get_url(), true, false) --[[@as Url]]
	local legalInPath = util.merge_tables(netUrl.options.legalInPath, { ["/"] = true }) -- we want to keep / in path for resources
	if type(self.__id) == "string" then netUrl.add_segment(url, self.__id, legalInPath) end

	return url:normalize()
end

---#DES 'net.RestClient:get_headers'
---
---@param self RestClient
---@return Url
function net.RestClient:get_headers()
	return setmetatable(util.clone(self.__options.headers, true) --[[@as table]], corehttp.HEADERS_METATABLE)
end

---#DES 'net.RestClient:conf'
---
--- configures RestClient
---@param self RestClient
---@param options RestClientOptions
---@return RestClientOptions
function net.RestClient:conf(options)
	if options == nil then return self.__options end
	self.__options = util.merge_tables(options, self.__options)
	return self.__options
end

---@class ResourceCreationOptions: RestClientOptions
---@field allowRestclientPropertyOverride boolean?
---@field shortcutRules fun(name: string, path: string): string

---#DES 'net.RestClient:res'
---
--- creates resource
---@overload fun(self: RestClient, resources: string, options: ResourceCreationOptions?):RestClient?
---@overload fun(self: RestClient, resources: string[], options: ResourceCreationOptions?):RestClient[]?
---@overload fun(self: RestClient, resources: {k:string, v:string}, options: ResourceCreationOptions?):{k:string, v:RestClient}?
function net.RestClient:res(resources, options)
	if options == nil then options = {} end
	local _shortcut = options.shortcut
	if _shortcut == nil then _shortcut = self.__options.shortcut end

	---creates resource
	---@param name string|number
	---@param path string|number
	---@return RestClient
	local function makeResource(name, path)
		if type(self.__resources) ~= "table" then self.__resources = {} end
		if self.__resources[path] then return self.__resources[path] end

		local _result = net.RestClient:new(tostring(path), self)
		self.__resources[path] = _result
		if _shortcut then
			self.__shortcuts[name] = _result
			self[name] = _result
			for _, rule in ipairs(exTable.get(self,
				{ "__options", "shortcutRules" },
				{})) do
				if type(rule) == "function" then
					local _customShortcut = rule(name, path);
					if type(_customShortcut) == "string" then
						self.__shortcuts[_customShortcut] = _result
						self[_customShortcut] = _result
					end
				end
			end
		end
		return _result
	end

	if type(resources) == "string" or type(resources) == "number" then
		return makeResource(resources, resources)
	end

	if util.is_array(resources) then
		local _validForResource = exTable.filter(resources, function (_, v)
			return type(v) == "string" or type(resources) == "number"
		end)
		return exTable.map(_validForResource, function (v, i) return makeResource(i, v) end)
	end

	if type(resources) == "table" then
		local _result = {}
		for k, v in pairs(resources) do
			local _resources
			if type(v) == "table" then
				local _parent = makeResource(k, v.__root or k)
				local _options = util.clone(options, true)
				_options.shortcut = true
				_parent:res(exTable.filter(v, function (k) return k ~= "__root" end), _options)
				_resources = _parent
			elseif type(v) == "number" or type(v) == "string" then
				_resources = makeResource(k, v)
			end
			_result[k] = _resources
		end
		return _result
	end
end

---#DES 'net.RestClient:safe_res'
---
--- creates resource
---@overload fun(self: RestClient, resources: string, options: RestClientOptions?):boolean, RestClient?
---@overload fun(self: RestClient, resources: string[], options: RestClientOptions?):boolean, RestClient[]?
---@overload fun(self: RestClient, resources: {k:string, v:string}, options: RestClientOptions?):boolean, {k:string, v:RestClient}?
function net.RestClient:safe_res(resources, options)
	return unwrap_safe_result(pcall(self.res, self, resources, options))
end

---Resolves request url and options
---@param client RestClient
---@param pathOrOptions (RestClientOptions | string)?
---@param options RestClientOptions?
---@return Url, RestClientOptions
local function get_request_url(client, pathOrOptions, options)
	local path = ""
	if type(pathOrOptions) == "table" then
		options = pathOrOptions
	elseif type(pathOrOptions) == "string" then
		path = pathOrOptions
	end

	if type(options) ~= "table" then options = {} end

	local url = client:get_url()
	if #path > 0 then
		url = netUrl.add_path(url, path)
	end
	if type(options.params) == "table" then
		local query = {}
		if util.is_array(options.params) and #options.params > 1 then
			-- split params into key-value pairs, they are stored as k=v
			for _, v in ipairs(options.params) do
				local partialQuery = netUrl.parse_query(v)
				query = util.merge_tables(query, partialQuery, true)
			end
		else
			query = util.merge_tables(query, options.params, true)
		end

		netUrl.set_query(url, query) -- cleans up and validates query
	end
	return url:normalize(), options
end

---#DES 'net.RestClient:get'
---
---@param self RestClient
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:get(pathOrOptions, options)
	local url, options = get_request_url(self, pathOrOptions,
		options)
	local _, _, _, path, _ = netUrl.extract_components_for_request(url)

	return request(self.__client, path, "GET", util.merge_tables(options, self.__options))
end

---#DES 'net.RestClient:safe_get'
---
---@param self RestClient
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_get(pathOrOptions, options)
	return unwrap_safe_result(pcall(self.get, self, pathOrOptions, options))
end

---#DES 'net.RestClient:post'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:post(data, pathOrOptions, options)
	local url, options = get_request_url(self, pathOrOptions,
		options)
	local _, _, _, path, _ = netUrl.extract_components_for_request(url)
	return request(self.__client, path, "POST", util.merge_tables(options, self.__options), data)
end

---#DES 'net.RestClient:safe_post'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_post(data, pathOrOptions, options)
	return unwrap_safe_result(pcall(self.post, self, data, pathOrOptions, options))
end

---#DES 'net.RestClient:put'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:put(data, pathOrOptions, options)
	local url, options = get_request_url(self, pathOrOptions,
		options)
	local _, _, _, path, _ = netUrl.extract_components_for_request(url)
	return request(self.__client, path, "PUT", util.merge_tables(options, self.__options), data)
end

---#DES 'net.RestClient:safe_put'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_put(data, pathOrOptions, options)
	return unwrap_safe_result(pcall(self.put, self, data, pathOrOptions, options))
end

---#DES 'net.RestClient:patch'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:patch(data, pathOrOptions, options)
	local url, options = get_request_url(self, pathOrOptions,
		options)
	local _, _, _, path, _ = netUrl.extract_components_for_request(url)
	return request(self.__client, path, "PATCH", util.merge_tables(options, self.__options), data)
end

---#DES 'net.RestClient:safe_patch'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_patch(data, pathOrOptions, options)
	return unwrap_safe_result(pcall(self.patch, self, data, pathOrOptions, options))
end

---#DES 'net.RestClient:delete'
---
---@param self RestClient
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:delete(pathOrOptions, options)
	local url, options = get_request_url(self, pathOrOptions,
		options)
	local _, _, _, path, _ = netUrl.extract_components_for_request(url)

	return request(self.__client, path, "DELETE", util.merge_tables(options, self.__options))
end

---#DES 'net.RestClient:safe_delete'
---
---@param self RestClient
---@param pathOrOptions (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_delete(pathOrOptions, options)
	return unwrap_safe_result(pcall(self.delete, self, pathOrOptions, options))
end

---Performs download operation. Data received are passed to write_function
---@param url string
---@param write_function (fun(data: string))?
---@param options BaseRequestOptions?
---@return BaseResponse
local function download(url, write_function, options)
	if type(options) ~= "table" then options = {} end

	local _client = net.RestClient:new(url, util.merge_tables(options, {
		timeout = options.timeout,
		write_function = write_function,
	}, true))

	return _client:get()
end

---gets retry limit either from request options or from ENV variable ELI_NET_RETRY_LIMIT
---@param options BaseRequestOptions?
---@return integer
local function get_retry_limit(options)
	local retryLimit = tonumber(os.getenv"ELI_NET_RETRY_LIMIT") or 0
	if type(options) == "table" then
		if type(options.retryLimit) == "number" and options.retryLimit > 0 then
			retryLimit = options.retryLimit
		end
	end
	return retryLimit --[[@as integer]]
end

---#DES net.download_file
---
--- Downloads file from url to destination
---@param url string
---@param destination string
---@param options BaseRequestOptions?
function net.download_file(url, destination, options)
	local tries = 0
	local retryLimit = get_retry_limit(options)

	while tries <= retryLimit do
		local didOpenFile, df <close> = pcall(io.open, destination, "wb")
		if not didOpenFile or df == nil then error(df) end
		local write = function (data) df:write(data) end

		local _ok, _response = pcall(download, url, write, options)
		if _ok then
			return _response.code
		elseif (tries >= retryLimit) then
			os.remove(destination)
			error(_response)
		end

		tries = tries + 1
	end
end

---#DES net.download_string
---
--- Downloads file from url to destination
---@param url string
---@param options BaseRequestOptions?
---@return string?, number?
function net.download_string(url, options)
	local tries = 0
	local retryLimit = get_retry_limit(options)

	while tries <= retryLimit do
		local result = ""
		local write = function (data) result = result .. data end

		local ok, response = pcall(download, url, write, options)
		if ok then
			return result, response.code
		elseif (tries >= retryLimit) then
			error(response)
		end
		tries = tries + 1
	end
end

return util.generate_safe_functions(net)
