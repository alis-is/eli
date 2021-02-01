local _curlLoaded , curl = pcall(require, "lcurl.safe")
local io = require "io"
local _util = require "eli.util"
local _hjson = require"hjson"
local _exString = require"eli.extensions.string"
local _exTable = require"eli.extensions.table"

if not _curlLoaded then
   return nil
end

local function _encode_headers(headers)
   local _result = {}
   if type(headers) ~= "table" then return _result end
   if _util.is_array(headers) then return headers end
   for k, v in pairs(headers) do
      local _sep = k:sub(#k, #k) == ":" and "" or ":"
      table.insert(_result, k .. _sep .. v)
   end
   return _result
end

local function _request(method, url, options, data)
   assert(type(url) == "string", "URL has to be a string!")
   assert(type(method) == "string", "METHOD has to be a string!")
   local _result = ""
   local _write = function(data)
      _result = _result .. data
   end
   if type(options.write_function) == "function" then
      _write = options.write_function
   end

   local _headers = _util.merge_tables(options.headers or {}, {
      ['Content-Type'] = options.contentType
   })

   local followRedirects = options.followRedirects or false
   local verifyPeer = options.verifyPeer
   if verifyPeer == nil then
      verifyPeer = true
   end

   if type(options.curlOptions) ~= "table" then
      options.curlOptions = {}
   end

   local _easyOpts = {
      url = url,
      writefunction = _write,
      [curl.OPT_CUSTOMREQUEST] = method,
      [curl.OPT_FOLLOWLOCATION] = followRedirects,
      [curl.OPT_SSL_VERIFYPEER] = verifyPeer,
      [curl.OPT_TIMEOUT] = options.timeout or 0,
      httpheader = _encode_headers(_headers)
   }
   for k, v in pairs(options.curlOptions) do
      if _easyOpts[k] == nil then _easyOpts[k] = v end
   end

   local _easy = curl.easy(_easyOpts)

   local _mime = _exTable.get(_headers, 'Content-Type')
   local _encode = _exTable.get(options, { _mime, "encode" })
   if type(_encode) == "function" then
      data = _encode(data)
   end

   if getmetatable(data) == getmetatable(curl.form()) then
      _easy:setopt_httppost(data)
   elseif getmetatable(data) == getmetatable(_easy:mime()) then
      _easy:setopt{ mimepost = data }
   elseif getmetatable(data) == getmetatable(io.stdout) then
      _easy:setopt{ upload = true }
      _easy:setopt_readfunction(data.read, data)
   else
      _easy:setopt{ postfields = data }
   end

   local _ok, _err = _easy:perform()
   if _ok then
      local _code = _easy:getinfo_response_code()
      if (tonumber(_code) < 200 or tonumber(_code) > 299) and not options.ignoreHttpErrors then
         _easy:close()
         error("Request failed with code " .. tostring(_code) .. "!")
      end
      local _response = {
         code = _code,
         data = _result
      }
      setmetatable(_response, { __type = "ELI_RESTCLIENT_RESPONSE", __tostring = function () return "ELI_RESTCLIENT_RESPONSE" end })
      _easy:close()
      return _response
   else
      _easy:close()
      error(_err)
   end
end

local RestClient = {}
RestClient.__index = RestClient

-- https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
local function _encodeURIComponent(url)
   if url == nil then
     return
   end
   url = url:gsub("\n", "\r\n")
   url = url:gsub("([^%w _%%%-%.~])",  function(c)
      return string.format("%%%02X", string.byte(c))
   end)
   url = url:gsub(" ", "+")
   return url
end

local function encodeQueryParams(data)
   local _result = "";
   for k,v in pairs(data) do
      _result = _result .. _encodeURIComponent(tostring(k)) .. "=" .. _encodeURIComponent(tostring(v)) .. "&"
   end
   return _result:sub(1, #_result - 1);
end

function RestClient:new(hostOrId, parentOrOptions, options)
   local _restClient = {
      host = nil,
      __resources = {},
      __shortcuts = {},
      __is_child = false,
      __parent = nil,
      __id = nil
   }
   if options == nil then
      options = {}
   end

   if type(parentOrOptions) == "table" and tostring(parentOrOptions) == "ELI_RESTCLIENT" then
      _restClient.__is_child = true
      _restClient.__parent = parentOrOptions
      _restClient.__id = hostOrId
      _restClient.__options = _util.merge_tables(options, _util.clone(parentOrOptions.__options))
   else
      options = parentOrOptions
      _restClient.__host = hostOrId
      _restClient.__options = _util.merge_tables(options, {
         followRedirects = true,
         verifyPeer = true,
         trailing = '',
         shortcut = true,
         shortcutRules = {},
         contentType = 'application/json',
         ['application/x-www-form-urlencoded'] = { encode = _encodeURIComponent },
         ['application/json'] = {
            encode = function(v)
               return _hjson.stringify_to_json(v, { invalidObjectsAsType = true })
            end,
            decode = _hjson.parse
         }
      })
   end

   _restClient.__type = "ELI_RESTCLIENT"
   _restClient.__tostring = function() return "ELI_RESTCLIENT" end
   setmetatable(_restClient, self)
   self.__index = function(t, k)
      local _result = rawget(self, k)
      if _result == nil and type(k) == "string" and not k:match"^__.*" then
         return RestClient:new(k, _restClient)
      end
      return _result
   end
   return _restClient
end

local function _join_url(p1, p2)
   if p1:sub(#p1, #p1) == "/" then
      p1 = p1:sub(1, #p1 - 1)
   end
   if p2:sub(1,1) == "/" then
      p2 = p2:sub(2)
   end
   return p1 .. "/" .. p2
end

function RestClient:get_url()
   if not self.__is_child then
      return self.__host
   end
   local _url = self.__parent:get_url()
   if type(self.__id) == "string" then
      _url = _join_url(_url, self.__id)
   end
   return _url
end

function RestClient:conf(options)
   if options == nil then
      return self.__options
   end
   self.__options = _util.merge_tables(options, self.__options)
   return self.__options
end

function RestClient:res(resources, options)
   if options == nil then
      options = {}
   end
   local _shortcut = options.shortcut
   if _shortcut == nil then
      _shortcut = self.__options.shortcut
   end

   local function makeResource(name)
      if self.__resources[name] then
         return self.__resources[name]
      end

      local _result = RestClient:new(tostring(name), self, options)
      self.__resources = _result
      if _shortcut then
         self.__shortcuts[name] = _result
         self[name] = _result
         for _, rule in ipairs(_exTable.get(self, { "options", "shortcutRules" }, {})) do
            if type(rule) == "function" then
               local _customShortcut = rule(name);
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
      return makeResource(resources)
   end

   if _util.is_array(resources) then
      local _validForResource = _exTable.filter(resources, function(_, v)
         return type(v) == "string" or type(resources) == "number"
      end)
      return _exTable.map(_validForResource, makeResource)
   end

   if type(resources) == "table" then
      local _result = {}
      for k, v in pairs(resources) do
         if type(k) ~= "number" and type(k) ~= "string" then
            goto continue
         end
         local _resource = makeResource(k)
         if v then
            _resource.res(v)
         end
         _result[k] = _resource
         ::continue::
      end
      return _result
   end
end
function RestClient:safe_res(resources, options) return pcall(self.res, self, resources, options) end

local function _get_request_url_n_options(client, pathOrOptions, options)
   local _path = ""
   if type(pathOrOptions) == "table" then
      options = pathOrOptions
   elseif type(pathOrOptions) == "string" then
      _path = pathOrOptions
   end
   if type(options) ~= "table" then
      options = {}
   end
   local _url = #_path > 0 and _join_url(client:get_url(), _path) or client:get_url()
   if type(options.params) == "table" then
      local _query
      if _util.is_array(options.params) and #options.params > 1 then
         _query = _exString.join("&", table.unpack(_exTable.map(options.params, tostring)))
      else
         _query = encodeQueryParams(options.params)
      end
      if type(_query) == "string" and #_query > 0 then
         if _url:sub(#_url, #_url) == "/" then _url = _url:sub(1, #_url - 1) end
         _url = _url .. '?' .. _query
      end
   end
   return _url, _util.merge_tables(options, client.__options)
end

function RestClient:get(pathOrOptions, options)
   local _url, _options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('GET', _url, _options)
end
function RestClient:safe_get(pathOrOptions, options) return pcall(self.get, self, pathOrOptions, options) end

function RestClient:post(data, pathOrOptions, options)
   local _url, _options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('POST', _url, _options, data)
end
function RestClient:safe_post(data, pathOrOptions, options) return pcall(self.post, self, data, pathOrOptions, options) end

function RestClient:put(data, pathOrOptions, options)
   local _url, _options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('PUT', _url, _options, data)
end
function RestClient:safe_put(data, pathOrOptions, options) return pcall(self.put, self, data, pathOrOptions, options) end

function RestClient:patch(data, pathOrOptions, options)
   local _url, _options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('PATCH', _url, _options, data)
end
function RestClient:safe_patch(data, pathOrOptions, options) return pcall(self.patch, self, data, pathOrOptions, options) end

function RestClient:delete(pathOrOptions, options)
   local _url, _options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('DELETE', _url, _options)
end
function RestClient:safe_delete(pathOrOptions, options) return pcall(self.delete, self, pathOrOptions, options) end

local function _download(url, write_function, options)
   if type(options) ~= "table" then
      options = {}
   end
   local followRedirects = options.followRedirects or false
   local verifyPeer = options.verifyPeer
   if verifyPeer == nil then
      verifyPeer = true
   end

   local _client = RestClient:new(url, {
      followRedirects = followRedirects,
      verifyPeer = verifyPeer,
      timeout = options.timeout,
      write_function = write_function
   })

   return _client:get()
end

local function _get_retry_limit(options)
   local _retryLimit = tonumber(os.getenv("ELI_NET_RETRY_LIMIT")) or 0
   if type(options) == "table" then
      if type(options.retryLimit) == "number" and options.retryLimit > 0 then
         _retryLimit = options._retryLimit
      end
   end
   return _retryLimit
end

local function download_file(url, destination, options)
   local _tries = 0
   local _retryLimit = _get_retry_limit(options)

   while _tries <= _retryLimit do
      local _didOpenFile, _df = pcall(io.open, destination, "w+b")
      if not _didOpenFile then
         error(_df)
      end

      local _write = function(data)
         _df:write(data)
      end

      local _ok, _code = pcall(_download, url, _write, options)
      if _ok then
         return _code
      elseif (_tries >= _retryLimit) then
         error(_code)
      end

      _tries = _tries + 1
      _df:close()
   end
end

local function download_string(url, options)
   local _tries = 0
   local _retryLimit = _get_retry_limit(options)

   while _tries <= _retryLimit do
      local _result = ""
      local _write = function(data)
         _result = _result .. data
      end

      local _ok, _code = pcall(_download, url, _write, options)
      if _ok then
         return _result, _code
      elseif (_tries >= _retryLimit) then
         error(_code)
      end
      _tries = _tries + 1
   end
end

return _util.generate_safe_functions({
   download_file = download_file,
   download_string = download_string,
   RestClient = RestClient
})