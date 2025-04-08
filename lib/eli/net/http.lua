local is_corehttp_loaded, corehttp = pcall(require, "corehttp")
local io = require"io"
local util = require"eli.util"
local hjson = require"hjson"
local table_extensions = require"eli.extensions.table"
local net_url = require"eli.net.url"
local zlib = require"zlib"
local base64 = require"base64"

local MINIMUM_BUFFER_CAPACITY = 1024
local MINIMUM_HEADERS_BUFFER_CAPACITY = 1024
local DEFAULT_BUFFER_CAPACITY = 16 * 1024
local MAXIMUM_BUFFER_CAPACITY = 1024 * 1024
local net = {
	---#DES 'CURL_AVAILABLE'
	---@type boolean
	ENET = is_corehttp_loaded,
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

if not is_corehttp_loaded then
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
---@field retry_limit integer?
---@field follow_redirects boolean?
---@field verify_peer boolean?
---@field timeout integer? @deprecated use connect_timeout
---@field connect_timeout integer? timeout to wait (ms) for server response, 0 means no timeout, default 5 minuts
---@field read_timeout integer? timeout to wait (ms) for bytes to arrive on sockets during recv, 0 means no timeout, default 0
---@field write_timeout integer? timeout to wait (ms) for bytes to be sent on sockets during send, 0 means no timeout, default 0
---@field content_type string? @deprecated use headers
---@field progress_function (fun(total?: number, current: number))?
---@field show_default_progress boolean|number? respected only if progressFunction not defined
---@field buffer_capacity number? @default 16K (16 * 1024)
---@field drgb_seed string?
---@field use_bundled_root_certificates boolean?
---@field ca_certificates table<string>?
---@field client_certificate ClientCertificate?
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

local function encode_uri_component(url)
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
	local written_steps = 0
	if type(step) ~= "number" then step = 10 end
	return function (total, current)
		local progress = math.floor(current / total * 100)
		if progress >= written_steps * step then
			written_steps = written_steps + 1
			if progress == 100 then
				io.write"100%\n"
			else
				io.write(math.floor(progress / step) * step .. "%...")
			end
			io.flush()
		end
	end
end

local function parse_content_type(header_value)
	-- Initially match for both MIME type and charset
	local type, subtype, charset = string.match(header_value, "(%w+)/(%w+);%s*charset=(%w+)")

	-- If charset is missing, match only for MIME type
	if not charset then
		type, subtype = string.match(header_value, "(%w+)/(%w+)")
	end

	return type, subtype, charset
end

---checks if client is targeting same authority as url
---@param client CorehttpClient
---@param url Url | string
local function is_client_targeting_same_authority(client, url)
	local scheme, host, port, _, _ = net_url.extract_components_for_request(url)
	local client_scheme, client_host, client_port, _, _ = net_url.extract_components_for_request(client:endpoint())
	return scheme == client_scheme and host == client_host and port == client_port
end

-- // TODO: port to C
---@param response BaseResponse
---@param options RequestOptions
---@param progress_function (fun(total?: number, current: number))?
---@return string
local function read_content(response, options, progress_function)
	local raw_response_data = ""

	local response_headers = response:headers()
	local content_length = response_headers["Content-Length"] and tonumber(response_headers["Content-Length"])
	local content_encoding = response_headers["Content-Encoding"]

	local total_bytes_read = 0
	local inflate = (content_encoding == "deflate" or content_encoding == "gzip") and zlib.inflate() or false
	local inflate_cache = ""

	while true do
		local buffer_capacity = math.min(options.buffer_capacity or DEFAULT_BUFFER_CAPACITY,
			content_length - total_bytes_read)
		local chunk = response:read(buffer_capacity)
		if not chunk or type(chunk) ~= "string" then
			if content_length > 0 and total_bytes_read ~= content_length then
				error("expected " .. content_length .. " bytes, got " .. total_bytes_read)
			end
			break
		end
		total_bytes_read = total_bytes_read + #chunk
		if type(progress_function) == "function" then
			progress_function(content_length, total_bytes_read)
		end
		if inflate then
			inflate_cache = inflate_cache .. chunk
			local bytes_in
			chunk, _, bytes_in = inflate(inflate_cache)
			inflate_cache = inflate_cache:sub(bytes_in + 1) -- remove inflated part
		end
		if type(options.write_function) == "function" then
			options.write_function(chunk)
		else
			raw_response_data = raw_response_data .. chunk
		end
		if total_bytes_read == content_length then break end
	end
	return raw_response_data
end

-- // TODO: port to C
local function read_chunked_content(response, options)
	local raw_response_data = ""

	local response_headers = response:headers()
	local content_encoding = response_headers["Content-Encoding"]

	local inflate = (content_encoding == "deflate" or content_encoding == "gzip") and zlib.inflate() or false
	local inflate_cache = ""

	local data_cache = ""
	---@type integer|nil
	local expected_chunk_size
	local available_data_size = 0

	while true do
		-- we always need either chunk size and 5 bytes for next chunk size or at least 3 bytes for chunk header
		local bytes_needed = expected_chunk_size and (expected_chunk_size - available_data_size) + 5 or 3
		if bytes_needed == 3 and available_data_size > 1 then
			bytes_needed = data_cache:sub(-1) == "\r" and 1 or 2 -- we need only 1 or 2 bytes to close chunk header
		end
		local buffer_capacity = math.min(options.buffer_capacity or DEFAULT_BUFFER_CAPACITY, bytes_needed)

		local data, data_length_or_error = response:read(buffer_capacity)
		if not data or type(data) ~= "string" then
			error(string.interpolate("cannot retreive data: ${error}", { error = data_length_or_error }))
		end
		data_cache = data_cache .. data
		available_data_size = available_data_size + data_length_or_error

		while true do
			if expected_chunk_size == nil then
				local _, match_end = data_cache:find("\r\n", 1, true)
				if match_end == 2 then
					_, match_end = data_cache:find("\r\n", 3, true) -- skip \r\n
				end
				if not match_end then break end      -- Not enough data to determine chunk size

				expected_chunk_size = tonumber(data_cache:sub(1, match_end), 16)
				if expected_chunk_size == 0 then return raw_response_data end -- Last chunk
				data_cache = data_cache:sub(match_end + 1)
				available_data_size = available_data_size - match_end
			end

			if available_data_size < expected_chunk_size then
				break -- Not enough data to read the full chunk
			end

			local chunk = data_cache:sub(1, expected_chunk_size)
			data_cache = data_cache:sub(expected_chunk_size + 1)
			available_data_size = available_data_size - expected_chunk_size
			expected_chunk_size = nil

			if inflate then
				inflate_cache = inflate_cache .. chunk
				local bytes_in
				chunk, _, bytes_in, _ = inflate(inflate_cache)
				inflate_cache = inflate_cache:sub(bytes_in + 1) -- remove inflated part
			end

			if type(options.write_function) == "function" then
				options.write_function(chunk)
			else
				raw_response_data = raw_response_data .. chunk
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

	-- // TODO: remove in next version
	if options.followRedirects ~= nil and options.follow_redirects == nil then
		options.follow_redirects = options.followRedirects
		print"followRedirects is deprecated, use follow_redirects"
	end

	-- // TODO: remove in next version
	if options.verifyPeer ~= nil and options.verify_peer == nil then
		options.verify_peer = options.verifyPeer
		print"verifyPeer is deprecated, use verify_peer"
	end

	-- // TODO: remove in next version
	if options.connectTimeout ~= nil and options.connect_timeout == nil then
		options.connect_timeout = options.connectTimeout
		print"connectTimeout is deprecated, use connect_timeout"
	end

	-- // TODO: remove in next version
	if options.readTimeout ~= nil and options.read_timeout == nil then
		options.read_timeout = options.readTimeout
		print"readTimeout is deprecated, use read_timeout"
	end

	-- // TODO: remove in next version
	if options.writeTimeout ~= nil and options.write_timeout == nil then
		options.write_timeout = options.writeTimeout
		print"writeTimeout is deprecated, use write_timeout"
	end

	-- // TODO: remove in next version
	if options.contentType ~= nil and options.content_type == nil then
		options.content_type = options.contentType
		print"contentType is deprecated, use content_type"
	end

	-- // TODO: remove in next version
	if options.progressFunction ~= nil and options.progress_function == nil then
		options.progress_function = options.progressFunction
		print"progressFunction is deprecated, use progress_function"
	end

	-- // TODO: remove in next version
	if options.showDefaultProgress ~= nil and options.show_default_progress == nil then
		options.show_default_progress = options.showDefaultProgress
		print"showDefaultProgress is deprecated, use show_default_progress"
	end

	-- // TODO: remove in next version
	if options.bufferCapacity ~= nil and options.buffer_capacity == nil then
		options.buffer_capacity = options.bufferCapacity
		print"bufferCapacity is deprecated, use buffer_capacity"
	end

	-- // TODO: remove in next version
	if options.drgbSeed ~= nil and options.drgb_seed == nil then
		options.drgb_seed = options.drgbSeed
		print"drgbSeed is deprecated, use drgb_seed"
	end

	-- // TODO: remove in next version
	if options.useBundledRootCertificates ~= nil and options.use_bundled_root_certificates == nil then
		options.use_bundled_root_certificates = options.useBundledRootCertificates
		print"useBundledRootCertificates is deprecated, use use_bundled_root_certificates"
	end

	-- // TODO: remove in next version
	if options.caCertificates ~= nil and options.ca_certificates == nil then
		options.ca_certificates = options.caCertificates
		print"caCertificates is deprecated, use ca_certificates"
	end

	-- // TODO: remove in next version
	if options.clientCertificate ~= nil and options.client_certificate == nil then
		options.client_certificate = options.clientCertificate
		print"clientCertificate is deprecated, use client_certificate"
	end

	local request_options = {}
	local headers = setmetatable(options.headers or {}, corehttp.HEADERS_METATABLE)

	-- options
	request_options.verify_peer = options.verify_peer == nil and true or options.verify_peer
	request_options.connect_timeout = options.connect_timeout or options.timeout
	request_options.read_timeout = options.read_timeout
	request_options.write_timeout = options.write_timeout
	request_options.drgb_seed = type(options.drgb_seed) == "string" or options.drgb_seed or "eli.net"
	request_options.use_bundled_root_certificates = type(options.use_bundled_root_certificates) == "boolean" or
	   options.use_bundled_root_certificates or true
	request_options.ca_certificates = options.ca_certificates
	request_options.client_certificate = options.client_certificate
	request_options.headers = headers
	request_options.buffer_size = math.max(
		math.min(options.buffer_capacity or DEFAULT_BUFFER_CAPACITY, MAXIMUM_BUFFER_CAPACITY),
		MINIMUM_HEADERS_BUFFER_CAPACITY)

	if options.credentials then
		local encoded = base64.encode(tostring(options.credentials.username) ..
			":" .. tostring(options.credentials.password))
		headers["Authorization"] = "Basic " .. encoded
	end

	-- progress function
	local progress_function = nil
	if type(options.progress_function) == "function" then
		progress_function = options.progress_function
	elseif options.show_default_progress == true or (type(options.show_default_progress) == "number" and options.show_default_progress > 0) then
		local step = type(options.show_default_progress) == "boolean" and 10 or
		   options.show_default_progress --[[@as number]]
		if type(step) == "number" and step > 0 then
			progress_function = generate_progress_function(step)
		end
	end

	if type(data) ~= "nil" then
		if type(data.read) == "function" then
			if not headers["Content-Length"] and headers["Transfer-Encoding"] ~= "chunked" then
				local err_msg = "can not determine size of data"
				if type(data.seek) == "function" then
					local current_pos = data:seek("cur", 0)
					if current_pos == nil then
						error(err_msg)
					end
					local size = data:seek("end", 0)
					data:seek("set", current_pos)
					headers["Content-Length"] = tostring(size - current_pos)
				else
					error(err_msg)
				end
			end

			request_options.write_body_hook = function (context)
				while true do
					local chunk = data.read(data, options.buffer_capacity or DEFAULT_BUFFER_CAPACITY)
					if not chunk then break end
					context:write(chunk)
				end
			end
		else
			-- //TODO: remove content_type
			headers["Content-Type"] = options.content_type or headers["Content-Type"] or "application/json"
			local codec = options.codecs[headers["Content-Type"]]
			if codec and type(codec.encode) == "function" then
				request_options.body = codec.encode(data)
			end
		end
	end

	--- options contains 'headers' table and 'body' string
	local response, err_msg, err_code = client:request(path, method, request_options)
	if not response then
		error(tostring(err_msg) .. " (" .. tostring(err_code) .. ")")
	end

	local response_headers = response:headers()
	if options.follow_redirects and table_extensions.includes({ 301, 302, 303, 307, 308 }, response:http_status_code()) then
		local location = response_headers["Location"]
		if location then
			-- we don't want to decode url values as they might be encoded secrets, we trust server to send us valid url
			if not is_client_targeting_same_authority(client, location) then
				local new_scheme, new_host, new_port, new_path, _ = net_url.extract_components_for_request(location)
				-- allow relative (non standard) redirects
				local old_scheme, old_host, old_port, _, _ = net_url.extract_components_for_request(client:endpoint())
				new_scheme = new_scheme or old_scheme
				new_host = (new_host and new_host ~= "") and new_host or old_host
				new_port = new_port or old_port

				local new_client = corehttp.new_client(new_scheme, new_host, new_port, options)
				return request(new_client, new_path, method, options, data)
			else
				return request(client, location, method, options, data)
			end
		end
	end

	local raw_response_data
	local is_chunked_encoding = response_headers["Transfer-Encoding"] == "chunked"
	local is_event_stream = response_headers["Content-Type"] == "text/event-stream"

	if is_chunked_encoding then
		raw_response_data = read_chunked_content(response, options)
	elseif is_event_stream then
		error"event stream not supported yet"
	else
		raw_response_data = read_content(response, options, progress_function)
	end

	local response_data = nil
	if type(raw_response_data) == "string" and #raw_response_data > 0 then
		local mime_type, subtype, _ = parse_content_type(response_headers["Content-Type"])
		local codec_type = options.codecs[type] or options.codecs[mime_type .. "/" .. subtype]
		if codec_type and type(codec_type.decode) == "function" then
			response_data = codec_type.decode(raw_response_data)
		end
	end

	local core_status_code = response:status_code()
	if core_status_code ~= 0 then
		error(tostring(response:status()) .. " (" .. tostring(core_status_code) .. ")")
	end

	local result = {
		code = response:http_status_code(),
		data = response_data,
		raw = raw_response_data,
		headers = response_headers,
	}
	setmetatable(result, {
		__type = "ELI_REST_CLIENT_RESPONSE",
		__tostring = function () return "ELI_REST_CLIENT_RESPONSE" end,
	})
	return result
end

---#DES 'net.http.RestClient:new'
---
---@param self RestClient
---@param url_or_id string
---@param parent_or_options (RestClient|RestClientOptions)?
---@param options RestClientOptions?
---@return RestClient
function net.RestClient:new(url_or_id, parent_or_options, options)
	local rest_client = {
		host = nil,
		__resources = {},
		__shortcuts = {},
		__is_child = false,
		__parent = nil,
		__id = nil,
	}

	if options == nil then options = {} end

	if tostring(parent_or_options):match"ELI_REST_CLIENT" then
		local parent = parent_or_options --[[@as RestClient]]
		rest_client.__is_child = true
		rest_client.__parent = parent
		rest_client.__id = url_or_id
		rest_client.__options = util.merge_tables(options, util.clone(
			parent.__options))
		rest_client.__client = parent.__client
	else
		options = parent_or_options --[[@as RestClientOptions]]
		rest_client.__url = net_url.parse(url_or_id)
		local scheme, host, port, _, _ = net_url.extract_components_for_request(rest_client.__url)
		rest_client.__client = corehttp.new_client(scheme, host, port, options)
		rest_client.__options = util.merge_tables(options, {
			follow_redirects = false,
			verify_peer = true,
			trailing = "",
			shortcut = true,
			shortcut_rules = {},
			headers = util.clone(DEFAULT_HEADERS, true),
			codecs = {
				["application/x-www-form-urlencoded"] = {
					encode = encode_uri_component,
				},
				["text/plain"] = { encode = tostring },
				["application/json"] = {
					encode = function (v)
						return hjson.stringify_to_json(v, {
							invalid_objects_as_type = true,
							indent = false,
						})
					end,
					decode = hjson.parse,
				},
			},
		})
	end

	setmetatable(rest_client, self)
	self.__type = "ELI_REST_CLIENT"
	self.__index = function (t, k)
		local result = rawget(self, k)
		if result == nil and type(k) == "string" and not k:match"^__.*" then
			return net.RestClient:new(k, rest_client)
		end
		return result
	end
	return rest_client
end

---#DES 'net.http.RestClient:__tostring'
---
---@param self RestClient
---@return string
function net.RestClient:__tostring()
	return "ELI_REST_CLIENT " ..
	   (tostring(self.__url) or self.__id or "unknown host or id")
end

---#DES 'net.http.RestClient:get_url'
---
---@param self RestClient
---@return Url
function net.RestClient:get_url()
	if not self.__is_child then return util.clone(self.__url, true, false) --[[@as Url]] end
	local url = util.clone(self.__parent:get_url(), true, false) --[[@as Url]]
	local legal_in_path = util.merge_tables(net_url.options.legal_in_path, { ["/"] = true }) -- we want to keep / in path for resources
	if type(self.__id) == "string" then net_url.add_segment(url, self.__id, legal_in_path) end

	return url:normalize()
end

---#DES 'net.http.RestClient:get_headers'
---
---@param self RestClient
---@return Url
function net.RestClient:get_headers()
	return setmetatable(util.clone(self.__options.headers, true) --[[@as table]], corehttp.HEADERS_METATABLE)
end

---#DES 'net.http.RestClient:conf'
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
---@field shortcut_rules fun(name: string, path: string): string

---#DES 'net.http.RestClient:res'
---
--- creates resource
---@overload fun(self: RestClient, resources: string, options: ResourceCreationOptions?):RestClient?
---@overload fun(self: RestClient, resources: string[], options: ResourceCreationOptions?):RestClient[]?
---@overload fun(self: RestClient, resources: {k:string, v:string}, options: ResourceCreationOptions?):{k:string, v:RestClient}?
function net.RestClient:res(resources, options)
	if options == nil then options = {} end
	local shortcut = options.shortcut
	if shortcut == nil then shortcut = self.__options.shortcut end

	---creates resource
	---@param name string|number
	---@param path string|number
	---@return RestClient
	local function make_resource(name, path)
		if type(self.__resources) ~= "table" then self.__resources = {} end
		if self.__resources[path] then return self.__resources[path] end

		local result = net.RestClient:new(tostring(path), self)
		self.__resources[path] = result
		if shortcut then
			self.__shortcuts[name] = result
			self[name] = result
			for _, rule in ipairs(table_extensions.get(self,
				{ "__options", "shortcut_rules" },
				{})) do
				if type(rule) == "function" then
					local custom_shortcut = rule(name, path);
					if type(custom_shortcut) == "string" then
						self.__shortcuts[custom_shortcut] = result
						self[custom_shortcut] = result
					end
				end
			end
		end
		return result
	end

	if type(resources) == "string" or type(resources) == "number" then
		return make_resource(resources, resources)
	end

	if util.is_array(resources) then
		local valid_for_resource = table_extensions.filter(resources, function (_, v)
			return type(v) == "string" or type(resources) == "number"
		end)
		return table_extensions.map(valid_for_resource, function (v, i) return make_resource(i, v) end)
	end

	if type(resources) == "table" then
		local result = {}
		for k, v in pairs(resources) do
			local resources
			if type(v) == "table" then
				local parent = make_resource(k, v.__root or k)
				local options = util.clone(options, true)
				options.shortcut = true
				parent:res(table_extensions.filter(v, function (k) return k ~= "__root" end), options)
				resources = parent
			elseif type(v) == "number" or type(v) == "string" then
				resources = make_resource(k, v)
			end
			result[k] = resources
		end
		return result
	end
end

---#DES 'net.http.RestClient:safe_res'
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
---@param path_or_options (RestClientOptions | string)?
---@param options RestClientOptions?
---@return Url, RestClientOptions
local function get_request_url(client, path_or_options, options)
	local path = ""
	if type(path_or_options) == "table" then
		options = path_or_options
	elseif type(path_or_options) == "string" then
		path = path_or_options
	end

	if type(options) ~= "table" then options = {} end

	local url = client:get_url()
	if #path > 0 then
		url = net_url.add_path(url, path)
	end
	if type(options.params) == "table" then
		local query = {}
		if util.is_array(options.params) and #options.params > 1 then
			-- split params into key-value pairs, they are stored as k=v
			for _, v in ipairs(options.params) do
				local partial_query = net_url.parse_query(v)
				query = util.merge_tables(query, partial_query, true)
			end
		else
			query = util.merge_tables(query, options.params, true)
		end

		net_url.set_query(url, query) -- cleans up and validates query
	end
	return url:normalize(), options
end

---#DES 'net.http.RestClient:get'
---
---@param self RestClient
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:get(path_or_options, options)
	local url, options = get_request_url(self, path_or_options,
		options)
	local _, _, _, path, _ = net_url.extract_components_for_request(url)

	return request(self.__client, path, "GET", util.merge_tables(options, self.__options))
end

---#DES 'net.http.RestClient:safe_get'
---
---@param self RestClient
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_get(path_or_options, options)
	return unwrap_safe_result(pcall(self.get, self, path_or_options, options))
end

---#DES 'net.http.RestClient:post'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:post(data, path_or_options, options)
	local url, options = get_request_url(self, path_or_options,
		options)
	local _, _, _, path, _ = net_url.extract_components_for_request(url)
	return request(self.__client, path, "POST", util.merge_tables(options, self.__options), data)
end

---#DES 'net.http.RestClient:safe_post'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_post(data, path_or_options, options)
	return unwrap_safe_result(pcall(self.post, self, data, path_or_options, options))
end

---#DES 'net.http.RestClient:put'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:put(data, path_or_options, options)
	local url, options = get_request_url(self, path_or_options,
		options)
	local _, _, _, path, _ = net_url.extract_components_for_request(url)
	return request(self.__client, path, "PUT", util.merge_tables(options, self.__options), data)
end

---#DES 'net.http.RestClient:safe_put'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_put(data, path_or_options, options)
	return unwrap_safe_result(pcall(self.put, self, data, path_or_options, options))
end

---#DES 'net.http.RestClient:patch'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:patch(data, path_or_options, options)
	local url, options = get_request_url(self, path_or_options,
		options)
	local _, _, _, path, _ = net_url.extract_components_for_request(url)
	return request(self.__client, path, "PATCH", util.merge_tables(options, self.__options), data)
end

---#DES 'net.http.RestClient:safe_patch'
---
---@param self RestClient
---@param data (any|RequestData)?
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_patch(data, path_or_options, options)
	return unwrap_safe_result(pcall(self.patch, self, data, path_or_options, options))
end

---#DES 'net.http.RestClient:delete'
---
---@param self RestClient
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return BaseResponse
function net.RestClient:delete(path_or_options, options)
	local url, options = get_request_url(self, path_or_options,
		options)
	local _, _, _, path, _ = net_url.extract_components_for_request(url)

	return request(self.__client, path, "DELETE", util.merge_tables(options, self.__options))
end

---#DES 'net.http.RestClient:safe_delete'
---
---@param self RestClient
---@param path_or_options (string|RestClientOptions)?
---@param options RestClientOptions?
---@return boolean, BaseResponse
function net.RestClient:safe_delete(path_or_options, options)
	return unwrap_safe_result(pcall(self.delete, self, path_or_options, options))
end

---Performs download operation. Data received are passed to write_function
---@param url string
---@param write_function (fun(data: string))?
---@param options BaseRequestOptions?
---@return BaseResponse
local function download(url, write_function, options)
	if type(options) ~= "table" then options = {} end

	local client = net.RestClient:new(url, util.merge_tables(options, {
		timeout = options.timeout,
		write_function = write_function,
	}, true))

	return client:get()
end

---gets retry limit either from request options or from ENV variable ELI_NET_RETRY_LIMIT
---@param options BaseRequestOptions?
---@return integer
local function get_retry_limit(options)
	local retry_limit = tonumber(os.getenv"ELI_NET_RETRY_LIMIT") or 0
	if type(options) == "table" then
		if type(options.retry_limit) == "number" and options.retry_limit > 0 then
			retry_limit = options.retry_limit
		end
	end
	return retry_limit --[[@as integer]]
end

---#DES net.http.download_file
---
--- Downloads file from url to destination
---@param url string
---@param destination string
---@param options BaseRequestOptions?
function net.download_file(url, destination, options)
	local tries = 0
	local retry_limit = get_retry_limit(options)

	while tries <= retry_limit do
		local did_open_file, df <close> = pcall(io.open, destination, "wb")
		if not did_open_file or df == nil then error(df) end
		local write = function (data) df:write(data) end

		local ok, response = pcall(download, url, write, options)
		if ok then
			return response.code
		elseif (tries >= retry_limit) then
			os.remove(destination)
			error(response)
		end

		tries = tries + 1
	end
end

---#DES net.http.download_string
---
--- Downloads file from url to destination
---@param url string
---@param options BaseRequestOptions?
---@return string?, number?
function net.download_string(url, options)
	local tries = 0
	local retry_limit = get_retry_limit(options)

	while tries <= retry_limit do
		local result = ""
		local write = function (data) result = result .. data end

		local ok, response = pcall(download, url, write, options)
		if ok then
			return result, response.code
		elseif (tries >= retry_limit) then
			error(response)
		end
		tries = tries + 1
	end
end

return util.generate_safe_functions(net)
